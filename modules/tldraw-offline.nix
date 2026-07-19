# tldraw (offline) — NixOS module
#
# Wraps the official tldraw-offline AppImage so it installs system-wide with a
# desktop entry. tldraw-offline is a fully client-side build of tldraw — no
# server or sync needed, works offline.
#
# The AppImage source is provided as a flake input (`tldraw-offline-src`,
# `flake = false`) pointing at the repo's /latest/download redirect, so a
# `nix flake update tldraw-offline-src` pulls the newest release — no version
# is hardcoded here.
#
# The AppImage can't run as-is on NixOS (no FHS libs), so we exec it through
# `appimage-run`, which extracts it and runs it inside a bubblewrap FHS
# sandbox. No FUSE / host bwrap required (appimage-run brings both).
#
# Usage (in a NixOS config):
#   programs.tldraw-offline.enable = true;
{ config, lib, pkgs, inputs, ... }:

with lib;

let

  cfg = config.programs.tldraw-offline;

  # Fetched as a flake input (latest release, see flake.nix). This is the
  # AppImage file itself, so we reference it directly as the source.
  tldrawAppImage = inputs.tldraw-offline-src;

  tldraw-offline = pkgs.stdenv.mkDerivation {
    pname = "tldraw-offline";
    # Version tracks the upstream release via the input; we mark it latest.
    version = "latest";

    src = tldrawAppImage;

    dontUnpack = true;

    nativeBuildInputs = [
      pkgs.makeWrapper
    ];

    installPhase = ''
      runHook preInstall

      mkdir -p $out/bin $out/share/applications

      # Keep the AppImage intact; appimage-run extracts it at launch.
      cp ${tldrawAppImage} $out/share/tldraw-offline.AppImage
      chmod +x $out/share/tldraw-offline.AppImage

      makeWrapper ${pkgs.appimage-run}/bin/appimage-run $out/bin/tldraw-offline \
        --add-flags $out/share/tldraw-offline.AppImage

      cat > $out/share/applications/tldraw-offline.desktop <<EOF
[Desktop Entry]
Name=tldraw (offline)
Comment=Offline infinite-canvas whiteboard
Exec=tldraw-offline
Terminal=false
Type=Application
Categories=Graphics;Office;
EOF

      runHook postInstall
    '';
  };

in {

  options.programs.tldraw-offline = {
    enable = mkEnableOption "tldraw (offline) whiteboard";
  };

  config = mkIf cfg.enable {
    environment.systemPackages = [
      tldraw-offline
    ];
  };

}
