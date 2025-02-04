inputs:
{
  options.nixos.system.kernel = let inherit (inputs.lib) mkOption types; in
  {
    variant = mkOption
    {
      type = types.enum [ "nixos" "xanmod-lts" "xanmod-latest" "cachyos" "cachyos-lto" "cachyos-server" ];
      default = if inputs.config.nixos.system.gui.preferred then "cachyos" else "cachyos-server";
    };
    patches = mkOption { type = types.listOf types.nonEmptyStr; default = [ "cjktty" ]; };
    modules =
    {
      install = mkOption { type = types.listOf types.str; default = []; };
      load = mkOption { type = types.listOf types.str; default = []; };
      initrd = mkOption { type = types.listOf types.str; default = []; };
      modprobeConfig = mkOption { type = types.listOf types.str; default = []; };
    };
  };
  config = let inherit (inputs.config.nixos.system) kernel; in inputs.lib.mkMerge
  [
    {
      boot =
      {
        kernelModules = [ "br_netfilter" ] ++ kernel.modules.load;
        # modprobe --show-depends
        initrd.availableKernelModules =
        [
          "bfq" "failover" "net_failover" "nls_cp437" "nls_iso8859-1" "sd_mod"
          "sr_mod" "usbcore" "usbhid" "usbip-core" "usb-common" "usb_storage" "vhci-hcd" "virtio" "virtio_blk"
          "virtio_net" "virtio_ring" "virtio_scsi" "cryptd" "libaes"
          "ahci" "ata_piix" "nvme" "sdhci_acpi" "virtio_pci" "xhci_pci"
          # networking for nas
          "igb"
        ]
        ++ (inputs.lib.optionals (kernel.variant != "nixos") [ "crypto_simd" ])
        # for pi3b to show message over hdmi while boot
        ++ (inputs.lib.optionals (kernel.variant == "nixos") [ "vc4" "bcm2835_dma" "i2c_bcm2835" ]);
        extraModulePackages = (with inputs.config.boot.kernelPackages; [ v4l2loopback ]) ++ kernel.modules.install;
        extraModprobeConfig = builtins.concatStringsSep "\n" kernel.modules.modprobeConfig;
        kernelParams = [ "delayacct" "acpi_osi=Linux" "acpi.ec_no_wakeup=1" ];
        kernelPackages =
        {
          nixos = inputs.pkgs.linuxPackages;
          xanmod-lts = inputs.pkgs.linuxPackages_xanmod;
          xanmod-latest = inputs.pkgs.linuxPackages_xanmod_latest;
          cachyos = inputs.pkgs.linuxPackages_cachyos;
          cachyos-lto = inputs.pkgs.linuxPackages_cachyos-lto;
          cachyos-server = inputs.pkgs.linuxPackages_cachyos-server;
          rpi3 = inputs.pkgs.linuxPackages_rpi3;
        }.${kernel.variant};
        kernelPatches =
          let
            patches =
            {
              cjktty =
              [{
                name = "cjktty";
                patch =
                  let
                    version = builtins.concatStringsSep "." (inputs.lib.lists.take 2
                      (builtins.splitVersion inputs.config.boot.kernelPackages.kernel.version));
                    fileVersion = { "6.8" = "6.7"; }.${version} or version;
                  in "${inputs.topInputs.cjktty}/v6.x/cjktty-${fileVersion}.patch";
                extraStructuredConfig =
                  { FONT_CJK_16x16 = inputs.lib.kernel.yes; FONT_CJK_32x32 = inputs.lib.kernel.yes; };
              }];
              lantian =
              [{
                name = "lantian";
                patch = null;
                # pick from xddxdd/nur-packages dce93a
                extraStructuredConfig = with inputs.lib.kernel;
                {
                  ACPI_PCI_SLOT = yes;
                  ENERGY_MODEL = yes;
                  PARAVIRT_TIME_ACCOUNTING = yes;
                  PM_AUTOSLEEP = yes;
                  WQ_POWER_EFFICIENT_DEFAULT = yes;
                  PREEMPT_VOLUNTARY = inputs.lib.mkForce no;
                  PREEMPT = inputs.lib.mkForce yes;
                  NO_HZ_FULL = yes;
                  HZ_1000 = inputs.lib.mkForce yes;
                  HZ_250 = inputs.lib.mkForce no;
                  HZ = inputs.lib.mkForce (freeform "1000");
                };
              }];
              surface =
                let
                  version =
                    let versionArray = builtins.splitVersion inputs.config.boot.kernelPackages.kernel.version;
                    in "${builtins.elemAt versionArray 0}.${builtins.elemAt versionArray 1}";
                  kernelPatches = builtins.map
                    (file:
                    {
                      name = "surface-${file.name}";
                      patch = "${inputs.topInputs.linux-surface}/patches/${version}/${file.name}";
                    })
                    (builtins.filter
                      (file: file.value == "regular")
                      (inputs.localLib.attrsToList (builtins.readDir
                        "${inputs.topInputs.linux-surface}/patches/${version}")));
                  kernelConfig = builtins.removeAttrs
                    (builtins.listToAttrs (builtins.concatLists (builtins.map
                      (configString:
                        if builtins.match "CONFIG_.*=." configString == [] then
                        (
                          let match = builtins.match "CONFIG_(.*)=(.)" configString; in with inputs.lib.kernel;
                          [{
                            name = builtins.elemAt match 0;
                            value = { m = module; y = yes; }.${builtins.elemAt match 1};
                          }]
                        )
                        else if builtins.match "# CONFIG_.* is not set" configString == [] then
                        [{
                          name = builtins.elemAt (builtins.match "# CONFIG_(.*) is not set" configString) 0;
                          value = inputs.lib.kernel.unset;
                        }]
                        else if builtins.match "#.*" configString == [] then []
                        else if configString == "" then []
                        else throw "could not parse: ${configString}"
                      )
                      (inputs.lib.strings.splitString "\n"
                        (builtins.readFile "${inputs.topInputs.linux-surface}/configs/surface-${version}.config")))))
                    [ "VIDEO_IPU3_IMGU" ];
                in kernelPatches ++ [{ name = "surface-config"; patch = null; extraStructuredConfig = kernelConfig; }];
              hibernate-progress = [{ name = "hibernate-progress"; patch = ./hibernate-progress.patch; }];
            };
          in builtins.concatLists (builtins.map (name: patches.${name}) kernel.patches);
      };
    }
    (
      inputs.lib.mkIf
      (
        inputs.lib.strings.hasPrefix "cachyos" kernel.variant
        && builtins.elem "server-extra" inputs.config.nixos.packages._packageSets
      )
      (
        let scx =
          let rustPlatform = inputs.pkgs.unstablePackages.rustPlatform;
          in inputs.pkgs.scx.override (prev:
          {
            scx-layered = prev.scx-layered.override { inherit rustPlatform; };
            scx-rustland = prev.scx-rustland.override { inherit rustPlatform; };
            scx-rusty = prev.scx-rusty.override { inherit rustPlatform; };
            scx-rlfifo = prev.scx-rlfifo.override { inherit rustPlatform; };
            scx-lavd = prev.scx-lavd.override { inherit rustPlatform; };
          });
        in { environment.systemPackages = [ scx ]; }
      )
    )
    (
      inputs.lib.mkIf (kernel.variant == "rpi3")
        { boot.initrd = { systemd.enableTpm2 = false; includeDefaultModules = false; }; }
    )
  ];
}
