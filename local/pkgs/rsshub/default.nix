{
  lib, stdenv, mkPnpmPackage, fetchFromGitHub, nodejs, writeShellScript,
  chromium, bash
}:
let
  pname = "rsshub";
  version = "20230829";
  src = fetchFromGitHub
  {
    owner = "DIYgod";
    repo = "RSSHub";
    rev = "afcf9774260dc6505263cf0428970e890f2f7b1d";
    hash = "sha256-BQFE0Z5DsFTf0tylQ0NN89hCdXT/Y2M+YPa/10ccOVg=";
  };
  originalPnpmPackage = mkPnpmPackage { inherit pname version src nodejs; };
  nodeModules = originalPnpmPackage.nodeModules.overrideAttrs { PUPPETEER_SKIP_DOWNLOAD = true; };
  rsshub-unwrapped = stdenv.mkDerivation
  {
    inherit version src;
    pname = "${pname}-unwrapped";
    configurePhase = 
    ''
      export HOME=$NIX_BUILD_TOP # Some packages need a writable HOME
      export npm_config_nodedir=${nodejs}

      runHook preConfigure

      ln -s ${nodeModules}/. node_modules

      runHook postConfigure
    '';
    installPhase =
    ''
      runHook preInstall
      mkdir -p $out
      mv * .* $out
      runHook postInstall
    '';
  };
  startScript = writeShellScript "rsshub"
  ''
    cd ${rsshub-unwrapped}
    export PATH=${lib.makeBinPath [ bash nodejs nodejs.pkgs.pnpm chromium ]}:$PATH
    export CHROMIUM_EXECUTABLE_PATH=chromium
    pnpm start
  '';
in stdenv.mkDerivation rec
{
  inherit pname version;
  phases = [ "installPhase" ];
  installPhase =
  ''
    runHook preInstall
    mkdir -p $out/bin
    cp ${startScript} $out/bin/rsshub
    runHook postInstall
  '';
}
