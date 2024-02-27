{ go, cudatoolkit, stdenv, src, config, cudaCapabilities ? config.cudaCapabilities }: stdenv.mkDerivation
{
  name = "mumax";
  inherit src;
  nativeBuildInputs = [ go cudatoolkit ];
  CUDA_CC = builtins.concatStringsSep " " cudaCapabilities;
}
