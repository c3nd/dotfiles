{ pkgs, lib, config, ... }:

/*
  meowbar — native GTK4 layer-shell overlay chat bar (Pluely-style pill).

  A real Hyprland layer-surface widget that mirrors the Cluely/Pluely floating
  "Ask me anything..." bar, but talks to the local llm-stack LFM on :8080.
  No webview, no $120 license, no CPU-melting WebKit — just GTK4 on Wayland.

  Summon with SUPER+Space (bound in config/caelestia/hypr-user.lua).

  Enabled via:  programs.meowbar.enable = true;
*/
{
  options.programs.meowbar = {
    enable = lib.mkEnableOption "meowbar overlay chat bar";
    url = lib.mkOption {
      type = lib.types.str;
      default = "http://localhost:8080/v1";
      description = "OpenAI-compatible chat endpoint (llm-stack LFM).";
    };
    model = lib.mkOption {
      type = lib.types.str;
      default = "LFM2.5-VL-1.6B";
      description = "Model name to send in the chat completion request.";
    };
    key = lib.mkOption {
      type = lib.types.str;
      default = "sk-local";
      description = "API key sent in the Authorization header.";
    };
  };

  config = lib.mkIf config.programs.meowbar.enable (
    let
      # Every GTK/GObject typelib the script touches (cairo comes from
      # gobject-introspection, PangoCairo from pango, HarfBuzz from harfbuzz…).
      # No libadwaita → avoids the duplicate GIcon/GdkPixbuf type-registration
      # crash when LD_PRELOAD is used for the layer-shell linking quirk.
      typelibPath = pkgs.lib.makeSearchPath "lib/girepository-1.0" [
        pkgs.gtk4.out pkgs.gtk4-layer-shell.out pkgs.graphene.out pkgs.glib.out
        pkgs.gobject-introspection.out pkgs.pango.out pkgs.gdk-pixbuf.out pkgs.harfbuzz.out
      ];
      layerSo = "${pkgs.gtk4-layer-shell}/lib/libgtk4-layer-shell.so";
      pyEnv = pkgs.python3.withPackages (p: [ p.pygobject3 p.pycairo p.requests ]);
    in
    {
      xdg.configFile."meowbar/meowbar.py" = {
        source = ../config/meowbar/meowbar.py;
        executable = true;
      };

      home.packages = [
        # runtime deps the bar actually shells out to:
        pkgs.ffmpeg          # audio capture / conversion (user-requested)
        pkgs.pipewire        # pw-record (mic capture)
        pkgs.wl-clipboard    # wl-copy (persistent clipboard)
        (pkgs.writeShellScriptBin "meowbar" ''
          export MEOWBAR_URL="${config.programs.meowbar.url}"
          export MEOWBAR_MODEL="${config.programs.meowbar.model}"
          export MEOWBAR_KEY="${config.programs.meowbar.key}"
          export GDK_BACKEND=wayland
          export GI_TYPELIB_PATH="${typelibPath}:$GI_TYPELIB_PATH"
          export LD_PRELOAD="${layerSo} $LD_PRELOAD"
          exec ${pyEnv}/bin/python3 "$HOME/.config/meowbar/meowbar.py"
        '')
      ];
    }
  );
}
