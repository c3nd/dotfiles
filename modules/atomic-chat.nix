{ config, lib, pkgs, inputs, ... }:

with lib;

let
  cfg = config.programs.atomic-chat;

  atomic-chat-pkg = pkgs.appimageTools.wrapType2 {
    pname = "atomic-chat";
    version = cfg.version;

    src = pkgs.fetchurl {
      url = "https://github.com/AtomicBot-ai/Atomic-Chat/releases/download/v${cfg.version}/Atomic.Chat_${cfg.version}_amd64.AppImage";
      # Run with this hash once (or `nix-prefetch-url <url>`) to get the
      # real sha256, then paste it in here.
      hash = "sha256-B/gci7q7xWWsl7T6vwUza3pxDLO60GQenH91ZFp4BHI=";
    };

    # Libraries the Tauri/WebKitGTK app dlopen's at runtime. Without these
    # the AppImage extracts fine but the binary segfaults/blank-screens on
    # launch - this is almost certainly what was biting you before.
    extraPkgs = pkgs: with pkgs; [
      gtk3
      glib
      cairo
      pango
      atk
      gdk-pixbuf
      webkitgtk_4_1
      openssl
      libayatana-appindicator
      libsoup_3
      alsa-lib
      libpulseaudio
      libxkbcommon
      vulkan-loader
      wayland
      nss
      nspr
      at-spi2-core
      cups
      dbus
      expat
      libdrm
      mesa
    ];

    extraInstallCommands = ''
      # wrapType2 already copies any usr/share/{applications,icons} found
      # inside the AppImage, but the upstream .desktop Exec= line points at
      # the AppImage's internal name - repoint it at our wrapped binary.
      if [ -f "$out/share/applications/atomic-chat.desktop" ]; then
        substituteInPlace "$out/share/applications/atomic-chat.desktop" \
          --replace "Exec=AppRun" "Exec=$out/bin/atomic-chat"
      fi
    '';

    meta = with lib; {
      description = "Local AI chat app and inference engine (AppImage release)";
      homepage = "https://github.com/AtomicBot-ai/Atomic-Chat";
      license = licenses.agpl3Only;
      platforms = [ "x86_64-linux" ];
      mainProgram = "atomic-chat";
    };
  };

in
{
  options.programs.atomic-chat = {
    enable = mkEnableOption "Atomic Chat (AppImage)";

    version = mkOption {
      type = types.str;
      default = "1.1.137";
      description = "Atomic Chat release tag (without the leading 'v') to fetch.";
    };

    hash = mkOption {
      type = types.str;
      default = lib.fakeHash;
      description = ''
        sha256 hash of the AppImage for the chosen version. Leave as
        lib.fakeHash to get the real one printed by the build error on
        first switch, then set it here.
      '';
    };

    package = mkOption {
      type = types.package;
      default = atomic-chat-pkg;
      description = "The Atomic Chat package to use.";
    };
  };

  config = mkIf cfg.enable {
    home.packages = [ cfg.package ];
  };
}
