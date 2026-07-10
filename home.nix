# Milkdromeda — Home Manager configuration for user `kepler452`
#
# Manages the *user* environment: user packages, shells, dotfiles (symlinked
# from this repo's `config/` dir), and the caelestia-shell desktop session.
#
# Dotfiles under `config/` are symlinked into ~/.config via mkOutOfStoreSymlink,
# so edits here apply live without a full rebuild of the store.
{ config, pkgs, inputs, ... }:

let
  # Root of this repo's `config/` tree (relative to $HOME).
  dotfiles = "${config.home.homeDirectory}/dotfiles/config";

  # Helper: symlink a whole config dir into ~/.config.
  linkConfig = name: config.lib.file.mkOutOfStoreSymlink "${dotfiles}/${name}";
in
{
  ############################################################################
  # Imports — local Home Manager modules
  ############################################################################
  imports = [
    # AppImage-wrapped apps (enable via programs.<name>.enable below).
    ./modules/atomic-chat.nix
    ./modules/zcode.nix

    # Local-first meeting summarizer (built from ~/Projects/meownotes source).
    ./modules/meownotes.nix
  ];

  ############################################################################
  # Identity
  ############################################################################
  home.username = "kepler452";
  home.homeDirectory = "/home/kepler452";

  ############################################################################
  # User packages
  ############################################################################
  home.packages = with pkgs; [
    # Archiving
    zip
    xz
    unzip
    p7zip

    # Editors
    zed-editor
    calibre

    # Prebuilt browsers (from flake inputs)
    inputs.zen-browser.packages.${pkgs.system}.beta
    inputs.brave-previews.packages.${pkgs.system}.brave-nightly
  ];

  ############################################################################
  # caelestia-shell desktop session
  ############################################################################
  programs.caelestia = {
    enable = true;
    systemd = {
      enable = true;
      target = "graphical-session.target";
      environment = [ ];
    };
    cli = {
      enable = true;
    };
  };

  # Symlink caelestia config dirs into ~/.config.
  xdg.configFile."caelestia" = {
    source = linkConfig "caelestia";
    force = true;
    recursive = true;
  };

  ############################################################################
  # Qt / GTK theming
  ############################################################################
  qt.platformTheme.name = "qtengine";

  xdg.configFile."qt6ct" = {
    source = linkConfig "qt6ct";
    recursive = true;
    force = true;
  };
  xdg.configFile."qtengine" = {
    source = linkConfig "qtengine";
    recursive = true;
    force = true;
  };

  gtk.enable = true;
  gtk.font.name = "TX-02";
  fonts.fontconfig.enable = true;

  ############################################################################
  # Zed editor + config
  ############################################################################
  programs.zed-editor.enable = true;
  xdg.configFile."zed" = {
    source = linkConfig "zed";
    recursive = true;
    force = true;
  };

  ############################################################################
  # Polkit agent (needed for GUI privilege prompts under Hyprland)
  ############################################################################
  services.hyprpolkitagent.enable = true;

  ############################################################################
  # Git
  ############################################################################
  programs.git = {
    enable = true;
    settings = {
      user = {
        name = "c3nd";
        email = "ascendancyluvsu@gmail.com";
      };
      init.defaultBranch = "main";
    };
  };

  ############################################################################
  # Fish shell
  ############################################################################
  programs.fish = {
    enable = true;
    shellAliases = {
      btw = "echo i use nixos, btw";
      # Commit everything in the dotfiles repo and push to origin/main.
      plspush = "cd ~/dotfiles && git add -A && git commit -m 'autocommit' && git push && cd ~";
    };
  };

  ############################################################################
  # Optional AppImage apps (wired, disabled by default)
  #
  # These modules are ready to use. To enable, set `enable = true` and, after
  # the first (expected) hash error, paste the real sha256 shown into the
  # module's `hash` option (or here).
  ############################################################################
  # programs.atomic-chat.enable = true;
  # programs.zcode.enable = true;

  ############################################################################
  # meownotes — local-first meeting summarizer
  #
  # Built from ~/Projects/meownotes. Enable to put `meownotes` on PATH and
  # create the notes output dir.
  ############################################################################
  programs.meownotes.enable = true;
  programs.meownotes.outputDir = "~/meownotes-notes";

  ############################################################################
  # State version
  ############################################################################
  home.stateVersion = "25.11";

  ############################################################################
  # Housekeeping
  ############################################################################
  programs.home-manager.enable = true;
}
