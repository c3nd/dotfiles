# Kuroya — a native Rust code editor (egui/eframe + wgpu, no Electron/webview).
#
# Built from source with buildRustPackage. Kuroya is not in nixpkgs (yet), so
# we vendor it from the upstream repo (passed in as `kuroya-src`, a
# `flake = false` flake input). Their committed Cargo.lock has no git deps, so
# it vendors cleanly.
#
# Arguments:
#   pkgs        - the nixpkgs package set
#   lib         - nixpkgs lib
#   kuroya-src  - path to the kuroya source tree (inputs.kuroya-src)
{ pkgs, lib, kuroya-src }:

let
  # Runtime libs the binary dlopen()s (vulkan loader, wayland/xkb, fonts, GL).
  runtimeLibs = pkgs.lib.makeLibraryPath [
    pkgs.vulkan-loader
    pkgs.libxkbcommon
    pkgs.fontconfig
    pkgs.freetype
    pkgs.mesa
    pkgs.libGL
    pkgs.wayland
  ];
in
pkgs.rustPlatform.buildRustPackage {
  pname = "kuroya";
  version = "0.1.6";

  src = kuroya-src;

  # Vendored deps come straight from the repo's committed lockfile (no git deps).
  cargoLock = {
    lockFile = "${kuroya-src}/Cargo.lock";
  };
  # Hash of the vendored dependency tarball. First build fails with the real
  # hash printed; paste it in here.
  cargoHash = lib.fakeHash;

  # Build only the app crate (kuroya-core is pulled in as a workspace member).
  cargoBuildFlags = [ "-p" "kuroya-app" ];
  cargoTestFlags = [ "-p" "kuroya-app" ];

  # Native headers needed at compile time (git2 -> libgit2, pkg-config, etc.).
  nativeBuildInputs = [ pkgs.pkg-config pkgs.makeWrapper ];
  buildInputs = [
    pkgs.openssl
    pkgs.fontconfig
    pkgs.freetype
    pkgs.libxkbcommon
    pkgs.vulkan-loader
    pkgs.vulkan-headers
    pkgs.wayland
    pkgs.libGL
    pkgs.libx11
    pkgs.libxcursor
    pkgs.libxrandr
    pkgs.libxinerama
    pkgs.libxcb
    pkgs.zlib
    pkgs.alsa-lib
    pkgs.expat
    pkgs.libgit2
    pkgs.mesa
  ];

  # Skip the (slow / occasionally flaky) upstream test suite for the system build.
  doCheck = false;

  # Make sure the runtime libs the app dlopen()s are on the path once installed.
  postFixup = ''
    wrapProgram "$out/bin/kuroya" \
      --prefix LD_LIBRARY_PATH : "${runtimeLibs}"
  '';

  meta = with lib; {
    description = "A fast native code editor for local workspaces (egui/wgpu, no Electron)";
    homepage = "https://github.com/redmarklabscom/kuroya";
    license = licenses.asl20;
    mainProgram = "kuroya";
    platforms = platforms.linux;
  };
}
