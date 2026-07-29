# OpenVSP — NixOS source-build module
#
# Builds OpenVSP from the official GitHub source tree using CMake.
# Dependencies mirror upstream README: cmake, fltk, glew, libxml2, eigen,
# openssl, libGL, etc.
#
# Code-Eli 0.3.6 is vendored from OpenVSP's own Libraries/ mirror; we
# build the generated versioned header from the shipped cmake template.
#
# Usage:
#   programs.openvsp.enable = true;
#   # optional:
#   # programs.openvsp.version = "3.35.0";
#
{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.programs.openvsp;

  code-eli = pkgs.runCommand "code-eli-0.3.6" {
    src = pkgs.fetchzip {
      url = "https://github.com/OpenVSP/OpenVSP/raw/OpenVSP_${cfg.version}/Libraries/Code-Eli-f6aefa912d58.zip";
      sha256 = "sha256-GJ3C3n3enVsNb/Nj1XMMP+S1AI4VO9y+ue9hBa5XPaM=";
    };
    buildInputs = [ pkgs.cmake ];
  } ''
    mkdir -p $out/include/eli
    cp -R $src/include/eli/* $out/include/eli/
    cmake -S $src -B ./build
    cp ./build/include/eli/code_eli.hpp $out/include/eli/
  '';

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
      code-eli
    ];

    cmakeFlags = with pkgs; [
      "-DCMAKE_BUILD_TYPE=Release"
      "-DVSP_USE_SYSTEM_EIGEN=ON"
      "-DVSP_USE_SYSTEM_CODEELI=ON"
      "-DVSP_USE_SYSTEM_ANGELSCRIPT=ON"
      "-DVSP_USE_SYSTEM_CMINPACK=ON"
      "-DANGELSCRIPT_INSTALL_DIR=${angelscript}"
      "-DCMINPACK_INSTALL_DIR=${cminpack}"
      "-DCodeEli_FIRST_INCLUDE_DIR=${code-eli}/include/eli"
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
