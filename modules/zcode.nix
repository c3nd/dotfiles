# ZCode — Home Manager module
#
# Wraps the upstream ZCode AppImage (Electron) so it runs on NixOS. The `hash`
# option defaults to `lib.fakeHash`; on the first build Nix prints the *real*
# sha256 for the chosen version — paste it into `hash` and rebuild.
#
# Usage (in home.nix or a Home Manager config):
#   programs.zcode.enable = true;
#   programs.zcode.version = "3.1.2";  # optional override
#   programs.zcode.hash    = "sha256-...";  # set after first build
{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.programs.zcode;

  zcode-pkg = pkgs.appimageTools.wrapType2 {
    pname = "zcode";
    version = cfg.version;

    src = pkgs.fetchurl {
      url = "https://cdn.zcode-ai.com/zcode/electron/releases/${cfg.version}/ZCode-${cfg.version}-linux-x64.AppImage";
      hash = cfg.hash;
    };

    # Electron/Chromium runtime deps
    extraPkgs = pkgs: with pkgs; [
      gtk3
      glib
      cairo
      pango
      atk
      gdk-pixbuf
      nss
      nspr
      dbus
      expat
      xorg.libX11
      xorg.libXcomposite
      xorg.libXdamage
      xorg.libXext
      xorg.libXfixes
      xorg.libXrandr
      xorg.libxcb
      xorg.libXcursor
      xorg.libXi
      xorg.libXtst
      xorg.libXScrnSaver
      libxkbcommon
      at-spi2-core
      cups
      alsa-lib
      libdrm
      mesa
      vulkan-loader
      wayland
      openssl
    ];

    extraInstallCommands = ''
      if [ -f "$out/share/applications/zcode.desktop" ]; then
        substituteInPlace "$out/share/applications/zcode.desktop" \
          --replace "Exec=AppRun" "Exec=$out/bin/zcode"
      fi
    '';

    meta = with lib; {
      description = "ZCode — agentic development environment by Z.AI, powered by GLM-5.2";
      homepage = "https://zcode.z.ai";
      platforms = [ "x86_64-linux" ];
      mainProgram = "zcode";
    };
  };

in
{
  options.programs.zcode = {
    enable = mkEnableOption "ZCode by Z.AI (AppImage)";

    version = mkOption {
      type = types.str;
      default = "3.1.2";
      description = "ZCode release version to fetch (e.g. \"3.1.2\").";
    };

    hash = mkOption {
      type = types.str;
      default = lib.fakeHash;
      description = ''
        sha256 hash of the AppImage for the chosen version.
        Leave as lib.fakeHash on first build to get the real hash
        from the error output, then set it here or in home.nix.
      '';
    };

    package = mkOption {
      type = types.package;
      default = zcode-pkg;
      description = "The ZCode package to use.";
    };
  };

  config = mkIf cfg.enable {
    home.packages = [ cfg.package ];
  };
}
