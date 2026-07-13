#!/usr/bin/env python3
"""meowbar — native GTK4 layer-shell overlay chat pill (Windows 7 Aero glass).

A real Hyprland layer-surface widget that mirrors the Cluely/Pluely floating
"Ask me anything..." bar, but talks to your local llm-stack LFM on :8080.
No webview, no $120 license — just GTK4 on Wayland with real Aero glass
(translucent window + Hyprland backdrop blur + glossy highlight).

Summon:  SUPER+Space   (bound in ~/.config/hypr/hyprland/keybinds.lua)
Type, Enter → sends to :8080, reply copied to clipboard.
Buttons:  mic (dictate) · new (clear) · attach (image→vision) · history · settings.

Env overrides:
  MEOWBAR_URL     default http://localhost:8080/v1
  MEOWBAR_MODEL   default LFM2.5-VL-1.6B
  MEOWBAR_KEY     default sk-local
"""
import os
import sys
import json
import base64
import threading
import subprocess

import gi
import urllib.request
from gi.repository import GLib, Gio

gi.require_version("Gtk", "4.0")
gi.require_version("Gtk4LayerShell", "1.0")
from gi.repository import Gtk, Gdk, Gtk4LayerShell

URL = os.environ.get("MEOWBAR_URL", "http://localhost:8080/v1")
MODEL = os.environ.get("MEOWBAR_MODEL", "LFM2.5-VL-1.6B")
KEY = os.environ.get("MEOWBAR_KEY", "sk-local")
WHISPER = os.environ.get("MEOWBAR_WHISPER", "http://localhost:8081/inference")
HIST = os.path.expanduser("~/.cache/meowbar/history.jsonl")
os.makedirs(os.path.dirname(HIST), exist_ok=True)

# ---- Windows 7 Aero glass -------------------------------------------------
# Translucent window + Hyprland backdrop blur + glossy top highlight + 1px
# light-blue glass border. The blur is done by the compositor (decoration:
# blur enabled), so we only need an alpha < 1 background.
CSS = """
.meowbar-pill {
  background: linear-gradient(to bottom,
              rgba(190,222,255,0.42) 0%,
              rgba(143,184,240,0.32) 48%,
              rgba(110,150,220,0.30) 100%);
  border-radius: 999px;
  padding: 5px 8px;
  border: 1px solid rgba(225,242,255,0.65);
  box-shadow: 0 0 0 1px rgba(80,120,190,0.30),
              0 8px 30px rgba(20,40,80,0.45),
              inset 0 1px 0 rgba(255,255,255,0.75);
}
/* glossy top sheen */
.meowbar-gloss {
  background: linear-gradient(to bottom,
              rgba(255,255,255,0.55), rgba(255,255,255,0.0) 60%);
  border-radius: 999px;
}
.entry { background: rgba(255,255,255,0.10); border-radius: 999px;
         border: 1px solid rgba(255,255,255,0.25);
         color: #0c1a2e; font-size: 15px; padding: 5px 14px; }
.entry placeholder { color: rgba(20,40,80,0.65); }
.round-btn { background: rgba(255,255,255,0.22); border-radius: 999px;
             min-width: 34px; min-height: 34px; padding: 0;
             border: 1px solid rgba(255,255,255,0.30); }
.round-btn:hover { background: rgba(255,255,255,0.42); }
.round-btn:active { background: rgba(150,190,250,0.55); }
.send { background: linear-gradient(to bottom,
              rgba(150,205,255,0.95), rgba(70,140,235,0.95));
        border-radius: 999px; min-width: 36px; min-height: 36px; padding: 0;
        color: #fff; border: 1px solid rgba(255,255,255,0.55);
        box-shadow: inset 0 1px 0 rgba(255,255,255,0.8); }
.send:hover { background: linear-gradient(to bottom,
              rgba(180,222,255,1.0), rgba(95,165,250,1.0)); }
.send:disabled { opacity: 0.55; }
.pop { background: rgba(225,240,255,0.92); border-radius: 14px;
       border: 1px solid rgba(255,255,255,0.7);
       box-shadow: 0 10px 40px rgba(20,40,80,0.5); padding: 10px; }
.pop-title { font-weight: 700; color: #0c1a2e; margin: 2px 6px 8px; }
.hist-row { padding: 7px 10px; border-radius: 8px; color: #0c1a2e; }
.hist-row:hover { background: rgba(120,170,250,0.35); }
.spin { color: #1a3a6a; }
"""

