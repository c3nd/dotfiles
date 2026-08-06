{
  description = "Cassiopeia Dendritic-style Dotfiles";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-25.11";
    home-manager.url = "github:nix-community/home-manager/release-25.11";
    nh.url = "github:nix-community/nh";
    zen-browser.url = "github:0xc000022070/zen-browser-flake";
    openwhispr.url = "github:OpenWhispr/OpenWhispr";
  };

  outputs =
    { self, nixpkgs, home-manager, nh, zen-browser, openwhispr, ... }@inputs:
    {
      nixosConfigurations.Cassiopeia = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit inputs; };
        modules = [
          ./hosts/cassiopeia/configuration.nix
        ];
      };

      homeConfigurations.kepler9001 = home-manager.lib.homeManagerConfiguration {
        pkgs = import nixpkgs { system = "x86_64-linux"; };
        extraSpecialArgs = { inherit inputs nh; };
        modules = [
          ./home/kepler452/home.nix
        ];
      };
    };
}
