inputs:
{
  options.nixos.services.postgresql = let inherit (inputs.lib) mkOption types; in mkOption
  {
    type = types.nullOr (types.submodule { options =
    {
      instances = mkOption
      {
        type = types.attrsOf (types.submodule (submoduleInputs: { options =
        {
          database = mkOption { type = types.nonEmptyStr; default = submoduleInputs.config._module.args.name; };
          user = mkOption { type = types.nonEmptyStr; default = submoduleInputs.config._module.args.name; };
          passwordFile = mkOption { type = types.nullOr types.nonEmptyStr; default = null; };
          initializeFlags = mkOption { type = types.attrsOf types.nonEmptyStr; default = {}; };
        };}));
        default = {};
      };
    };});
    default = null;
  };
  config =
    let
      inherit (inputs.config.nixos.services) postgresql;
      inherit (inputs.lib) mkAfter concatStringsSep mkIf;
      inherit (inputs.localLib) attrsToList;
      inherit (builtins) map listToAttrs filter;
    in mkIf (postgresql != null)
    {
      services =
      {
        postgresql =
        {
          enable = true;
          package = inputs.pkgs.postgresql_15;
          enableTCPIP = true;
          authentication = "host all all 0.0.0.0/0 md5";
          settings =
          {
            unix_socket_permissions = "0700";
            shared_buffers = "8192MB";
            work_mem = "512MB";
            autovacuum = "on";
          };
          # log_timezone = 'Asia/Shanghai'
          # datestyle = 'iso, mdy'
          # timezone = 'Asia/Shanghai'
          # lc_messages = 'en_US.utf8'
          # lc_monetary = 'en_US.utf8'
          # lc_numeric = 'en_US.utf8'
          # lc_time = 'en_US.utf8'
          # default_text_search_config = 'pg_catalog.english'
          # plperl.on_init = 'use utf8; use re; package utf8; require "utf8_heavy.pl";'
          # mv /path/to/dir /path/to/dir_old
          # mkdir /path/to/dir
          # chattr +C /path/to/dir
          # cp -a --reflink=never /path/to/dir_old/. /path/to/dir
          # rm -rf /path/to/dir_old
          ensureUsers = map (db: { name = db.value.user; }) (attrsToList postgresql.instances);
        };
        postgresqlBackup =
        {
          enable = true;
          pgdumpOptions = "-Fc";
          compression = "none";
          databases = map (db: db.value.database) (attrsToList postgresql.instances);
        };
      };
      systemd.services.postgresql.postStart = mkAfter (concatStringsSep "\n" (map
        (db:
          let
            passwordFile =
              if db.value.passwordFile or null != null then db.value.passwordFile
              else inputs.config.sops.secrets."postgresql/${db.value.user}".path;
            initializeFlag =
              if db.value.initializeFlags != {} then
                " WITH "
                + (concatStringsSep " " (map
                  (flag: ''${flag.name} = "${flag.value}"'')
                  (attrsToList db.value.initializeFlags)))
              else "";
          in
          # create database if not exist
          "$PSQL -tAc \"SELECT 1 FROM pg_database WHERE datname = '${db.value.database}'\" | grep -q 1"
            + " || $PSQL -tAc 'CREATE DATABASE \"${db.value.database}\"${initializeFlag}'"
          # set user password
            + "\n"
            + "$PSQL -tAc \"ALTER USER ${db.value.user} with encrypted password '$(cat ${passwordFile})'\""
          # set db owner
            + "\n"
            + "$PSQL -tAc \"select pg_catalog.pg_get_userbyid(d.datdba) FROM pg_catalog.pg_database d"
            + " WHERE d.datname = '${db.value.database}' ORDER BY 1\""
            + " | grep -E '^${db.value.user}$' -q"
            + " || $PSQL -tAc \"ALTER DATABASE ${db.value.database} OWNER TO ${db.value.user}\"")
        (attrsToList postgresql.instances)));
      sops.secrets = listToAttrs (map
        (db: { name = "postgresql/${db.value.user}"; value.owner = inputs.config.users.users.postgres.name; })
        (filter (db: db.value.passwordFile == null) (attrsToList postgresql.instances)));
    };
}
  # sops.secrets.drone-agent = {
  #   owner = config.systemd.services.drone-agent.serviceConfig.User;
  #   key = "drone";
  # };
# pg_dump -h 127.0.0.1 -U synapse -Fc -f synaps.dump synapse
# pg_restore -h 127.0.0.1 -U misskey -d misskey --data-only --jobs=4 misskey.dump