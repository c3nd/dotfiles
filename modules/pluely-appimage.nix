# Pluely — AppImage-wrapped release (mirrors atomic-chat.nix)
#
# The Nix-built Tauri package (modules/pluely.nix) ships a debug webview that
# fails to embed its frontend, so the window shows "Could not connect to
# localhost: Connection refused" and never reaches the Settings UI. The
# upstream AppImage is a proper release build, so we wrap that instead.
#
# `hash` defaults to lib.fakeHash; on the first build Nix prints the real
# sha256 — paste it into `hash` and rebuild.
#
# Usage:
#   programs.pluely-appimage.enable = true;
#   programs.pluely-appimage.hash   = "sha256-...";  # set after first build
{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.programs.pluely-appimage;

  pluely-pkg = pkgs.appimageTools.wrapType2 {
    pname = "pluely";
    version = cfg.version;

    src = pkgs.fetchurl {
      url = "https://github.com/iamsrikanthnani/pluely/releases/download/app-v${cfg.version}/Pluely_${cfg.version}_amd64.AppImage";
      hash = "sha256-9542ecef841a68f7653a8b0c9894665a023d6ebcae21cfd96c72cf3447fc013c";
    };

    # Tauri/WebKitGTK runtime libs (same set that keeps atomic-chat from
    # segfaulting/blank-screening on launch).
    extraPkgs = pkgs: with pkgs; [
      gtk3
      glib
      cairo
      pango
      atk
      gdk-pixbuf
      webkitgtk_4_1
      openssl
      libayatana-appindicator
      libsoup_3
      alsa-lib
      libpulseaudio
      libxkbcommon
      vulkan-loader
      wayland
      nss
      nspr
      at-spi2-core
      cups
      dbus
      expat
      libdrm
      mesa
    ];

    extraInstallCommands = ''
      if [ -f "$out/share/applications/pluely.desktop" ]; then
        substituteInPlace "$out/share/applications/pluely.desktop" \
          --replace "Exec=AppRun" "Exec=$out/bin/pluely"
      fi
    '';

    meta = with lib; {
      description = "AI chat client for local providers (Pluely AppImage release)";
      homepage = "https://github.com/iamsrikanthnani/pluely";
      license = licenses.mit;
      platforms = [ "x86_64-linux" ];
      mainProgram = "pluely";
    };
  };
in
{
  options.programs.pluely-appimage = {
    enable = mkEnableOption "Pluely (AppImage-wrapped release)";

    version = mkOption {
      type = types.str;
      default = "0.1.9";
      description = "Pluely release tag (without the leading 'v') to fetch.";
    };

    hash = mkOption {
      type = types.str;
      default = lib.fakeHash;
      description = ''
        sha256 hash of the AppImage for the chosen version. Leave as
        lib.fakeHash to get the real one printed by the build error on
        first switch, then set it here.
      '';
    };

    package = mkOption {
      type = types.package;
      default = pluely-pkg;
      description = "The Pluely package to use.";
    };
  };

  config = mkIf cfg.enable {
    home.packages = [ cfg.package ];
  };
}
