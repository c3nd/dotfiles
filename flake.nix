{
  description = "Cassiopeia Dendritic-style Dotfiles";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs";
    hyprland.url = "github:hyprwm/Hyprland";
    home-manager.url = "github:nix-community/home-manager";
    nh.url = "github:nix-community/nh";
    zen-browser.url = "github:0xc000022070/zen-browser-flake";
    openwhispr.url = "github:OpenWhispr/OpenWhispr";
    qtengine = {
      url = "github:kossLAN/qtengine";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    dank-material-shell = {
      url = "github:AvengeMedia/DankMaterialShell";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    { self, nixpkgs, home-manager, nh, zen-browser, openwhispr, qtengine, dank-material-shell, ... }@inputs:
    {
      nixosConfigurations.Cassiopeia = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit inputs; };
        modules = [
          ./hosts/cassiopeia/configuration.nix
        ];
      };

      homeConfigurations.kepler9001 = home-manager.lib.homeManagerConfiguration {
        pkgs = import nixpkgs { 
          system = "x86_64-linux"; 
          config.permittedInsecurePackages = [
            "electron-39.8.10"
            "xpdf-4.06"
          ];
          config.allowUnfree = true;
        };
        extraSpecialArgs = { inherit inputs nh; dmsPkgs = inputs.dank-material-shell.packages.x86_64-linux; };
        modules = [
          ./home/kepler9001/home.nix
          inputs.dank-material-shell.homeModules.dank-material-shell
        ];
      };
    };
}
