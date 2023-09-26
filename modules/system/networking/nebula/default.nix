inputs:
{
  options.nixos.system.networking.nebula = let inherit (inputs.lib) mkOption types; in
  {
    enable = mkOption { type = types.bool; default = false; };
    # null: is lighthouse; non-empty string: is not lighthouse, and use this string as lighthouse address.
    lighthouse = mkOption { type = types.nullOr types.nonEmptyStr; default = null; };
    useRelay = mkOption { type = types.bool; default = false; };
  };
  config =
    let
      inherit (inputs.lib) mkIf;
      inherit (inputs.config.nixos.system.networking) nebula;
      inherit (builtins) concatStringsSep;
    in mkIf nebula.enable
    {
      services.nebula.networks.nebula =
      {
        enable = true;
        ca = ./ca.crt;
        # nebula-cert sign -name 1p9p -ip 192.168.82.4/24
        cert = ./. + "/${inputs.config.nixos.system.networking.hostname}.crt";
        key = inputs.config.sops.templates."nebula/key-template".path;
        firewall.inbound = [ { host = "any"; port = "any"; proto = "any"; } ];
        firewall.outbound = [ { host = "any"; port = "any"; proto = "any"; } ];
      }
      // (
        if nebula.lighthouse == null then { isLighthouse = true; isRelay = true; }
        else
        {
          lighthouses = [ "192.168.82.1" ];
          relays = if nebula.useRelay then [ "192.168.82.1" ] else [];
          staticHostMap."192.168.82.1" = [ "${nebula.lighthouse}:4242" ];
        }
      );
      sops =
      {
        templates."nebula/key-template" =
        {
          content = concatStringsSep "\n"
          [
            "-----BEGIN NEBULA X25519 PRIVATE KEY-----"
            inputs.config.sops.placeholder."nebula/key"
            "-----END NEBULA X25519 PRIVATE KEY-----"
          ];
          owner = inputs.config.systemd.services."nebula@nebula".serviceConfig.User;
          group = inputs.config.systemd.services."nebula@nebula".serviceConfig.Group;
        };
        secrets."nebula/key" = {};
      };
      networking.firewall.trustedInterfaces = [ "nebula.nebula" ];
      systemd.services."nebula@nebula" =
      {
        after = [ "network-online.target" ];
        serviceConfig.Restart = "always";
      };
    };
}
