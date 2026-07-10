{
  ##############################################################################
  # Milkdromeda — NixOS + Home Manager system flake
  #
  # This flake builds the system configuration for the `Milkdromeda` host.
  # The desktop stack is Hyprland + caelestia-shell, with Home Manager managing
  # the `kepler452` user environment.
  #
  # Rebuild with:  sudo nixos-rebuild switch --flake .#Milkdromeda
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

    # Misc apps / sources.
    antigravity-nix = {
      url = "github:jacopone/antigravity-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
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

    # Pluely — Tauri 2 Cluely alternative (open-source, privacy-first).
    # Consumed as a github flake input; its source is fetched into the store
    # (pure-eval-legal). The HM module builds `pluely.packages.<sys>.default`.
    pluely = {
      url = "github:iamsrikanthnani/pluely";
      flake = false;
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  ##############################################################################
  # Outputs (what this flake produces)
  ##############################################################################
  outputs =
  { self, nixpkgs, home-manager, pluely, zen-browser, cake-wallet-src, brave-previews, antigravity-nix, kuroya-src, ... }@inputs:
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
    # Standalone Home Manager module: Pluely (Tauri 2 Cluely alternative).
    # Re-usable via `nixosModules.pluely` (built from the pluely flake input).
    ############################################################################
    nixosModules.pluely = import ./modules/pluely.nix;

    ############################################################################
    # Standalone NixOS module: local TurboQuant llama.cpp + Whisper STT stack.
    # Re-usable via `nixosModules.llm-stack`.
    ############################################################################
    nixosModules.llm-stack = import ./modules/llm-stack.nix;

    ############################################################################
    # The system configuration for the `Milkdromeda` host.
    ############################################################################
    nixosConfigurations.Milkdromeda = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      # Pass the full inputs set down so modules can reach flake inputs
      # (e.g. cake-wallet-src, browsers, caelestia-shell).
      specialArgs = { inherit inputs pluely; };

      modules = [
        # ---- Core system config -------------------------------------------
        ./configuration.nix
        ./modules/qtengine.nix

        # ---- Cake Wallet package (enabled below) --------------------------
        ./modules/cake-wallet.nix
        {
          programs.cake-wallet.enable = true;
        }

        # ---- Kuroya code editor (enabled below) --------------------------
        ./modules/kuroya.nix
        {
          programs.kuroya.enable = true;
        }

        # ---- Local TurboQuant LLM + Whisper STT stack (enabled below) -----
        ./modules/llm-stack.nix
        {
          services.llm-stack.enable = true;
        }

        # ---- Antigravity apps (CLI + base app) ----------------------------
        {
          environment.systemPackages = [
            antigravity-nix.packages.x86_64-linux.default # Base App
            antigravity-nix.packages.x86_64-linux.google-antigravity-cli # CLI
          ];
        }

        # ---- Home Manager (manages the `kepler452` user) ------------------
        home-manager.nixosModules.home-manager
        {
          home-manager = {
            extraSpecialArgs = { inherit inputs pluely; };
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
    };
}
