# CAD desktop entries — NixOS module
#
# Adds .desktop files for CAD tools that need them so they show up in the
# app launcher. Writes .desktop files directly via writeTextFile to avoid
# strict desktop-entry validation in makeDesktopItem.
#
{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.programs.cad-desktop-entries;

  desktopFile = name: binaryPath: displayName: iconName: genericName: categoriesList: isTerminal: packageDescription:
    pkgs.writeTextFile {
      inherit name;
      destination = "/share/applications/${name}.desktop";
      text = ''
        [Desktop Entry]
        Type=Application
        Name=${displayName}
        GenericName=${genericName}
        Comment=${packageDescription}
        Exec=${binaryPath}
        Icon=${iconName}
        Terminal=${if isTerminal then "true" else "false"}
        StartupNotify=true
        Categories=${categoriesList};
      '';
    };

  freecad = desktopFile "freecad"
    "${pkgs.freecad}/bin/FreeCAD"
    "FreeCAD"
    "freecad"
    "3D CAD Modeler"
    "Graphics;Engineering"
    false
    "General purpose Open Source 3D CAD/MCAD modeler";

  librecad = desktopFile "librecad"
    "${pkgs.librecad}/bin/librecad"
    "LibreCAD"
    "librecad"
    "2D CAD Drafting"
    "Graphics;Engineering"
    false
    "2D CAD package based on Qt";

  openscad = desktopFile "openscad"
    "${pkgs.openscad}/bin/openscad"
    "OpenSCAD"
    "openscad"
    "3D Parametric Modeler"
    "Graphics;Engineering"
    false
    "3D parametric model compiler";

  gmsh = desktopFile "gmsh"
    "${pkgs.gmsh}/bin/gmsh"
    "Gmsh"
    "gmsh"
    "3D Mesh Generator"
    "Science;Engineering"
    false
    "Three-dimensional finite element mesh generator";

  openvsp = desktopFile "openvsp"
    "${config.programs.openvsp.package}/bin/vsp"
    "OpenVSP"
    "openvsp"
    "Aerospace Vehicle Conceptual Design"
    "Science;Engineering"
    false
    "Parametric aircraft/spacecraft geometry tool";

in
{
  options.programs.cad-desktop-entries = {
    enable = mkEnableOption "CAD desktop entries for FreeCAD/LibreCAD/OpenSCAD/Gmsh/OpenVSP";
  };

  config = mkIf cfg.enable {
    environment.systemPackages = [
      freecad
      librecad
      openscad
      gmsh
      openvsp
    ];
  };
}
