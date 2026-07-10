# Kuroya — NixOS module
#
# Builds the Kuroya native Rust code editor from the upstream source
# (passed in via the `kuroya-src` flake input, a non-flake source), installs a
# .desktop entry (so it shows up in XDG launchers such as caelestia), and
# registers it as the default handler for common text / source MIME types via
# the XDG mimeapps mechanism.
#
# Usage (in flake.nix / configuration.nix):
#   programs.kuroya.enable = true;
{ config, lib, pkgs, inputs, ... }:

with lib;

let
  cfg = config.programs.kuroya;

  kuroyaPkg = import ./../pkgs/kuroya.nix {
    inherit pkgs lib;
    kuroya-src = inputs.kuroya-src;
  };

  desktopFile = pkgs.makeDesktopItem {
    name = "kuroya";
    exec = "kuroya %U";
    icon = "kuroya";
    desktopName = "Kuroya";
    genericName = "Code Editor";
    comment = "A fast native code editor for local workspaces (egui/wgpu, no Electron)";
    categories = [ "Development" "TextEditor" "Utility" ];
    mimeTypes = [
      "text/plain"
      "text/x-shellscript"
      "text/x-c"
      "text/x-c++"
      "text/x-csharp"
      "text/x-python"
      "text/x-java"
      "text/x-rust"
      "text/x-go"
      "text/x-javascript"
      "text/x-typescript"
      "text/x-markdown"
      "text/x-lua"
      "text/x-nix"
      "text/x-yaml"
      "text/x-toml"
      "text/x-json"
      "text/html"
      "application/json"
    ];
    terminal = false;
    startupNotify = true;
  };
in
{
  options.programs.kuroya = {
    enable = mkEnableOption "Kuroya code editor";

    package = mkOption {
      type = types.package;
      default = kuroyaPkg;
      description = "The Kuroya package to install.";
    };
  };

  config = mkIf cfg.enable {
    environment.systemPackages = [
      # Wrap the package so the .desktop entry and icon ship with it.
      (pkgs.symlinkJoin {
        name = "kuroya-with-desktop";
        paths = [ cfg.package desktopFile ];
        postBuild = ''
          mkdir -p $out/share/icons/hicolor/256x256/apps
          cp ${cfg.package.src}/assets/logos/kuroya.png \
             $out/share/icons/hicolor/256x256/apps/kuroya.png
        '';
      })
    ];

    # Register Kuroya as the default app for the text/source MIME types above.
    # This writes ~/.config/mimeapps.list on `nixos-rebuild switch`.
    xdg.mime = {
      enable = true;
      defaultApplications = {
        "text/plain" = "kuroya.desktop";
        "text/x-shellscript" = "kuroya.desktop";
        "text/x-c" = "kuroya.desktop";
        "text/x-c++" = "kuroya.desktop";
        "text/x-csharp" = "kuroya.desktop";
        "text/x-python" = "kuroya.desktop";
        "text/x-java" = "kuroya.desktop";
        "text/x-rust" = "kuroya.desktop";
        "text/x-go" = "kuroya.desktop";
        "text/x-javascript" = "kuroya.desktop";
        "text/x-typescript" = "kuroya.desktop";
        "text/x-markdown" = "kuroya.desktop";
        "text/x-lua" = "kuroya.desktop";
        "text/x-nix" = "kuroya.desktop";
        "text/x-yaml" = "kuroya.desktop";
        "text/x-toml" = "kuroya.desktop";
        "text/x-json" = "kuroya.desktop";
        "text/html" = "kuroya.desktop";
        "application/json" = "kuroya.desktop";
      };
      addedAssociations = {
        "text/plain" = [ "kuroya.desktop" ];
        "text/x-rust" = [ "kuroya.desktop" ];
        "text/x-nix" = [ "kuroya.desktop" ];
        "text/x-python" = [ "kuroya.desktop" ];
        "text/x-markdown" = [ "kuroya.desktop" ];
      };
    };
  };
}
