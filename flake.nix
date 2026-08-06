{
  description = "Cassiopeia Dendritic-style Dotfiles";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    home-manager.url = "github:nix-community/home-manager";
    nh.url = "github:nix-community/nh";
    zen-browser.url = "github:zen-browser-desktop/flake";
    openwhispr.url = "github:OpenWhispr/OpenWhispr";
  };

  outputs =
    { self, nixpkgs, home-manager, nh, zen-browser, openwhispr, ... }@inputs:
    {
      nixosConfigurations.cassiopeia = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit inputs; };
        modules = [
          ./hosts/cassiopeia/configuration.nix
          ./modules/nixos/boot.nix
          ./modules/nixos/networking.nix
          ./modules/nixos/hardware.nix
          ./modules/nixos/desktop.nix
          ./modules/nixos/packages.nix
          openwhispr.nixosModules.default
        ];
      };

      homeConfigurations.kepler452 = home-manager.lib.homeManagerConfiguration {
        pkgs = import nixpkgs { system = "x86_64-linux"; };
        extraSpecialArgs = { inherit inputs nh; };
        modules = [
          ./home/kepler452/home.nix
          ./modules/home/shell.nix
          ./modules/home/editor.nix
          ./modules/home/desktop.nix
        ];
      };
    };
}
