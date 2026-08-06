{ config, pkgs, inputs, ... }:

{
  home.username = "kepler9001";
  home.homeDirectory = "/home/kepler9001";
  home.stateVersion = "25.11";

  home.sessionVariables = {
    NH_OS_FLAKE = "~/.config/cassiopeia#Cassiopeia";
    NH_HOME_FLAKE = "~/.config/cassiopeia#kepler9001";
    NH_ELEVATION_STRATEGY = "auto";
    EDITOR = "vim";
    VISUAL = "vim";
    TERMINAL = "xterm";
  };

  home.packages = with pkgs; [
    zip xz unzip p7zip
    fastfetch
    feh xpdf
    pavucontrol
    cliphist
    logseq
    dunst
    conky
    fuzzel
    pcmanfm
  ];

  programs.git = {
    enable = true;
    settings = {
      user = { name = "c3nd"; email = "ascendancyluvsu@gmail.com"; };
      init.defaultBranch = "main";
    };
  };

  programs.fish = {
    enable = true;
    interactiveShellInit = "fastfetch";
  };

  programs.lapce.enable = true;

  qt.platformTheme.name = "qtengine";
  gtk.enable = true;
  gtk.font.name = "TX-02";
  fonts.fontconfig.enable = true;

  services.hyprpolkitagent.enable = false;

  xdg.configFile."wmaker" = {
    source = ../../config/wmaker;
    recursive = true;
    force = true;
  };

  xdg.configFile."fastfetch" = {
    source = ../../config/fastfetch;
    recursive = true;
    force = true;
  };

  xdg.configFile."dunst" = {
    source = ../../config/dunst;
    recursive = true;
    force = true;
  };

  xdg.configFile."conky" = {
    source = ../../conky;
    recursive = true;
    force = true;
  };

  programs.home-manager.enable = true;
}
