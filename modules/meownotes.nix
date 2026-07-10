# meownotes — Home Manager module
#
# Wires the local-first meeting summarizer into the `kepler452` user
# environment, matching the conventions used by the other dotfiles app
# modules (programs.<name> with enable / package / outputDir).
#
# The package is built from the source tree at ~/Projects/meownotes (the
# `src` is resolved here, so the meownotes repo stays self-contained and the
# dotfiles just point at it — no fetchurl / hash dance for a personal tool).
#
# Usage (in home.nix):
#   programs.meownotes.enable = true;
#   programs.meownotes.outputDir = "~/meownotes-notes";  # optional override
{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.programs.meownotes;

  # Source tree of the tool (relative to $HOME). Adjust if you move it.
  meownotesSrc = "${config.home.homeDirectory}/Projects/meownotes";

  meownotes-pkg = pkgs.callPackage ../../Projects/meownotes/nixos/default.nix {
    src = meownotesSrc;
    python = pkgs.python3;
  };
in
{
  options.programs.meownotes = {
    enable = mkEnableOption "meownotes — local-first meeting summarizer";

    package = mkOption {
      type = types.package;
      default = meownotes-pkg;
      description = "The meownotes package to install.";
    };

    outputDir = mkOption {
      type = types.str;
      default = "~/meownotes-notes";
      description = "Default directory for generated meeting notes (.md / .txt / .wav).";
    };
  };

  config = mkIf cfg.enable {
    home.packages = [ cfg.package ];

    # Make the default output dir exist so `meownotes run` never fails.
    home.file."${cfg.outputDir}".source = pkgs.runCommand "meownotes-notes-dir" { } ''
      mkdir -p $out
    '';
  };
}
