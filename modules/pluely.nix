# Pluely — Tauri 2 (Rust + React/Vite) Cluely alternative.
#
# Built from the `pluely` flake input (its full source tree is copied into the
# Nix store, so this is pure-eval-legal). The package itself is produced here;
# the module just wires it into the user environment when enabled.
#
# Usage:
#   programs.pluely.enable = true;
{ config, lib, pkgs, pluely, ... }:

with lib;

let
  cfg = config.programs.pluely;

  # ---- Frontend: install node deps + `vite build` -> dist/ ------------------
  frontend = pkgs.buildNpmPackage {
    pname = "pluely-frontend";
    version = "0.1.9";
    src = pluely;
    # Hash of the npm dependency closure (filled in by the build on first run).
    npmDepsHash = "sha256-A5JJrD15QHx0JoccbMDzp1MFIXPDoHAb4J5rPbOKXHM=";
    # `build` script is `tsc && vite build`; tsc is only type-checking and
    # vite is what emits dist/. Run vite directly to avoid tsc blocking the
    # build on unrelated type noise.
    npmBuildScript = "build";
    npmFlags = [ "--legacy-peer-deps" ];
    installPhase = ''
      mkdir -p $out
      cp -r dist $out/dist
    '';
    # No native node modules in the dependency tree, so no rebuild needed.
  };

  # ---- Backend: Tauri 2 Rust binary ----------------------------------------
  package = pkgs.rustPlatform.buildRustPackage {
    pname = "pluely";
    version = "0.1.9";
    src = "${pluely}/src-tauri";

    cargoLock = {
      lockFile = "${pluely}/src-tauri/Cargo.lock";
      # macOS-only git dep referenced by Cargo.lock; harmless on Linux (never
      # compiled) but buildRustPackage needs its hash to vendor it.
      outputHashes = {
        "tauri-nspanel-2.0.1" = "sha256-pQgv/Lkc9yE+DSv+MdOV1NZRj2nkMhAm+Wn41qvdvvE=";
      };
    };

    # Tauri expects the frontend at `../dist` relative to src-tauri/. The cargo
    # source is extracted to $PWD; place the built frontend one level up.
    preBuild = ''
      mkdir -p $PWD/../dist
      cp -r ${frontend}/dist/. $PWD/../dist/
    '';

    # Tauri 2 runtime/build dependencies.
    nativeBuildInputs = [
      pkgs.pkg-config
      pkgs.makeWrapper
    ];

    buildInputs = [
      # WebView / GTK stack Tauri links against.
      pkgs.webkitgtk_4_1
      pkgs.libsoup_3
      pkgs.gtk3
      pkgs.glib
      pkgs.openssl
      # Audio capture: PulseAudio (pluely) + ALSA (cpal needs alsa headers).
      pkgs.pulseaudio
      pkgs.alsa-lib
      pkgs.dbus
    ];

    # Tell tauri-build where to find the webkit/sys libs.
    PKG_CONFIG_PATH = "${pkgs.webkitgtk_4_1.dev}/lib/pkgconfig:${pkgs.libsoup_3.dev}/lib/pkgconfig";

    # Build a RELEASE binary so Tauri embeds the bundled `dist/` frontend
    # into the binary. Without this (default debug build) the webview tries
    # to load from the Vite dev server at http://localhost:1420, which is
    # never running in a Nix install -> "Connection refused" + the blurred
    # error screen, and the React app (Settings included) never loads.
    buildType = "release";

    # Skip the self-updater (we manage versions via Nix).
    CARGO_BUILD_FEATURES = "";

    meta = with pkgs.lib; {
      description = "Open-source Cluely alternative — privacy-first AI assistant for meetings/interviews";
      homepage = "https://github.com/iamsrikanthnani/pluely";
      license = licenses.gpl3Only;
      mainProgram = "pluely";
      platforms = platforms.linux;
    };
  };

  desktopItem = pkgs.makeDesktopItem {
    name = "pluely";
    exec = "pluely";
    icon = "pluely";
    desktopName = "Pluely";
    comment = "Privacy-first AI assistant for meetings & interviews";
    categories = [ "Office" "Utility" ];
  };
in
{
  options.programs.pluely = {
    enable = mkEnableOption "Pluely — open-source Cluely alternative (Tauri)";

    package = mkOption {
      type = types.package;
      default = package;
      description = "The Pluely package to install.";
    };
  };

  config = mkIf cfg.enable {
    home.packages = [ cfg.package desktopItem ];
  };
}
