{ config, pkgs, lib, inputs, ... }:

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
    # media
    kopuz

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

    # terminal / system
    kitty
    xterm
    starship
    fish
    brave
    lapce
    fprintd
    qt6.qtwayland

    zip xz unzip p7zip
    fastfetch
    feh xpdf
    pavucontrol
    cliphist
    logseq
    fuzzel
    thunar
  ];

  # Install TX-02 fonts locally so every app sees them
  home.file.".local/share/fonts/tx02" = {
    source = ../../themes/space/fonts/tx02;
    recursive = true;
  };

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
      enable = false;
    };
    enableSystemMonitoring = true;
    enableVPN = true;
    enableDynamicTheming = true;
    enableAudioWavelength = true;
    enableCalendarEvents = true;
  };

  qt.platformTheme.name = "qtengine";
  gtk.enable = true;
  gtk.font.name = "TX-02";
  fonts.fontconfig.enable = true;
  fonts.fontconfig.defaultFonts = {
    sansSerif = [ "TX-02" ];
    serif = [ "TX-02" ];
    monospace = [ "TX-02" ];
  };

  xdg.configFile."fish" = {
    source = ../../config/fish;
    recursive = true;
    force = true;
  };

  xdg.configFile."starship" = {
    source = ../../config/starship;
    recursive = true;
    force = true;
  };

  programs.home-manager.enable = true;

  # Copy Hyprland configs into ~/.config/hypr as real writable files
  # so DMS Settings can edit hyprland.lua and write dms/*.lua
  home.activation.deployHyprConfig = lib.mkAfter ''
    set -euo pipefail
    for SRC in \
      "$HOME/.config/cassiopeia/home/kepler9001/config/hypr" \
      "$HOME/projects/cassiopeia-dendritic/config/hypr" \
      "$HOME/dotfiles/config/hypr"
    do
      if [ -d "$SRC" ]; then
        break
      fi
    done
    if [ ! -d "$SRC" ]; then
      echo "ERROR: cannot find Hyprland config source directory" >&2
      exit 1
    fi
    DEST="$HOME/.config/hypr"
    mkdir -p "$DEST" "$DEST/custom"
    cp -f "$SRC/hyprland.conf" "$DEST/hyprland.conf"
    cp -f "$SRC/hyprland.lua" "$DEST/hyprland.lua"
    cp -f "$SRC/custom/execs.conf" "$DEST/custom/execs.conf"
    cp -f "$SRC/custom/keybinds.conf" "$DEST/custom/keybinds.conf"
    chmod -R u+w "$DEST" 2>/dev/null || true
  '';
}
