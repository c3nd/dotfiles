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
        appearance ={
          font.family = {
            clock = "TX-02 Regular";
            mono = "TX-02 Regular";
            sans = "TX-02 Regular";
          };
        };
        background = {
          desktopClock = {
            enabled = true;
          };
          visualizer = {
            enabled = true;
            autohide = true;
          };
        };
        bar={
          clock.showIcon = true;
          status = {
            showBattery = true;
            };
        };
        paths.wallpaperDir = "~/Pictures/Wallpapers";
        border.rounding = "1.7";
    };

    cli = {
        enable = true;
        settings = {
            theme.enableGtk = false;
        };
    };
  };
  qt.platformTheme.name = "qt6ct";
  fonts.fontconfig.enable = true;
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
  programs.home-manager.enable = true;
}
