#!/usr/bin/env python3
"""meowbar — native GTK4 layer-shell overlay chat bar (Pluely-style pill).

A real Hyprland layer-surface widget that mirrors the Cluely/Pluely floating
"Ask me anything..." bar, but talks to your local llm-stack LFM on :8080
(no webview, no $120 license, no CPU-melting WebKit — just GTK4 on Wayland).

Summon:  SUPER+Space   (bound in config/caelestia/hypr-user.lua)
Toggle visibility, type, Enter → sends to :8080, reply copied to clipboard.

Env overrides:
  MEOWBAR_URL     default http://localhost:8080/v1
  MEOWBAR_MODEL   default LFM2.5-VL-1.6B
  MEOWBAR_KEY     default sk-local
"""
import os
import sys
import json
import threading
import gi
import urllib.request
from gi.repository import GLib

gi.require_version("Gtk", "4.0")
gi.require_version("Gtk4LayerShell", "1.0")
from gi.repository import Gtk, Gdk, Gtk4LayerShell

URL = os.environ.get("MEOWBAR_URL", "http://localhost:8080/v1")
MODEL = os.environ.get("MEOWBAR_MODEL", "LFM2.5-VL-1.6B")
KEY = os.environ.get("MEOWBAR_KEY", "sk-local")

CSS = """
.pill {
  background: rgba(18,18,22,0.78);
  border-radius: 999px;
  padding: 5px 7px;
  border: 1.5px solid rgba(120,200,255,0.55);
  box-shadow: 0 6px 26px rgba(0,0,0,0.50);
}
.entry { background: transparent; border: none; color: #eaeaf0;
         font-size: 15px; padding: 4px 10px; }
.entry placeholder { color: rgba(170,200,230,0.65); }
.round-btn { background: rgba(255,255,255,0.08); border-radius: 999px;
             min-width: 34px; min-height: 34px; padding: 0; }
.round-btn:hover { background: rgba(255,255,255,0.18); }
.send { background: rgba(180,140,255,0.90); border-radius: 999px;
        min-width: 34px; min-height: 34px; padding: 0; color: #fff; }
.send:hover { background: rgba(180,140,255,1.0); }
"""


def chat(prompt):
    body = json.dumps({
        "model": MODEL,
        "messages": [{"role": "user", "content": prompt}],
        "stream": False,
    }).encode()
    req = urllib.request.Request(
        URL + "/chat/completions", data=body,
        headers={"Content-Type": "application/json",
                 "Authorization": "Bearer " + KEY},
        method="POST",
    )
    try:
        with urllib.request.urlopen(req, timeout=60) as r:
            resp = json.loads(r.read().decode())
        return resp["choices"][0]["message"]["content"].strip()
    except Exception as e:  # noqa: BLE001
        return f"nya~ error: {e}"


class Bar:
    def __init__(self):
        self.app = Gtk.Application(application_id="me.c3nd.meowbar")
        self.app.connect("activate", self.on_activate)
        self.app.run()

    def on_activate(self, app):
        self.win = Gtk.ApplicationWindow(application=app)
        self.win.set_decorated(False)
        Gtk4LayerShell.init_for_window(self.win)
        Gtk4LayerShell.set_layer(self.win, Gtk4LayerShell.Layer.TOP)
        Gtk4LayerShell.set_anchor(self.win, Gtk4LayerShell.Edge.TOP, True)
        Gtk4LayerShell.set_anchor(self.win, Gtk4LayerShell.Edge.RIGHT, True)
        Gtk4LayerShell.set_margin(self.win, Gtk4LayerShell.Edge.TOP, 14)
        Gtk4LayerShell.set_margin(self.win, Gtk4LayerShell.Edge.RIGHT, 14)
        Gtk4LayerShell.set_exclusive_zone(self.win, 0)
        try:
            Gtk4LayerShell.set_keyboard_mode(
                self.win, Gtk4LayerShell.KeyboardMode.ON_DEMAND)
        except Exception:  # noqa: BLE001
            pass

        css = Gtk.CssProvider()
        css.load_from_string(CSS)
        Gtk.StyleContext.add_provider_for_display(
            Gdk.Display.get_default(), css,
            Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION)

        pill = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=6)
        pill.add_css_class("pill")

        self.entry = Gtk.Entry()
        self.entry.set_placeholder_text("Ask me anything…")
        self.entry.set_hexpand(True)
        self.entry.set_width_chars(38)
        self.entry.connect("activate", self.on_send)
        # ESC hides the bar via an EventControllerKey (GTK4 has no key-press-event signal).
        ec = Gtk.EventControllerKey()
        ec.connect("key-pressed", self.on_key)
        self.entry.add_controller(ec)

        pill.append(self._icon_btn("🎤", "voice (nyi)"))
        pill.append(self._icon_btn("🖊", "new chat"))
        pill.append(self.entry)
        self.send_btn = self._icon_btn("➤", "send", send=True)
        pill.append(self.send_btn)
        pill.append(self._icon_btn("📎", "attach (nyi)"))
        pill.append(self._icon_btn("🕘", "history (nyi)"))
        pill.append(self._icon_btn("⚙", "settings (nyi)"))

        self.win.set_child(pill)
        self.win.present()
        self.entry.grab_focus()

    def _icon_btn(self, glyph, tooltip, send=False):
        btn = Gtk.Button()
        btn.add_css_class("round-btn" if not send else "send")
        lbl = Gtk.Label()
        lbl.set_markup(f"<span size='15'>{glyph}</span>")
        btn.set_child(lbl)
        btn.set_tooltip_text(tooltip)
        if send:
            btn.connect("clicked", self.on_send)
        return btn

    def on_key(self, widget, keyval, keycode, state):
        if keyval == Gdk.KEY_Escape:
            self.win.set_visible(False)
            return True
        return False

    def on_send(self, *a):
        prompt = self.entry.get_text().strip()
        if not prompt:
            return
        self.entry.set_text("")
        self.entry.set_placeholder_text("thinking… 🐱")
        self.app.hold()
        threading.Thread(target=self._work, args=(prompt,),
                         daemon=True).start()

    def _work(self, prompt):
        ans = chat(prompt)
        GLib.idle_add(self._done, ans)

    def _done(self, ans):
        self.entry.set_placeholder_text("Ask me anything…")
        try:
            self.win.get_clipboard().set(ans)
        except Exception:  # noqa: BLE001
            pass
        self.app.release()
        # brief confirmation flash in the placeholder, then hide
        self.entry.set_placeholder_text("copied to clipboard ✅")
        GLib.timeout_add(1200, self._hide)

    def _hide(self, *a):
        self.win.set_visible(False)
        return False


if __name__ == "__main__":
    Bar()
