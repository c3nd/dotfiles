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

    # Handy — offline speech-to-text (Tauri, Nix-native). Replaces Buzz.
    handy = {
      url = "github:cjpais/Handy";
      inputs.nixpkgs.follows = "nixpkgs";
      # Handy's build pulls bun2nix (flake-parts + treefmt-nix) whose `systems`
      # input defaults to all 4 platforms incl. x86_64-darwin. Nixpkgs 26.11
      # dropped x86_64-darwin, so materializing that system crashes the build.
      # Pin bun2nix's `systems` to the linux-only set — we only need the linux
      # `packages.handy`. (See: nix-systems/default-linux)
      inputs.bun2nix.inputs.systems.url = "github:nix-systems/default-linux";
    };

    # tldraw (offline) — follow latest release via /latest/download redirect.
    # `flake = false` so the input is the AppImage file itself; bump with
    # `nix flake update tldraw-offline-src` when tldraw ships a new release.
    tldraw-offline-src = {
      url = "https://github.com/tldraw/tldraw-offline/releases/latest/download/tldraw-offline-linux-x86_64.AppImage";
      flake = false;
    };
    # Deliberately does NOT `follows = "nixpkgs"`: Hermes' flake-parts `systems`
    # list includes aarch64-darwin, and we don't want that evaluating the
    # system's 26.11 nixpkgs (which dropped darwin). Let it use its own nixpkgs
    # so the package stays self-contained.
    #
    # Pinned to main/HEAD (0.19.0, commit 3ef6bbd / 2026.07.21):
    # 0.17.0 at unpinned main (1310ceb) fails due to broken esbuild workspace
    # resolution in `hermes-tui` (`@hermes/shared/charge-settlement`).
    hermes-agent = {
      url = "github:NousResearch/hermes-agent/3ef6bbd20126";
    };

    # Raw Hermes Agent repo (same rev) used by modules/hermes-desktop-pkg.nix
    # to build the Electron frontend from source + as the backend source root.
    hermes-agent-src = {
      url = "github:NousResearch/hermes-agent/3ef6bbd20126";
      flake = false;
    };
  };

  ##############################################################################
  # Outputs (what this flake produces)
  ##############################################################################
  outputs =
    { self, nixpkgs, home-manager, nh, zen-browser, cake-wallet-src, brave-previews, kuroya-src, kopuz, handy, hermes-agent, tldraw-offline-src, ... }@inputs:
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
    # Standalone NixOS module: builds the Hermes desktop GUI (Electron) from
    # source and wires it to the working backend + system Electron on Wayland.
    # Re-usable via `nixosModules.hermes-desktop`.
    ############################################################################
    nixosModules.hermes-desktop = import ./modules/hermes-desktop.nix;

    nixosModules.cad-desktop-entries = import ./modules/cad-desktop-entries.nix;

    # Expose the assembled hermes-desktop package for direct `nix build
    # .#hermes-desktop` / verification (also what the module installs).
    packages.x86_64-linux.hermes-desktop = import ./modules/hermes-desktop-pkg.nix {
      pkgs = import nixpkgs { system = "x86_64-linux"; };
      lib = (import nixpkgs { system = "x86_64-linux"; }).lib;
      inputs = inputs;
    };

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

        # ---- Cake Wallet package (enabled below) -------------------------
        ./modules/cake-wallet.nix
        {
          programs.cake-wallet.enable = true;
        }

        # ---- Kuroya code editor (enabled below) ---------------------------
        ./modules/kuroya.nix
        {
          programs.kuroya.enable = true;
        }

        # ---- Handy offline speech-to-text (enabled below) ---------------
        handy.nixosModules.default
        {
          programs.handy.enable = true;
        }

        # ---- tldraw (offline whiteboard) — AppImage via appimage-run ---
        ./modules/tldraw-offline.nix
        {
          programs.tldraw-offline.enable = true;
        }

        # ---- Kopuz music player (replaces Strawberry) ---------------------
        {
          environment.systemPackages = [
            kopuz.packages.x86_64-linux.default
          ];
        }

        # ---- Hermes desktop GUI (Electron) — built from source -----------
        ./modules/hermes-desktop.nix
        {
          programs.hermes-desktop.enable = true;
        }

        # ---- Desktop entries for CAD tools that don't ship one ------------
        ./modules/cad-desktop-entries.nix
        {
          programs.cad-desktop-entries.enable = true;
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
      pkgs = import nixpkgs {
        system = "x86_64-linux";
        # Obsidian is unfree; allow just that package rather than blanket unfree.
        config.allowUnfreePredicate = p: builtins.elem (nixpkgs.lib.getName p) [ "obsidian" ];
      };
      extraSpecialArgs = { inherit inputs nh; };
      modules = [
        ./home.nix
        inputs.caelestia-shell.homeManagerModules.default
      ];
    };
  };
}
