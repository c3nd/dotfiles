# OpenVSP — NixOS source-build module
#
# Builds OpenVSP from the official GitHub source tree using CMake.
# Dependencies mirror upstream README: cmake, fltk, glew, libxml2, eigen,
# openssl, libGL, etc.
#
# Usage:
#   programs.openvsp.enable = true;
#   # optional:
#   programs.openvsp.version = "3.35.0";
#
{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.programs.openvsp;

  openvsp-pkg = pkgs.stdenv.mkDerivation {
    pname = "openvsp";
    version = cfg.version;

    src = pkgs.fetchFromGitHub {
      owner = "OpenVSP";
      repo = "OpenVSP";
      rev = "OpenVSP_${cfg.version}";
      fetchSubmodules = true; # bundled sub-deps in tree
      sha256 = "sha256-p5NJWGaRMUc/HnyQEXHr1qitD6nKkIw4R/3VxgMX01s=";
    };

    nativeBuildInputs = with pkgs; [
      cmake
      swig
      doxygen
      graphviz
    ];

    buildInputs = with pkgs; [
      fltk
      glew
      libxml2
      eigen
      openssl
      mesa
      libGLU
      libGL
      libxkbcommon
      wayland
      pkg-config
      angelscript
      cminpack
    ];

    cmakeFlags = with pkgs; [
      "-DCMAKE_BUILD_TYPE=Release"
      "-DVSP_USE_SYSTEM_EIGEN=ON"
      "-DANGELSCRIPT_INSTALL_DIR=${angelscript}"
      "-DCMINPACK_INSTALL_DIR=${cminpack}"
      "-DCMAKE_PREFIX_PATH=${cminpack};${angelscript}"
    ];

    meta = with lib; {
      description = "OpenVSP parametric aerospace vehicle conceptual design tool";
      homepage = "https://github.com/OpenVSP/OpenVSP";
      license = licenses.mit;
      platforms = [ "x86_64-linux" ];
      mainProgram = "vsp";
    };
  };

in
{
  options.programs.openvsp = {
    enable = mkEnableOption "OpenVSP (source build via CMake)";

    version = mkOption {
      type = types.str;
      default = "3.51.2";
      description = "OpenVSP release tag to build (no leading 'v' or `OpenVSP_` prefix here).";
    };

    package = mkOption {
      type = types.package;
      default = openvsp-pkg;
      description = "The built OpenVSP package to expose.";
    };
  };

  config = mkIf cfg.enable {
    environment.systemPackages = [ cfg.package ];
  };
}
