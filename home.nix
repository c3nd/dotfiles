{ config, pkgs, inputs,  ... }:
let
    dotfiles = "${config.home.homeDirectory}/dotfiles/config";
    create_symlink = path: config.lib.file.mkOutOfStoreSymlink path;
in

{
  
  home.username = "kepler452";
  home.homeDirectory = "/home/kepler452";
  home.packages = with pkgs; [
    zip
    xz
    unzip
    zed-editor
    calibre
    p7zip
    inputs.zen-browser.packages.${pkgs.system}.beta
    inputs.brave-previews.packages.${pkgs.system}.brave-nightly
  ];
  programs.caelestia= {
    enable = true;
    systemd = {
        enable = true;
        target = "graphical-session.target";
        environment = [];

    };
    cli = {
        enable = true;
        settings = {
            theme.enableGtk = true;
        };
    };
  };
  xdg.configFile."caelestia"={
   source = create_symlink"${dotfiles}/caelestia";
   force = true;
   recursive = true;
  };
  qt.platformTheme.name = "qt6ct";
  xdg.configFile."qt6ct"={
    source = create_symlink"${dotfiles}/qt6ct";
    recursive = true;
    force = true;
  };
  gtk.enable = true;
  gtk.font.name = "TX-02";
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
      plspush = "cd dotfiles/ && git commit -am 'autocommmit' && cd ../";
    };
  };
  programs.home-manager.enable = true;
}
