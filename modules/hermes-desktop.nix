# hermes-desktop — NixOS module wrapper around modules/hermes-desktop-pkg.nix
#
# Adds the Hermes Agent Electron desktop GUI to the system. The upstream
# `hermes-agent` flake ships a `desktop` package, but on this box it fails at
# launch (CLI+TUI-only Nix package, no apps/desktop; bundled Electron download
# blocked). The package file builds the real frontend from source and wires it
# to the working backend + system Electron on Wayland.
#
# Usage (in a NixOS config):
#   programs.hermes-desktop.enable = true;
{ config, lib, pkgs, inputs, ... }:

with lib;

let
  cfg = config.programs.hermes-desktop;
  hermes-desktop = import ./hermes-desktop-pkg.nix { inherit pkgs lib inputs; };
in {

  options.programs.hermes-desktop = {
    enable = mkEnableOption "Hermes Agent desktop GUI (Electron)";
  };

  config = mkIf cfg.enable {
    environment.systemPackages = [ hermes-desktop ];
  };

}
