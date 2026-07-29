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

  # Helper aligned with nixpkgs makeDesktopEntry conventions.
  desktopEntry = pkgs.makeDesktopEntry {
    name = name;
    desktopName = displayName;
    exec = binaryPath;
    icon = iconName;
    genericName = generic;
    categories = categories;
    terminal = isTerminal;
    comment = packageDescription;
    startupNotify = true;
  };

  freecad = desktopEntry {
    name = "freecad";
    displayName = "FreeCAD";
    binaryPath = "${pkgs.freecad}/bin/FreeCAD";
    icon = "freecad";
    generic = "3D CAD Modeler";
    categories = "Graphics;CAD;Engineering;";
    isTerminal = false;
    packageDescription = "General purpose Open Source 3D CAD/MCAD modeler";
  };

  librecad = desktopEntry {
    name = "librecad";
    displayName = "LibreCAD";
    binaryPath = "${pkgs.librecad}/bin/librecad";
    icon = "librecad";
    generic = "2D CAD Drafting";
    categories = "Graphics;CAD;Engineering;";
    isTerminal = false;
    packageDescription = "2D CAD package based on Qt";
  };

  openscad = desktopEntry {
    name = "openscad";
    displayName = "OpenSCAD";
    binaryPath = "${pkgs.openscad}/bin/openscad";
    icon = "openscad";
    generic = "3D Parametric Modeler";
    categories = "Graphics;CAD;Engineering;";
    isTerminal = false;
    packageDescription = "3D parametric model compiler";
  };

  gmsh = desktopEntry {
    name = "gmsh";
    displayName = "Gmsh";
    binaryPath = "${pkgs.gmsh}/bin/gmsh";
    icon = "gmsh";
    generic = "3D Mesh Generator";
    categories = "Science;Physics;Engineering;CAD;";
    isTerminal = false;
    packageDescription = "Three-dimensional finite element mesh generator";
  };

  openvsp = mkIf config.programs.openvsp.enable (pkgs.makeDesktopEntry {
    name = "openvsp";
    desktopName = "OpenVSP";
    exec = "${config.programs.openvsp.package}/bin/vsp";
    icon = "openvsp";
    generic = "Aerospace Vehicle Conceptual Design";
    categories = "Science;Physics;Engineering;CAD;Aviation;";
    terminal = false;
    comment = "Parametric aircraft/spacecraft geometry tool";
    startupNotify = true;
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
