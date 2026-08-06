# Cassiopeia — NixOS system configuration
# Host: HP ZBook Firefly 15.6 G8 (i7-1185G7, 32GB, T500)
# Desktop: WindowMaker + ly (X11, NVIDIA Prime sync)
# Boot: systemd-boot (EFI), shared NVMe with Windows
{ config, lib, pkgs, inputs, ... }:

{
  imports = [
    ./hardware-configuration.nix
  ];

  networking.hostName = "Cassiopeia";

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.kernelPackages = pkgs.linuxPackages_zen;
  boot.kernelModules = [ "kvm-intel" ];

  networking.networkmanager.enable = true;
  networking.firewall.enable = false;
  time.timeZone = "America/Phoenix";

  hardware.nvidia = {
    modesetting.enable = true;
    open = true;
    nvidiaSettings = true;
    prime = {
      sync.enable = true;
      intelBusId = "PCI:0:2:0";
      nvidiaBusId = "PCI:1:0:0";
    };
    powerManagement.enable = true;
    powerManagement.finegrained = false;
  };

  hardware.graphics.enable = true;
  hardware.bluetooth.enable = true;

  services.xserver = {
    enable = true;
    videoDrivers = [ "nvidia" "modesetting" ];
    autoRepeatDelay = 200;
    autoRepeatInterval = 35;
    layout = "us";
    xkbVariant = "";
  };

  services.displayManager.ly.enable = true;

  services.xserver.windowManager.windowmaker = {
    enable = true;
  };

  # X11 global hotkeys + OpenWhispr speech-to-text
  programs.openwhispr = {
    enable = true;
    users = [ "kepler9001" ];
  };

  # Fingerprint auth: fprintd D-Bus daemon + PAM rules
  services.fprintd.enable = true;
  security.pam.services.login.fprintAuth = true;
  security.pam.services.sudo.fprintAuth = true;
  security.pam.services.su.fprintAuth = true;
  security.pam.services.ly.fprintAuth = true;

  environment.systemPackages = with pkgs; [
    nh
    logseq
    fprintd
    alsa-utils
    pavucontrol
    ffmpeg
    # aerospace / school stack
    python314
    uv
    python313Packages.numpy
    python313Packages.scipy
    python313Packages.pandas
    python313Packages.matplotlib
    python313Packages.sympy
    python313Packages.astropy
    python313Packages.pythonocc-core
    octave
    gnuplot
    maxima
    gmsh
    calculix-ccx
    librecad
    openscad
    hunspell
    hunspellDicts.uk_UA
    krita
    xpdf
    fastfetch
    vim
    git
    gcc
    gnumake
    pkg-config
    nil
    jq
    lshw
    nnn
    btop
    eza
    starship
    gnome-keyring
    cliphist
    feh
    tree
    pavucontrol
    # browsers
    inputs.zen-browser.packages.${pkgs.system}.beta
    brave
    # lightweight tools
    pcmanfm
  ];

  users.users.kepler9001 = {
    isNormalUser = true;
    extraGroups = [ "wheel" "input" "video" ];
    packages = with pkgs; [ tree ];
    initialPassword = "testing";
  };

  security.sudo.extraConfig = ''
    kepler9001 ALL=(root) NOPASSWD: /run/current-system/sw/bin/nixos-rebuild, /run/current-system/sw/bin/systemctl
  '';

  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nix.settings.substituters = [
    "https://cache.nixos.org"
    "https://nix-community.cachix.org"
    "https://cuda-maintainers.cachix.org"
  ];
  nix.settings.trusted-public-keys = [
    "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
    "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Z9Iz52rXz24doJeTsuN8bjwc="
    "cuda-maintainers.cachix.org-1:0dq3bujKpuEPGUMXPcWe6Xsg52TCkEHwhT4SFgdHVR4="
  ];

  nixpkgs.config.allowUnfreePredicate = pkg:
    (builtins.elem (lib.getName pkg) [
      "nvidia-x11"
      "nvidia-settings"
      "brave"
      "nvidia-kernel-modules"
    ]);

  nixpkgs.config.permittedInsecurePackages = [
    "electron-39.8.10"
    "xpdf-4.06"
  ];

  system.stateVersion = "25.11";
}
