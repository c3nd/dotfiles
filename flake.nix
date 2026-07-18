{
  ##############################################################################
  # Milkdromeda — NixOS + Home Manager system flake
  #
  # This flake builds the system configuration for the `Milkdromeda` host.
  # The desktop stack is Hyprland + caelestia-shell, with Home Manager managing
  # the `kepler452` user environment.
  #
  # Rebuild with:  sudo nixos-rebuild switch --flake .#Milkdromeda
  # User-only changes:  home-manager switch --flake .#kepler452
  ##############################################################################

  description = "Milkdromeda System";

  ##############################################################################
  # Inputs (external flakes this configuration depends on)
  ##############################################################################
  inputs = {
    # The package set. Pinned to the unstable channel for latest packages.
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";

    # Wayland compositor.
    hyprland.url = "github:hyprwm/Hyprland";

    # Prebuilt browser flakes.
    zen-browser.url = "github:0xc000022070/zen-browser-flake";
    brave-previews.url = "github:drishal/brave-browser-flake";
    brave-previews.inputs.nixpkgs.follows = "nixpkgs";

    # Desktop environment / shell.
    caelestia-shell = {
      url = "github:caelestia-dots/shell";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    qtengine = {
      url = "github:kossLAN/qtengine";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # User environment management.
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Nix helper CLI (nh) — rebuild/clean/rollback ergonomics.
    nh = {
      url = "github:nix-community/nh";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Kopuz music player (Rust, built from source via crane). Ships its own
    # Cachix cache so we pull prebuilt binaries instead of compiling.
    kopuz.url = "github:temidaradev/kopuz";

    # Cake Wallet binary release (non-flake source — `flake = false`).
    cake-wallet-src = {
      url = "https://github.com/cake-tech/cake_wallet/releases/download/v6.1.2/Cake_Wallet_v6.1.2_Linux.tar.xz";
      flake = false;
    };

    # Kuroya code editor — source tree (non-flake source — `flake = false`).
    # Pinned to the v0.1.6 release tag.
    kuroya-src = {
      url = "github:redmarklabscom/kuroya?ref=v0.1.6";
      flake = false;
    };
  };

  ##############################################################################
  # Outputs (what this flake produces)
  ##############################################################################
  outputs =
  { self, nixpkgs, home-manager, nh, zen-browser, cake-wallet-src, brave-previews, kuroya-src, kopuz, ... }@inputs:
  {
    ############################################################################
    # Standalone NixOS module: builds the Cake Wallet package from a binary
    # release. Re-usable via `nixosModules.cake-wallet`.
    ############################################################################
    nixosModules.cake-wallet = import ./modules/cake-wallet.nix;

    ############################################################################
    # Standalone NixOS module: builds the Kuroya Rust code editor from source.
    # Re-usable via `nixosModules.kuroya`.
    ############################################################################
    nixosModules.kuroya = import ./modules/kuroya.nix;

    ############################################################################
    # The system configuration for the `Milkdromeda` host.
    ############################################################################
    nixosConfigurations.Milkdromeda = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      # Pass the full inputs set down so modules can reach flake inputs
      # (e.g. cake-wallet-src, browsers, caelestia-shell).
      specialArgs = { inherit inputs; };

      modules = [
        # ---- Core system config -------------------------------------------
        ./configuration.nix
        ./modules/qtengine.nix

        # ---- Cake Wallet package (enabled below) --------------------------
        ./modules/cake-wallet.nix
        {
          programs.cake-wallet.enable = true;
        }

        # ---- Kuroya code editor (enabled below) ---------------------------
        ./modules/kuroya.nix
        {
          programs.kuroya.enable = true;
        }

        # ---- Kopuz music player (replaces Strawberry) ---------------------
        {
          environment.systemPackages = [
            kopuz.packages.x86_64-linux.default
          ];
        }

        # ---- Home Manager (manages the `kepler452` user) ------------------
        home-manager.nixosModules.home-manager
        {
          home-manager = {
            extraSpecialArgs = { inherit inputs nh; };
            useGlobalPkgs = true;
            useUserPackages = true;
            users.kepler452 = { ... }: {
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

    ############################################################################
    # Standalone Home Manager configuration for the `kepler452` user.
    # Lets `home-manager switch --flake .#kepler452` apply user-only changes
    # (no sudo / no full system rebuild needed).
    ############################################################################
    homeConfigurations."kepler452" = home-manager.lib.homeManagerConfiguration {
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
      extraSpecialArgs = { inherit inputs nh; };
      modules = [
        ./home.nix
        inputs.caelestia-shell.homeManagerModules.default
      ];
    };
  };
}
