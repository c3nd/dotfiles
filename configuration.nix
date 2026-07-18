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

  # Desktop portals: Hyprland backend (for screen capture / gsr -w portal)
  # plus the GTK backend (for file pickers if a GTK portal is ever needed).
  xdg.portal = {
    enable = true;
    extraPortals = [
      inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.xdg-desktop-portal-hyprland
      pkgs.xdg-desktop-portal-gtk
    ];
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
  # Sudo: passwordless for system rebuild + systemctl (so the agent can apply
  # system-level fixes without an interactive password prompt). Scoped to the
  # two commands it actually needs — NOT blanket NOPASSWD:ALL.
  # Use extraConfig (appends a literal line into /etc/sudoers, which always
  # exists + is read) rather than extraRules (writes to /etc/sudoers.d/, which
  # is absent on this box and would be silently ignored).
  ##############################################################################
  security.sudo.extraConfig = ''
    kepler452 ALL=(root) NOPASSWD: /run/current-system/sw/bin/nixos-rebuild, /run/current-system/sw/bin/systemctl
  '';

  ##############################################################################
  # GPU Screen Recorder — KMS capture capability
  ##############################################################################
  # gpu-screen-recorder spawns a helper (gsr-kms-server) to grab the screen
  # via KMS. That helper needs the cap_sys_admin Linux capability. The cap is
  # normally set in the nixpkgs build, but it gets stripped when the binary
  # comes from the binary cache (xattrs/caps don't survive cache downloads on
  # NixOS), so the recorder dies with "kms server died or never started".
  # Grant it at activation time via a setcap-enabled security wrapper. The
  # wrapper lands in /run/wrappers/bin (first on PATH), so gsr finds it
  # ahead of the bare store binary.
  security.wrappers.gsr-kms-server = {
    source = "${pkgs.gpu-screen-recorder}/bin/gsr-kms-server";
    capabilities = "cap_sys_admin=ep";
    owner = "root";
    group = "root";
    permissions = "u+rx,g+rx,o+rx";
  };

  ##############################################################################
  # Nix settings
  ##############################################################################
  # Enable the experimental `nix-command` + `flakes` features.
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # Binary caches: pull prebuilt paths instead of compiling from source.
  # Keep cache.nixos.org (default) and add public cachix caches.
  nix.settings.substituters = [
    "https://cache.nixos.org"
    "https://nix-community.cachix.org"
    "https://cuda-maintainers.cachix.org"
    "https://kopuz.cachix.org"
  ];
  nix.settings.trusted-public-keys = [
    "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
    "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Z9Iz52rXz24doJeTsuN8bjwc="
    "cuda-maintainers.cachix.org-1:0dq3bujKpuEPGUMXPcWe6Xsg52TCkEHwhT4SFgdHVR4="
    "kopuz.cachix.org-1:J2X3AnAYhKTJW5S3aCLoA1ckonQXVNZMQvhZA0YAufw="
  ];

  # Allow unfree packages that this system relies on.
  nixpkgs.config.allowUnfreePredicate = pkg:
    (builtins.elem (lib.getName pkg) [
      "nvidia-x11"
      "nvidia-settings"
      "cloudflare-warp"
      "xnviewmp"
      "p7zip"
      "nvidia-kernel-modules"
    ]);

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

  # Syncthing — continuous file sync (pair with phone / laptop).
  # Runs as the kepler452 user so it can read/write the home dir + SecondSpot!.
  # Web UI: http://localhost:8384
  services.syncthing = {
    enable = true;
    user = "kepler452";
    group = "users";
    configDir = "/home/kepler452/.config/syncthing";
    dataDir = "/home/kepler452/.local/share/syncthing";
    # Pre-declare the music folder as a sync root (id "music").
    settings = {
      folders = {
        music = {
          path = "/home/kepler452/SecondSpot!/Music";
          id = "music";
          label = "Music";
        };
      };
    };
  };

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
