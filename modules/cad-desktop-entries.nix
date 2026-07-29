# CAD desktop entries — NixOS module
#
# Adds .desktop files for CAD tools that need them so they show up in the
# app launcher. The nixpkgs versions of several GUI CAD apps skip the
# .desktop file; we install explicit ones here for FreeCAD, LibreCAD,
# OpenSCAD, Gmsh, and OpenVSP.
#
# Usage:
#   programs.cad-desktop-entries.enable = true;
#
{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.programs.cad-desktop-entries;

  # Helper aligned with nixpkgs makeDesktopItem conventions.
  desktopEntry = name: binaryPath: displayName: iconName: generic: categories: isTerminal: packageDescription:
    pkgs.makeDesktopItem {
      inherit name categories;
      desktopName = displayName;
      exec = binaryPath;
      icon = iconName;
      genericName = generic;
      terminal = isTerminal;
      comment = packageDescription;
      startupNotify = true;
      type = "Application";
    };

  freecad = desktopEntry "freecad" "${pkgs.freecad}/bin/FreeCAD" "FreeCAD" "freecad" "3D CAD Modeler" "Graphics;CAD;Engineering;" false "General purpose Open Source 3D CAD/MCAD modeler";
  librecad = desktopEntry "librecad" "${pkgs.librecad}/bin/librecad" "LibreCAD" "librecad" "2D CAD Drafting" "Graphics;CAD;Engineering;" false "2D CAD package based on Qt";
  openscad = desktopEntry "openscad" "${pkgs.openscad}/bin/openscad" "OpenSCAD" "openscad" "3D Parametric Modeler" "Graphics;CAD;Engineering;" false "3D parametric model compiler";
  gmsh = desktopEntry "gmsh" "${pkgs.gmsh}/bin/gmsh" "Gmsh" "gmsh" "3D Mesh Generator" "Science;Physics;Engineering;CAD;" false "Three-dimensional finite element mesh generator";

  openvsp = mkIf config.programs.openvsp.enable (pkgs.makeDesktopItem {
    name = "openvsp";
    desktopName = "OpenVSP";
    exec = "${config.programs.openvsp.package}/bin/vsp";
    icon = "openvsp";
    genericName = "Aerospace Vehicle Conceptual Design";
    categories = "Science;Physics;Engineering;CAD;Aviation;";
    terminal = false;
    comment = "Parametric aircraft/spacecraft geometry tool";
    startupNotify = true;
    type = "Application";
  });

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
