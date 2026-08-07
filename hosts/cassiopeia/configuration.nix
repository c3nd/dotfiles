# Cassiopeia — NixOS system configuration
# Host: HP ZBook Firefly 15.6 G8 (i7-1185G7, 32GB, T500)
# Desktop: Hyprland + caelestia-shell (configured in home.nix)
# Boot: systemd-boot (EFI), shared NVMe with Windows
{ config, lib, pkgs, inputs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../modules/qtengine.nix
    inputs.openwhispr.nixosModules.default
  ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.kernelModules = [ "kvm-intel" ];

  networking.hostName = "Cassiopeia";
  networking.networkmanager.enable = true;
  networking.firewall.enable = false;
  time.timeZone = "America/Phoenix";

  hardware.nvidia = {
    modesetting.enable = true;
    open = true;
    nvidiaSettings = true;
    powerManagement.enable = true;
    powerManagement.finegrained = false;
    prime = {
      sync.enable = true;
      intelBusId = "PCI:0:2:0";
      nvidiaBusId = "PCI:1:0:0";
    };
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

  programs.hyprland = {
    enable = true;
    package = inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.hyprland;
    portalPackage = inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.xdg-desktop-portal-hyprland;
  };

  xdg.portal = {
    enable = true;
    extraPortals = [
      inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.xdg-desktop-portal-hyprland
      pkgs.xdg-desktop-portal-gtk
    ];
  };

  services.displayManager.ly.enable = true;

  programs.qtengine.enable = true;

  services.pipewire = {
    enable = true;
    pulse.enable = true;
  };

  services.upower.enable = true;
  services.printing.enable = true;
  services.libinput.enable = true;

  services.fprintd.enable = true;
  security.pam.services.login.fprintAuth = true;
  security.pam.services.sudo.fprintAuth = true;
  security.pam.services.su.fprintAuth = true;
  security.pam.services.ly.fprintAuth = true;

  programs.openwhispr = {
    enable = true;
    users = [ "kepler9001" ];
  };

  environment.systemPackages = with pkgs; [
    nh
    logseq
    fprintd
    alsa-utils
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
    # browsers
    inputs.zen-browser.packages.${pkgs.system}.beta
    brave
    # lightweight tools
    xterm
    kitty
    pcmanfm
    inputs.caelestia-shell.packages.${pkgs.system}.with-cli
    # fonts
    nerd-fonts.jetbrains-mono
  ];

  users.users.kepler9001 = {
    isNormalUser = true;
    extraGroups = [ "wheel" "input" "video" ];
    packages = with pkgs; [ tree ];
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
