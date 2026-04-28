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
    inputs.brave-previews.packages.${pkgs.system}.brave-nightly
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
        services = {
          showLyrics = true;
          gpuType = "Quadro P2000";
          useTwelveHourClock= false;
          useFahrenheit= true;
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
        utilities = {
          enabled = true;
          toasts ={
            nowPlaying = true;
          };
          vpn = {
            enabled = true;
            provider = [
                {
                  name = "warp";
                  interface = "CloudflareWARP";
                  displayName = "Cloudflare Warp";
                  enabled = "true";

                  }
                ];
            };
        };
        bar={
          clock.showIcon = true;
          status = {
            showBattery = true;
            };
        };
        paths.wallpaperDir = "~/Pictures/Wallpapers";
        paths.lyricsDir = "~/Music/LyricsDir";
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
  xdg.configFile."qt6ct/qt6ct.conf".text = ''
  [Appearance]
color_scheme_path=/nix/store/ng7xicngxinpp35yi5fkx6lr16nv3gb9-qt6ct-0.11/share/qt6ct/colors/darker.conf
custom_palette=true
icon_theme=Papirus-Dark
standard_dialogs=default
style=Fusion

[Fonts]
fixed="TX-02,12,-1,5,400,0,0,0,0,0,0,0,0,0,0,1,Regular,0,0"
general="TX-02,12,-1,5,400,0,0,0,0,0,0,0,0,0,0,1,Regular,0,0"

[Interface]
activate_item_on_single_click=1
buttonbox_layout=0
cursor_flash_time=1000
dialog_buttons_have_icons=1
double_click_interval=400
gui_effects=@Invalid()
keyboard_scheme=2
menus_have_icons=true
show_shortcuts_in_context_menus=true
stylesheets=@Invalid()
toolbutton_style=4
underline_shortcut=1
wheel_scroll_lines=3

[SettingsWindow]
geometry=@ByteArray(\x1\xd9\xd0\xcb\0\x3\0\0\0\0\0\0\0\0\0\0\0\0\x1\xbc\0\0\x2\0\0\0\0\0\0\0\0\0\0\0\x1\xbc\0\0\x2\0\0\0\0\0\x2\0\0\0\a\x80\0\0\0\0\0\0\0\0\0\0\x1\xbc\0\0\x2\0)

[Troubleshooting]
force_raster_widgets=1
ignored_applications=@Invalid()
  '';
  xdg.configFile."qt6ct/qt6ct.conf".force = true;
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
