# Cassiopeia — split Home Manager config
# School-focused, WindowMaker desktop, aerospace/scientific stack
{ config, pkgs, inputs, ... }:

{
  home.username = "kepler452";
  home.homeDirectory = "/home/kepler452";
  home.stateVersion = "25.11";

  home.sessionVariables = {
    NH_OS_FLAKE = "~/dotfiles#Cassiopeia";
    NH_HOME_FLAKE = "~/dotfiles#kepler452";
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

  # X11 dictation + WindowMaker keybindings
  # OpenWhispr provides global hotkeys/dictation; WMaker keys mirror Hyprland layout.
  xdg.configFile."wmaker" = {
    source = ../../config/wmaker;
    recursive = true;
    force = true;
  };
  xdg.configFile."fish" = {
    source = ../../config/fish;
    recursive = true;
    force = true;
  };

  programs.home-manager.enable = true;
}
