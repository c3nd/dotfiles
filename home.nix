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
            mono = "TX-02";
            sans = "TX-02";
          };
        };
        background = {
          enabled = true;
          desktopClock = {
            enabled = true;
          };
          visualiser = {
            enabled = true;
            autoHide = true;
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
      plspush = "cd dotfiles/ && git commit -am 'autocommmit' && git push -u --no-verify && cd ../";
    };
  };
  programs.home-manager.enable = true;
}