# ---- backend calls --------------------------------------------------------
def chat(prompt, image_path=None):
    content = [{"type": "text", "text": prompt}]
    if image_path:
        with open(image_path, "rb") as f:
            b64 = base64.b64encode(f.read()).decode()
        ext = image_path.rsplit(".", 1)[-1].lower()
        mime = "image/png" if ext in ("png",) else "image/jpeg" if ext in ("jpg", "jpeg") else "image/webp"
        content.append({"type": "image_url",
                        "image_url": {"url": f"data:{mime};base64,{b64}"}})
    body = json.dumps({
        "model": MODEL,
        "messages": [{"role": "user", "content": content}],
        "stream": False,
    }).encode()
    req = urllib.request.Request(
        URL + "/chat/completions", data=body,
        headers={"Content-Type": "application/json",
                 "Authorization": "Bearer " + KEY},
        method="POST",
    )
    try:
        with urllib.request.urlopen(req, timeout=90) as r:
            resp = json.loads(r.read().decode())
        return resp["choices"][0]["message"]["content"].strip()
    except Exception as e:  # noqa: BLE001
        return f"nya~ error: {e}"

def transcribe(wav_path):
    try:
        with open(wav_path, "rb") as f:
            data = f.read()
        req = urllib.request.Request(
            WHISPER, data=data,
            headers={"Content-Type": "application/octet-stream"},
            method="POST")
        with urllib.request.urlopen(req, timeout=60) as r:
            return r.read().decode().strip()
    except Exception as e:  # noqa: BLE001
        return ""

def record_audio(seconds=4):
    """Record from the default Pulse source via ffmpeg → 16k mono wav."""
    wav = "/tmp/meow_mic.wav"
    try:
        subprocess.run(
            ["ffmpeg", "-y", "-f", "pulse", "-i", "default",
             "-t", str(seconds), "-ar", "16000", "-ac", "1", wav],
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=seconds + 5)
        return wav if os.path.exists(wav) and os.path.getsize(wav) > 0 else None
    except Exception:  # noqa: BLE001
        return None

def log_history(prompt):
    try:
        with open(HIST, "a") as f:
            f.write(json.dumps({"q": prompt}) + "\n")
    except Exception:  # noqa: BLE001
        pass

def read_history(limit=12):
    try:
        rows = []
        with open(HIST) as f:
            for line in f:
                line = line.strip()
                if line:
                    try:
                        rows.append(json.loads(line)["q"])
                    except Exception:
                        pass
        return rows[-limit:][::-1]
    except FileNotFoundError:
        return []

