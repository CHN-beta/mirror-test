inputs:
  let
    inherit (inputs.localLib) stripeTabs;
    inherit (builtins) map attrNames;
    inherit (inputs.lib) mkMerge mkIf mkOption types;
    bugs =
    {
      # suspend & hibernate do not use platform
      suspend-hibernate-no-platform.systemd.sleep.extraConfig =
      ''
        SuspendState=freeze
        HibernateMode=shutdown
      '';
      # reload iwlwifi after resume from hibernate
      hibernate-iwlwifi =
      {
        systemd.services.reload-iwlwifi-after-hibernate =
        {
          description = "reload iwlwifi after resume from hibernate";
          after = [ "systemd-hibernate.service" ];
          serviceConfig.Type = "oneshot";
          script = let modprobe = "${inputs.pkgs.kmod}/bin/modprobe"; in
          ''
            ${modprobe} -r iwlwifi
            ${modprobe} iwlwifi
            echo 0 > /sys/devices/system/cpu/intel_pstate/no_turbo
          '';
          wantedBy = [ "systemd-hibernate.service" ];
        };
        nixos.system.kernel.modules.modprobeConfig =
          [ "options iwlmvm power_scheme=1" "options iwlwifi uapsd_disable=1" ];
      };
      # disable wakeup on lid open
      suspend-lid-no-wakeup.systemd.services.lid-no-wakeup =
      {
        description = "lid no wake up";
        serviceConfig.Type = "oneshot";
        script =
          let
            cat = "${inputs.pkgs.coreutils}/bin/cat";
            grep = "${inputs.pkgs.gnugrep}/bin/grep";
          in
          ''
            if ${cat} /proc/acpi/wakeup | ${grep} LID0 | ${grep} -q enabled
            then
              echo LID0 > /proc/acpi/wakeup
            fi
            if ${cat} /proc/acpi/wakeup | ${grep} XHCI | ${grep} -q enabled
            then
              echo XHCI > /proc/acpi/wakeup
            fi
          '';
        wantedBy = [ "multi-user.target" ];
      };
      # xmunet use old encryption
      xmunet.nixpkgs.config.packageOverrides = pkgs: { wpa_supplicant = pkgs.wpa_supplicant.overrideAttrs
        (attrs: { patches = attrs.patches ++ [ ./xmunet.patch ];}); };
      suspend-hibernate-waydroid.systemd.services =
        let
          systemctl = "${inputs.pkgs.systemd}/bin/systemctl";
        in
        {
          "waydroid-hibernate" =
          {
            description = "waydroid hibernate";
            wantedBy = [ "systemd-hibernate.service" "systemd-suspend.service" ];
            before = [ "systemd-hibernate.service" "systemd-suspend.service" ];
            serviceConfig.Type = "oneshot";
            script = "${systemctl} stop waydroid-container";
          };
          "waydroid-resume" =
          {
            description = "waydroid resume";
            wantedBy = [ "systemd-hibernate.service" "systemd-suspend.service" ];
            after = [ "systemd-hibernate.service" "systemd-suspend.service" ];
            serviceConfig.Type = "oneshot";
            script = "${systemctl} start waydroid-container";
          };
        };
      firefox.programs.firefox.enable = inputs.lib.mkForce false;
      power.boot.kernelParams = [ "cpufreq.default_governor=powersave" ];
      backlight.boot.kernelParams = [ "nvidia.NVreg_RegistryDwords=EnableBrightnessControl=1" ];
      amdpstate.boot.kernelParams = [ "amd_pstate=active" ];
      wireplumber.environment.etc."wireplumber/main.lua.d/50-alsa-config.lua".text =
        let
          content = builtins.readFile
            (inputs.pkgs.wireplumber + "/share/wireplumber/main.lua.d/50-alsa-config.lua");
          matched = builtins.match
            ".*\n([[:space:]]*)(--\\[\"session\\.suspend-timeout-seconds\"][^\n]*)[\n].*" content;
          spaces = builtins.elemAt matched 0;
          comment = builtins.elemAt matched 1;
          config = ''["session.suspend-timeout-seconds"] = 0'';
        in
          builtins.replaceStrings [(spaces + comment)] [(spaces + config)] content;
    };
  in
    {
      options.nixos.bugs = mkOption
      {
        type = types.listOf (types.enum (attrNames bugs));
        default = [];
      };
      config = mkMerge (map (bug: mkIf (builtins.elem bug inputs.config.nixos.bugs) bugs.${bug}) (attrNames bugs));
    }
