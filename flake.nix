{
  description = "Milkdromeda System";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    hyprland.url = "github:hyprwm/Hyprland";
    cake-wallet-src = {
      url = "https://github.com/cake-tech/cake_wallet/releases/download/v6.1.2/Cake_Wallet_v6.1.2_Linux.tar.xz";
      flake = false;
    };
    zen-browser.url = "github:0xc000022070/zen-browser-flake";
    brave-previews.url = "github:drishal/brave-browser-flake";
    brave-previews.inputs.nixpkgs.follows = "nixpkgs";
    caelestia-shell = {
      url = "github:caelestia-dots/shell";
      inputs.nixpkgs.follows = "nixpkgs";
      };
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    qtengine = {
      url = "github:kossLAN/qtengine";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager, zen-browser, cake-wallet-src, brave-previews, ... } @ inputs:
  {
    nixosModules.cake-wallet = import ./modules/cake-wallet.nix;

    nixosConfigurations.Milkdromeda = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = { inherit inputs; };
      modules = [
        ./configuration.nix
        ./modules/cake-wallet.nix {
          programs.cake-wallet.enable = true;
        }
        home-manager.nixosModules.home-manager
        {
          home-manager = {
            extraSpecialArgs = { inherit inputs; };
            useGlobalPkgs = true;
            useUserPackages = true;
            users.kepler452 = {...}: {
              imports = [
                ./home.nix
                inputs.caelestia-shell.homeManagerModules.default
              ];
            };
            backupFileExtension = "HMbackup";
          };
        }
      ];
    };
  };
}

