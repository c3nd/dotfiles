# hermes-desktop-pkg — the Hermes Agent desktop GUI package (no options).
#
# Builds the Electron frontend from the `hermes-agent-src` flake input and
# assembles a launcher that runs it with the system Electron (pkgs.electron_41)
# on Wayland, wired to the backend from the `hermes-agent` flake input.
#
# Why this works (verified manually, then encoded):
#   * HERMES_DESKTOP_HERMES_ROOT -> a source root with hermes_cli/main.py +
#       apps/desktop/package.json (Electron resolves the backend here).
#   * HERMES_DESKTOP_PYTHON      -> the interpreter that runs `hermes serve`
#       (the hermes-agent env from the `hermes-agent` flake input).
#   * The frontend (apps/desktop) runs via the *system* wrapped Electron
#       (electron_41) — the npm-bundled Electron lacks NixOS glib/at-spi libs.
#   * Wayland env is passed through with safe fallbacks.
#
# Used by:
#   * modules/hermes-desktop.nix  (the NixOS module / option)
#   * flake.nix packages.x86_64-linux.hermes-desktop (for direct `nix build`)
{ pkgs, lib, inputs }:

let
  hermesSrc = inputs.hermes-agent-src;
  hermesEnv = inputs.hermes-agent.packages.${pkgs.stdenv.hostPlatform.system}.default;

  # Build the Electron frontend (apps/desktop) reproducibly from source.
  desktopFrontend = pkgs.buildNpmPackage {
    pname = "hermes-desktop-frontend";
    version = "0.18.0";

    src = hermesSrc;
    npmWorkspace = "apps/desktop";
    npmDepsHash = "sha256-qDXGL/INHPW0pTF4SRVL1dS5XVh2X85dEE4JhrAQeqU=";

    env = {
      # write-build-stamp.cjs reads this and skips `git rev-parse`.
      GITHUB_SHA = "0000000000000000000000000000000000000000";
      ELECTRON_SKIP_BINARY_DOWNLOAD = "1";
    };

    nativeBuildInputs = [ pkgs.nodejs_22 pkgs.python3 ];
    npmBuildScript = "build";

    installPhase = ''
      runHook preInstall
      mkdir -p $out
      cp -r . $out/apps-desktop
      runHook postInstall
    '';

    meta = with lib; {
      description = "Hermes Agent Electron desktop frontend (built from source)";
      license = licenses.mit;
      platforms = [ "x86_64-linux" ];
    };
  };

  # The built Electron app lives at apps/desktop inside the npm-built repo
  # copy (buildNpmPackage runs `npm run build` in place, producing
  # apps/desktop/dist + apps/desktop/electron/main.cjs).
  builtDesktop = "${desktopFrontend}/apps-desktop/apps/desktop";

in pkgs.stdenv.mkDerivation {
  pname = "hermes-desktop";
  version = "0.18.0";

  dontUnpack = true;
  dontBuild = true;

  nativeBuildInputs = [ pkgs.makeWrapper ];

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin $out/share/applications

    # buildNpmPackage with `npmWorkspace = "apps/desktop"` builds the app
    # into <frontend>/apps-desktop/apps/desktop (the workspace is nested
    # under the copied repo root). That nested dir is the real Electron app
    # (dist/ + electron/main.cjs + node_modules).

    # Source root the Electron shell uses to find hermes_cli + apps/desktop.
    cp -r ${hermesSrc} $out/share/hermes-desktop-src
    chmod -R u+w $out/share/hermes-desktop-src
    rm -rf $out/share/hermes-desktop-src/apps/desktop
    cp -r ${builtDesktop} $out/share/hermes-desktop-src/apps/desktop

    # Frontend dir the system Electron runs against.
    mkdir -p $out/share/hermes-desktop
    cp -r ${builtDesktop}/. $out/share/hermes-desktop/

    # Electron resolves runtime native deps from process.resourcesPath
    # (= <appdir>/resources). stage-native-deps.cjs builds them under
    # build/native-deps; electron-builder would ship that via extraResources.
    # We copy it into place so simple-git / node-pty require()s resolve.
    mkdir -p $out/share/hermes-desktop/resources
    cp -r ${builtDesktop}/build/native-deps $out/share/hermes-desktop/resources/native-deps

    # Launcher.
    makeWrapper ${pkgs.electron_41}/bin/electron $out/bin/hermes-desktop \
      --add-flags "--ozone-platform=wayland" \
      --add-flags "--enable-features=WaylandWindowDecorations" \
      --add-flags "$out/share/hermes-desktop" \
      --set HERMES_DESKTOP_HERMES_ROOT "$out/share/hermes-desktop-src" \
      --set HERMES_DESKTOP_PYTHON "${hermesEnv}/bin/python3" \
      --set-default WAYLAND_DISPLAY "wayland-1" \
      --set-default DISPLAY ":0" \
      --set-default XDG_RUNTIME_DIR "/run/user/1000"

    cat > $out/share/applications/hermes-desktop.desktop <<EOF
[Desktop Entry]
Name=Hermes Desktop
Comment=Hermes Agent desktop GUI (Electron)
Exec=$out/bin/hermes-desktop
Terminal=false
Type=Application
Categories=Network;Chat;Utility;
StartupWMClass=hermes
EOF

    runHook postInstall
  '';

  meta = with lib; {
    description = "Hermes Agent desktop GUI launcher (Electron on Wayland)";
    license = licenses.mit;
    platforms = [ "x86_64-linux" ];
    mainProgram = "hermes-desktop";
  };
}
