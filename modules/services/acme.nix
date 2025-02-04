inputs:
{
  options.nixos.services.acme = let inherit (inputs.lib) mkOption types; in mkOption
  {
    type = types.nullOr (types.submodule { options =
    {
      cert = mkOption
      {
        type = types.attrsOf (types.submodule (submoduleInputs: { options =
        {
          domains = mkOption
            { type = types.nonEmptyListOf types.nonEmptyStr; default = [ submoduleInputs.config._module.args.name ]; };
          group = mkOption { type = types.nullOr types.nonEmptyStr; default = null; };
        };}));
        default = {};
      };
    };});
    default = null;
  };
  config = let inherit (inputs.config.nixos.services) acme; in inputs.lib.mkIf (acme != null)
  {
    security.acme =
    {
      acceptTerms = true;
      defaults =
      {
        email = "chn@chn.moe";
        dnsProvider = "cloudflare";
        dnsResolver = "1.1.1.1";
      };
      certs = builtins.listToAttrs (builtins.map
        (cert:
        {
          name = builtins.elemAt cert.value.domains 0;
          value =
          {
            credentialsFile = inputs.config.sops.templates."acme/cloudflare.ini".path;
            extraDomainNames = builtins.tail cert.value.domains;
            group = inputs.lib.mkIf (cert.value.group != null) cert.value.group;
          };
        })
        (inputs.localLib.attrsToList acme.cert));
    };
    sops =
    {
      templates."acme/cloudflare.ini".content =
      ''
        CLOUDFLARE_DNS_API_TOKEN=${inputs.config.sops.placeholder."acme/token"}
        CLOUDFLARE_PROPAGATION_TIMEOUT=300
      '';
      secrets."acme/token" = {};
    };
  };
}
