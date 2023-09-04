{ lib, pkgs }: with pkgs;
{
  typora = callPackage ./typora {};
  upho = python3Packages.callPackage ./upho {};
  spectral = python3Packages.callPackage ./spectral {};
  vesta = callPackage ./vesta {};
  oneapi = callPackage ./oneapi {};
  send = callPackage ./send {};
  rsshub = callPackage ./rsshub {};
  misskey = callPackage ./misskey {};
  mk-meili-mgn = callPackage ./mk-meili-mgn {};
  phonon-unfolding = callPackage ./phonon-unfolding {};
  # vasp = callPackage ./vasp
  # {
  #   stdenv = pkgs.lmix-pkgs.intel21Stdenv;
  #   intel-mpi = pkgs.lmix-pkgs.intel-oneapi-mpi_2021_9_0;
  #   ifort = pkgs.lmix-pkgs.intel-oneapi-ifort_2021_9_0;
  # };
  vasp = callPackage ./vasp { openmp = llvmPackages.openmp; };
}
