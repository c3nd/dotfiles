{ config, pkgs, inputs,  ... }:

{
  
  home.username = "kepler452";
  home.homeDirectory = "/home/kepler452";
  home.packages = with pkgs; [
    zip
    xz
    unzip
    p7zip
    inputs.zen-browser.packages.${pkgs.system}.beta
  ];
  programs.caelestia= {
    enable = true;
    systemd = {
        enable = true;
        target = "graphical-session.target";
        environment = [];

    };
    settings = {
        bar.status = {
            showBattery = true;
        };
        paths.wallpaperDir = "~/Pictures/Wallpapers";
    };
    cli = {
        enable = true;
        settings = {
            theme.enableGtk = false;
        };
    };
  };
  services.hyprpolkitagent.enable = true;
  programs.git= {
    enable = true;
    userName = "c3nd";
    userEmail = "ascendancyluvsu@gmail.com";
    extraConfig = {
        init.defaultBranch = "main";
    };
  };
  home.stateVersion = "25.11";
  programs.fish= {
    enable = true;
    shellAliases = {
      btw = "echo i use nixos, btw";
    };
  };
   home.file = {
    ".local/share/fonts/" = {
      source = config/fonts;
      recursive = true;
    };
  };
  programs.home-manager.enable = true;
}
