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
    TERMINAL = "kitty";
  };

  home.packages = with pkgs; [
    # aerospace/school stack
    freecad
    gmsh
    calculix-ccx
    librecad
    openscad
    octaveFull
    gnuplot
    maxima
    python3
    python3Packages.numpy
    python3Packages.scipy
    python3Packages.matplotlib
    python3Packages.pandas
    python3Packages.tkinter
    texliveFull

    zip xz unzip p7zip
    fastfetch
    starship
    feh xpdf
    pavucontrol
    cliphist
    logseq
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
    interactiveShellInit = ''
      fastfetch
      starship init fish | source
    '';
  };

  programs.lapce.enable = true;

  programs.dank-material-shell = {
    enable = true;
    systemd = {
      enable = true;
      # target = "graphical-session.target";  # wrong for user services; let DMS default
    };
  };

  qt.platformTheme.name = "qtengine";
  gtk.enable = true;
  gtk.font.name = "TX-02";
  fonts.fontconfig.enable = true;

  xdg.configFile."fish" = {
    source = ../../config/fish;
    recursive = true;
    force = true;
  };

  xdg.configFile."hypr" = {
    source = ../../config/hypr;
    recursive = true;
    force = true;
  };

  xdg.configFile."starship" = {
    source = ../../config/starship;
    recursive = true;
    force = true;
  };

  programs.home-manager.enable = true;
}
