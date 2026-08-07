# qtengine — NixOS module
#
# Enables the qtengine Qt platform theme (pulled from the qtengine flake input)
# so Qt apps match the DMS/Qt styling.
{ config, pkgs, inputs, ... }:

{
    imports = [inputs.qtengine.nixosModules.default];

    programs.qtengine = {
        enable = true;
    };

}
