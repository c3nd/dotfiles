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
{ config, lib, pkgs, meownotes, ... }:

with lib;

let
  cfg = config.programs.meownotes;

  # The meownotes package comes from the `meownotes` flake input (a path
  # flake at ~/Projects/meownotes). Its source is therefore an in-store path
  # that pure evaluation is allowed to read — no ../../Projects/... host-path
  # escape (which trips "access to absolute path … forbidden in pure mode").
  meownotes-pkg = meownotes.packages.${pkgs.system}.default;
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
