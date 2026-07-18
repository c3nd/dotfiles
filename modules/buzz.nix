# Buzz — NixOS module
#
# Installs the Buzz offline Whisper audio transcription/translation app
# (from the `buzz` flake input) and ships a .desktop entry so it shows up in
# XDG launchers such as caelestia.
#
# The buzz flake's package is an FHS env whose binary is versioned
# (`buzz-1.4.4`); we wrap it as a plain `buzz` command for a clean Exec=.
#
# Usage (in flake.nix):
#   programs.buzz.enable = true;
{ config, lib, pkgs, inputs, ... }:

with lib;

let
  cfg = config.programs.buzz;

  # Bumped in lockstep with the buzz flake's `version` (currently 1.4.4).
  buzzBin = "buzz-1.4.4";

  # Clean `buzz` command -> the versioned FHS launcher.
  buzzWrapper = pkgs.writeShellScriptBin "buzz" ''
    exec ${cfg.package}/bin/${buzzBin} "$@"
  '';

  desktopFile = pkgs.makeDesktopItem {
    name = "buzz";
    exec = "buzz %U";
    icon = "audio-x-generic";
    desktopName = "Buzz";
    genericName = "Audio Transcription";
    comment = "Offline audio transcription and translation (Whisper, CUDA)";
    categories = [ "AudioVideo" "Audio" "Utility" ];
    mimeTypes = [
      "audio/x-wav"
      "audio/x-flac"
      "audio/mpeg"
      "audio/mp4"
      "audio/ogg"
      "audio/x-m4a"
      "video/mp4"
    ];
    terminal = false;
    startupNotify = true;
  };
in
{
  options.programs.buzz = {
    enable = mkEnableOption "Buzz offline audio transcription";

    package = mkOption {
      type = types.package;
      default = inputs.buzz.packages.${pkgs.stdenv.hostPlatform.system}.default;
      description = "The Buzz package (FHS env from the buzz flake input).";
    };
  };

  config = mkIf cfg.enable {
    environment.systemPackages = [
      # Wrap so the clean `buzz` command, .desktop entry ship together.
      (pkgs.symlinkJoin {
        name = "buzz-with-desktop";
        paths = [ cfg.package buzzWrapper desktopFile ];
      })
    ];
  };
}
