# Milkdromeda — NixOS system configuration
#
# Host:        Milkdromeda (x86_64-linux)
# Desktop:     Hyprland + caelestia-shell (configured in home.nix)
# Boot:        systemd-boot (EFI)
#
# This file only holds *system-level* settings. Per-user settings (shell,
# dotfiles, user packages, caelestia) live in home.nix via Home Manager.
{ config, lib, pkgs, inputs, ... }:

{
  ##############################################################################
  # Imports
  ##############################################################################
  imports = [
    # Results of the hardware scan (filesystems, boot devices, CPU).
    ./hardware-configuration.nix
    # qtengine Qt theming module.
    ./modules/qtengine.nix
  ];

  ##############################################################################
  # Boot loader & kernel
  ##############################################################################
  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Run the latest available kernel.
  boot.kernelPackages = pkgs.linuxPackages_latest;

  ##############################################################################
  # Networking
  ##############################################################################
  networking.hostName = "Milkdromeda";

  # Manage network connections interactively with `nmcli` / `nmtui`.
  networking.networkmanager.enable = true;

  # Firewall is disabled (single-user workstation behind a router).
  networking.firewall.enable = false;

  ##############################################################################
  # Localization
  ##############################################################################
  time.timeZone = "America/Phoenix";

  ##############################################################################
  # Hardware
  ##############################################################################
  # NVIDIA GPU + Intel iGPU (Prime sync / Optimus).
  hardware.nvidia = {
    modesetting.enable = true;
    package = config.boot.kernelPackages.nvidiaPackages.legacy_580;
    powerManagement.enable = false;
    nvidiaSettings = true;
    open = false;
    prime = {
      sync.enable = true;
      intelBusId = "PCI:0:2:0";
      nvidiaBusId = "PCI:1:0:0";
    };
  };

  # Enable the Mesa/OpenGL graphics stack.
  hardware.graphics.enable = true;

  # Bluetooth + drawing tablet support.
  hardware.bluetooth.enable = true;
  hardware.opentabletdriver.enable = true;

  ##############################################################################
  # Display server & desktop
  ##############################################################################
  # XWayland + keyboard auto-repeat tuning.
  services.xserver = {
    enable = true;
    autoRepeatDelay = 200;
    autoRepeatInterval = 35;
  };

  # Video drivers for the XWayland fallback.
  services.xserver.videoDrivers = [
    "nvidia"
    "modesetting"
  ];

  # Hyprland compositor (pinned to the flake input so portals stay in sync).
  programs.hyprland = {
    enable = true;
    package = inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.hyprland;
    # Keep the portal package in sync with the Hyprland package.
    portalPackage = inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.xdg-desktop-portal-hyprland;
  };

  # Login manager.
  services.displayManager.ly.enable = true;

  # Qt theming (qtengine module, imported above).
  programs.qtengine.enable = true;

  ##############################################################################
  # Audio, power & printing
  ##############################################################################
  # PipeWire sound server (with PulseAudio compatibility shim).
  services.pipewire = {
    enable = true;
    pulse.enable = true;
  };

  # Power management daemon + CUPS printing.
  services.upower.enable = true;
  services.printing.enable = true;

  # Cloudflare WARP VPN client.
  services.cloudflare-warp.enable = true;

  ##############################################################################
  # Touchpad
  ##############################################################################
  # Enabled by default in most desktop managers, declared explicitly here.
  services.libinput.enable = true;

  ##############################################################################
  # Users
  ##############################################################################
  users.users.kepler452 = {
    isNormalUser = true;
    extraGroups = [ "wheel" ]; # Enable `sudo` for the user.
    packages = with pkgs; [
      tree
    ];
  };

  ##############################################################################
  # Nix settings
  ##############################################################################
  # Enable the experimental `nix-command` + `flakes` features.
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # Allow unfree packages that this system relies on.
  nixpkgs.config.allowUnfreePredicate = pkg:
    (builtins.elem (lib.getName pkg) [
      "nvidia-x11"
      "nvidia-settings"
      "cloudflare-warp"
      "xnviewmp"
      "p7zip"
      "nvidia-kernel-modules"
    ])
    # CUDA toolkit components (unfree, CUDA EULA) — needed by the local
    # TurboQuant llama.cpp + Whisper STT stack (services.llm-stack).
    # Match by license so every cuda_*/libcu*/libnpp/… component is covered.
    || (let
          lics = let l = pkg.meta.license or [ ];
                 in if builtins.isList l then l else [ l ];
        in builtins.any
             (l: (l.shortName or "") == "cudaEula"
                 || (l.spdxId or "") == "LicenseRef-CUDA-EULA"
                 || lib.hasInfix "EULA" (l.fullName or "")
                 || lib.hasInfix "EULA" (l.shortName or ""))
             lics);

  ##############################################################################
  # System-wide programs
  ##############################################################################
  programs.nix-ld.enable = true;
  programs.fish.enable = true;
  programs.mtr.enable = true;

  # GnuPG agent with SSH support (used as the SSH agent).
  programs.gnupg.agent = {
    enable = true;
    enableSSHSupport = true;
  };

  ##############################################################################
  # Services
  ##############################################################################
  # OpenSSH daemon.
  services.openssh.enable = true;

  ##############################################################################
  # Fonts
  ##############################################################################
  fonts = {
    fontDir.enable = true;
    enableGhostscriptFonts = true;
    packages = with pkgs; [
      nerd-fonts.jetbrains-mono
    ];
  };

  ##############################################################################
  # System packages
  ##############################################################################
  # Full list lives in packages.nix (grouped by category).
  environment.systemPackages = import ./packages.nix { inherit pkgs; };

  ##############################################################################
  # State version
  ##############################################################################
  # The first NixOS version installed on this machine. Do NOT change unless
  # you have manually migrated all affected application data.
  # See `man configuration.nix` for details.
  system.stateVersion = "25.11";
}
