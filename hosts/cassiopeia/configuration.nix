# Cassiopeia — NixOS system configuration
# Host: Cassiopeia (x86_64-linux)
# Desktop: WindowMaker + slim (X11, NVIDIA Prime sync)
# Boot: systemd-boot (EFI), shared NVMe with Windows
{ config, lib, pkgs, inputs, ... }:

{
  imports = [
    ./hardware-configuration.nix
  ];

  networking.hostName = "cassiopeia";

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.kernelPackages = pkgs.linuxPackages_zen;
  boot.kernelModules = [ "kvm-intel" ];

  networking.networkmanager.enable = true;
  networking.firewall.enable = false;
  time.timeZone = "America/Phoenix";

  hardware.nvidia = {
    modesetting.enable = true;
    package = config.boot.kernelPackages.nvidiaPackages.open;
    open = true;
    nvidiaSettings = true;
    powerManagement.enable = false;
    prime.sync = {
      enable = true;
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

  services.displayManager.slim.enable = true;

  programs.windowmaker = {
    enable = true;
    settings = {
      WMUserIcons = false;
      WMDockApps = false;
    };
  };

  # X11 global hotkeys + speech-to-text stack
  # Handy is Wayland-only; on X11/WindowMaker we use xbindkeys + faster-whisper
  # + wtype to inject text. SUPER/Mod3 bindings mirror Hyprland's layout.
  services.xbindkeys.enable = true;

  environment.systemPackages = with pkgs; [
    nh
    faster-whisper
    xbindkeys
    wtype
    alsa-utils
    pavucontrol
    ffmpeg
  ];

  users.users.kepler452 = {
    isNormalUser = true;
    extraGroups = [ "wheel" "input" "video" ];
    packages = with pkgs; [ tree ];
  };

  security.sudo.extraConfig = ''
    kepler452 ALL=(root) NOPASSWD: /run/current-system/sw/bin/nixos-rebuild, /run/current-system/sw/bin/systemctl
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
  nixpkgs.config.allowUnfree = true;

  system.stateVersion = "25.11";
}