# ---- the bar --------------------------------------------------------------
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

        # glossy overlay sits behind the controls
        pill = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=6)
        pill.add_css_class("meowbar-pill")
        pill.set_valign(Gtk.Align.CENTER)

        self.entry = Gtk.Entry()
        self.entry.set_placeholder_text("Ask me anything…")
        self.entry.set_hexpand(True)
        self.entry.set_width_chars(40)
        self.entry.connect("activate", self.on_send)
        ec = Gtk.EventControllerKey()
        ec.connect("key-pressed", self.on_key)
        self.entry.add_controller(ec)

        self.spinner = Gtk.Spinner()
        self.spinner.set_size_request(18, 18)
        self.spinner.add_css_class("spin")

        pill.append(self._icon_btn("🎤", "Dictate (mic)", self.on_mic))
        pill.append(self._icon_btn("✏️", "New chat", self.on_new))
        pill.append(self.entry)
        pill.append(self.spinner)
        pill.append(self._icon_btn("📎", "Attach image (vision)", self.on_attach))
        pill.append(self._icon_btn("🕘", "History", self.on_history))
        pill.append(self._icon_btn("⚙", "Settings", self.on_settings))
        self.send_btn = self._icon_btn("➤", "Send", self.on_send, send=True)
        pill.append(self.send_btn)

        # gloss overlay (pure decoration, ignores pointer)
        gloss = Gtk.Box()
        gloss.add_css_class("meowbar-gloss")
        gloss.set_can_target(False)
        gloss.set_hexpand(True)
        overlay = Gtk.Overlay()
        overlay.set_child(pill)
        overlay.add_overlay(gloss)
        gloss.set_valign(Gtk.Align.START)
        gloss.set_vexpand(False)
        gloss.set_size_request(-1, 16)

        self.win.set_child(overlay)
        self.win.present()
        self.entry.grab_focus()
        self._pop = None

    def _icon_btn(self, glyph, tooltip, cb=None, send=False):
        btn = Gtk.Button()
        btn.add_css_class("round-btn" if not send else "send")
        lbl = Gtk.Label()
        lbl.set_markup(f"<span size='15000'>{glyph}</span>")
        btn.set_child(lbl)
        btn.set_tooltip_text(tooltip)
        if cb:
            btn.connect("clicked", cb)
        return btn

    # ---- interactions -----------------------------------------------------
    def on_key(self, widget, keyval, keycode, state):
        if keyval == Gdk.KEY_Escape:
            self._hide()
            return True
        return False

    def on_send(self, *a):
        prompt = self.entry.get_text().strip()
        if not prompt:
            return
        self.entry.set_text("")
        self._set_busy(True)
        threading.Thread(target=self._work, args=(prompt, None),
                         daemon=True).start()

    def on_mic(self, *a):
        self.entry.set_placeholder_text("🎤 listening… speak now")
        self._set_busy(True)
        threading.Thread(target=self._dictate, daemon=True).start()

    def on_new(self, *a):
        self.entry.set_text("")
        self.entry.set_placeholder_text("Ask me anything…")
        self.entry.grab_focus()

    def on_attach(self, *a):
        dlg = Gtk.FileChooserDialog(
            title="Attach image", transient_for=self.win,
            action=Gtk.FileChooserAction.OPEN)
        dlg.add_button("Cancel", Gtk.ResponseType.CANCEL)
        dlg.add_button("Attach", Gtk.ResponseType.ACCEPT)
        f = Gtk.FileFilter(); f.set_name("Images")
        for m in ("image/png", "image/jpeg", "image/webp"):
            f.add_mime_type(m)
        dlg.add_filter(f)
        dlg.connect("response", self._attach_resp)
        dlg.show()

    def _attach_resp(self, dlg, resp):
        if resp == Gtk.ResponseType.ACCEPT:
            path = dlg.get_file().get_path()
            prompt = self.entry.get_text().strip() or "What's in this image?"
            self.entry.set_text("")
            self._set_busy(True)
            threading.Thread(target=self._work, args=(prompt, path),
                             daemon=True).start()
        dlg.destroy()

    def on_history(self, *a):
        self._close_pop()
        pop = Gtk.Popover()
        pop.set_parent(self.win)
        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2)
        box.add_css_class("pop")
        box.append(Gtk.Label(label="Recent asks"))
        box.children()[-1].add_css_class("pop-title")
        rows = read_history()
        if not rows:
            box.append(Gtk.Label(label="(none yet)"))
        for q in rows:
            row = Gtk.Button(label=(q[:48] + "…") if len(q) > 48 else q)
            row.add_css_class("hist-row")
            row.connect("clicked", lambda b, qq=q: self._use_hist(qq, pop))
            box.append(row)
        pop.set_child(box)
        pop.popup()
        self._pop = pop

    def _use_hist(self, q, pop):
        self.entry.set_text(q)
        self.entry.grab_focus()
        pop.popdown()

    def on_settings(self, *a):
        self._close_pop()
        pop = Gtk.Popover()
        pop.set_parent(self.win)
        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=6)
        box.add_css_class("pop")
        box.append(Gtk.Label(label="meowbar"))
        box.children()[-1].add_css_class("pop-title")
        for line in (f"model: {MODEL}", f"endpoint: {URL}",
                     "reply → clipboard", "ESC to hide"):
            box.append(Gtk.Label(label=line))
        clr = Gtk.Button(label="Clear history")
        clr.add_css_class("round-btn")
        clr.connect("clicked", lambda b: (open(HIST, "w").close(),
                                          self._close_pop()))
        box.append(clr)
        pop.set_child(box)
        pop.popup()
        self._pop = pop

    def _close_pop(self):
        if self._pop:
            try:
                self._pop.popdown()
            except Exception:  # noqa: BLE001
                pass
            self._pop = None

    # ---- workers ----------------------------------------------------------
    def _dictate(self):
        wav = record_audio(4)
        text = transcribe(wav) if wav else ""
        GLib.idle_add(self._dictate_done, text)

    def _dictate_done(self, text):
        self._set_busy(False)
        if text:
            self.entry.set_text(text)
            self.entry.grab_focus()
            self.entry.set_position(-1)
        else:
            self.entry.set_placeholder_text("🎤 STT offline — type instead")
        return False

    def _work(self, prompt, image_path):
        ans = chat(prompt, image_path)
        log_history(prompt)
        GLib.idle_add(self._done, ans)

    def _done(self, ans):
        self._set_busy(False)
        try:
            self.win.get_clipboard().set(ans)
            subprocess.run(["wl-copy"], input=ans.encode(),
                           stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        except Exception:  # noqa: BLE001
            pass
        self.entry.set_placeholder_text("copied to clipboard ✅")
        GLib.timeout_add(1300, self._hide)
        return False

    def _set_busy(self, busy):
        GLib.idle_add(self._busy_ui, busy)

    def _busy_ui(self, busy):
        self.send_btn.set_sensitive(not busy)
        if busy:
            self.spinner.start()
        else:
            self.spinner.stop()
        return False

    def _hide(self, *a):
        self._close_pop()
        self.win.set_visible(False)
        return False


if __name__ == "__main__":
    Bar()
