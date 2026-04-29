{config, pkgs, inputs,...}:

{
    imports = [inputs.qtengine.nixosModules.default];

    programs.qtengine = {
        enable = true;
    };

}
