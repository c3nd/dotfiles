#!/usr/bin/env python3
"""meowbar — native GTK4 layer-shell overlay chat pill (Windows 7 Aero glass).

A real Hyprland layer-surface widget that mirrors the Cluely/Pluely floating
"Ask me anything..." bar, but talks to your local llm-stack LFM on :8080.
No webview, no license — just GTK4 on Wayland with real Aero glass.

Summon:  SUPER+Space   (bound in ~/.config/hypr/hyprland/keybinds.lua)
Type, Enter -> sends to :8080, reply shown in a dropdown (no clipboard).
Buttons:  mic (live-dictate) . new . attach (image->vision) . screenshot .
          record (screen) . history . clock . settings . send.

Env overrides:
  MEOWBAR_URL       default http://localhost:8080/v1
  MEOWBAR_MODEL     default LFM2.5-VL-1.6B
  MEOWBAR_KEY       default sk-local
  MEOWBAR_WHISPER   default http://localhost:8081/inference
"""
import os
import sys
import json
import base64
import time
import threading
import subprocess
import shutil

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

CONFIG = os.path.expanduser("~/.config/meowbar/config.json")
SETTINGS_DEFAULT = {
    "model": MODEL,
    "endpoint": URL,
    "mic_source": "",   # empty => auto-detect first Audio/Source
    "record_seconds": 4,
}


def load_settings():
    s = dict(SETTINGS_DEFAULT)
    try:
        with open(CONFIG) as f:
            s.update(json.load(f))
    except Exception:
        pass
    return s


def save_settings(s):
    try:
        with open(CONFIG, "w") as f:
            json.dump(s, f, indent=2)
    except Exception:
        pass


def default_mic_source():
    """Pick the first PipeWire audio source (robust on NixOS/pipewire)."""
    try:
        out = subprocess.run(
            ["pw-cli", "list-objects", "Node"],
            capture_output=True, text=True, timeout=8).stdout
        cur = None
        for line in out.splitlines():
            line = line.strip()
            if line.startswith("id ") and "Node/3" in line:
                cur = {}
            elif cur is not None:
                if "node.name" in line:
                    cur["name"] = line.split("=", 1)[-1].strip().strip('"')
                if "media.class" in line:
                    cur["cls"] = line.split("=", 1)[-1].strip().strip('"')
                    if cur.get("cls") == "Audio/Source" and cur.get("name"):
                        return cur["name"]
    except Exception:
        pass
    return "alsa_input.pci-0000_00_1f.3.analog-stereo"


# ---- Windows 7 Aero glass -------------------------------------------------
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
.pop { background: rgba(225,240,255,0.95); border-radius: 14px;
       border: 1px solid rgba(255,255,255,0.7);
       box-shadow: 0 10px 40px rgba(20,40,80,0.5); padding: 10px; min-width: 240px; }
.pop-title { font-weight: 700; color: #0c1a2e; margin: 2px 6px 8px; }
.hist-row { padding: 7px 10px; border-radius: 8px; color: #0c1a2e;
            text-align: left; }
.hist-row:hover { background: rgba(120,170,250,0.35); }
.spin { color: #1a3a6a; }
.rec-on { background: rgba(220,40,40,0.55); box-shadow: 0 0 12px rgba(255,40,40,0.7); }
.rec-on:hover { background: rgba(240,60,60,0.7); }
.pop-label { color: #0c1a2e; padding: 2px 6px; }
.entry2 { background: rgba(255,255,255,0.85); border-radius: 8px;
          border: 1px solid rgba(80,120,190,0.4); color: #0c1a2e;
          padding: 6px 10px; }
"""

# ---- backend calls --------------------------------------------------------
def chat(prompt, image_path=None):
    content = [{"type": "text", "text": prompt}]
    if image_path:
        try:
            with open(image_path, "rb") as f:
                b64 = base64.b64encode(f.read()).decode()
            ext = image_path.rsplit(".", 1)[-1].lower()
            mime = ("image/png" if ext == "png" else
                    "image/jpeg" if ext in ("jpg", "jpeg") else "image/webp")
            content.append({"type": "image_url",
                            "image_url": {"url": f"data:{mime};base64,{b64}"}})
        except Exception:
            pass
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
        with urllib.request.urlopen(req, timeout=120) as r:
            resp = json.loads(r.read().decode())
        return resp["choices"][0]["message"]["content"].strip()
    except Exception as e:  # noqa: BLE001
        return f"nya~ error: {e}"


def transcribe(wav_path):
    """whisper.cpp /inference wants multipart form 'file=' (proven working)."""
    if not wav_path or not os.path.exists(wav_path):
        return ""
    boundary = "----meowbar" + os.urandom(16).hex()
    with open(wav_path, "rb") as f:
        data = f.read()
    head = (f'--{boundary}\r\n'
            f'Content-Disposition: form-data; name="file"; '
            f'filename="voice.wav"\r\n'
            f'Content-Type: audio/wav\r\n\r\n').encode()
    payload = head + data + f'\r\n--{boundary}--\r\n'.encode()
    req = urllib.request.Request(
        WHISPER, data=payload,
        headers={"Content-Type": f"multipart/form-data; boundary={boundary}"},
        method="POST")
    try:
        with urllib.request.urlopen(req, timeout=60) as r:
            return r.read().decode().strip()
    except Exception:  # noqa: BLE001
        return ""


def record_audio(seconds=4, source=None):
    """Record mic -> 16k mono wav. Use ffmpeg (pulse) — pw-record produces a
    wav header whisper.cpp rejects. Returns wav path or None."""
    wav = "/tmp/meow_mic.wav"
    src = source or default_mic_source()
    try:
        # ffmpeg -f pulse -i <node> -t N writes a clean RIFF wav whisper likes
        subprocess.run(
            ["ffmpeg", "-y", "-f", "pulse", "-i", src, "-t", str(seconds),
             "-ar", "16000", "-ac", "1", wav],
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
            timeout=seconds + 8, check=True)
        return wav if os.path.exists(wav) and os.path.getsize(wav) > 44 else None
    except Exception:  # noqa: BLE001
        return None


def record_and_stream(seconds, source, on_partial):
    """Record via ffmpeg while streaming interim transcripts into the box.
    Chunks the live wav every ~1.5s and sends each to whisper; the last
    partial is returned (the full final transcript)."""
    wav = "/tmp/meow_mic.wav"
    src = source or default_mic_source()
    # start ffmpeg writing continuously
    proc = subprocess.Popen(
        ["ffmpeg", "-y", "-f", "pulse", "-i", src, "-ar", "16000", "-ac", "1", wav],
        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    last = ""
    elapsed = 0.0
    chunk = 1.5
    try:
        while proc.poll() is None and elapsed < seconds + 1:
            time.sleep(chunk)
            elapsed += chunk
            if os.path.exists(wav) and os.path.getsize(wav) > 44:
                txt = transcribe(wav)
                txt = txt.strip()
                if txt and txt != last:
                    last = txt
                    on_partial(txt)
    finally:
        proc.terminate()
        try:
            proc.wait(timeout=4)
        except Exception:  # noqa: BLE001
            proc.kill()
    # final clean pass
    if os.path.exists(wav) and os.path.getsize(wav) > 44:
        final = transcribe(wav).strip()
        if final:
            last = final
            on_partial(final)
    return last


def pick_file(title="Select a file", mime=None):
    """Open a file picker without xdg-desktop-portal (which has no backend
    here, so Gtk.FileDialog fails). Uses zenity if present, else a tiny
    GTK FileDialog fallback. Returns a path or None."""
    if shutil.which("zenity"):
        cmd = ["zenity", "--file-selection", "--title", title]
        if mime:
            cmd += ["--file-filter", mime]
        try:
            out = subprocess.run(cmd, capture_output=True, text=True,
                                  timeout=30).stdout.strip()
            return out or None
        except Exception:  # noqa: BLE001
            return None
    # fallback: GTK FileDialog (only works if a portal backend exists)
    return None


def take_screenshot():
    """Region screenshot via grim + slurp -> png. Returns path or None."""
    png = os.path.expanduser("~/Pictures/meow_shot_%d.png"
                             % int(time.time()))
    os.makedirs(os.path.dirname(png), exist_ok=True)
    try:
        # slurp prints a geometry like "x,y,w,h"; feed to grim -g
        geo = subprocess.run(["slurp"], capture_output=True, text=True,
                              timeout=30).stdout.strip()
        if not geo:
            return None
        subprocess.run(["grim", "-g", geo, png],
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                       timeout=30, check=True)
        return png if os.path.exists(png) else None
    except Exception:  # noqa: BLE001
        return None


def start_screen_recorder(output_path, monitor="portal", fps=60):
    """Start gpu-screen-recorder. Uses the desktop-portal backend (``-w portal``)
    so it works WITHOUT the cap_sys_admin cap that KMS capture needs. The user
    approves the share in the portal dialog. Returns the Popen, or None if the
    binary is missing. Recording continues until stop_screen_recorder()."""
    if not shutil.which("gpu-screen-recorder"):
        return None
    os.makedirs(os.path.dirname(output_path), exist_ok=True)
    try:
        return subprocess.Popen(
            ["gpu-screen-recorder", "-w", monitor, "-f", str(fps),
             "-restore-portal-session", "yes", "-o", output_path],
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    except Exception:  # noqa: BLE001
        return None


def stop_screen_recorder(proc):
    """Stop a running recorder. Returns True if it was running."""
    if proc is None:
        return False
    try:
        proc.terminate()
        proc.wait(timeout=5)
    except Exception:  # noqa: BLE001
        try:
            proc.kill()
        except Exception:  # noqa: BLE001
            pass
    return True


def default_monitor():
    """Best-guess monitor name for gpu-screen-recorder (Hyprland)."""
    try:
        out = subprocess.run(["hyprctl", "monitors", "-j"],
                             capture_output=True, text=True, timeout=10).stdout
        import json as _json
        data = _json.loads(out)
        if isinstance(data, list) and data:
            return data[0].get("name", "eDP-1")
    except Exception:  # noqa: BLE001
        pass
    return "eDP-1"


def log_history(prompt, answer=""):
    try:
        with open(HIST, "a") as f:
            f.write(json.dumps({"q": prompt, "a": answer}) + "\n")
    except Exception:
        pass


def read_history(limit=12):
    try:
        rows = []
        with open(HIST) as f:
            for line in f:
                line = line.strip()
                if line:
                    try:
                        rows.append(json.loads(line))
                    except Exception:
                        pass
        return rows[-limit:][::-1]
    except FileNotFoundError:
        return []


def copy_text(text):
    """Copy to the compositor-persistent clipboard (wl-copy) so it survives
    the bar hiding. Falls back to the GTK surface clipboard."""
    ok = False
    try:
        subprocess.run(["wl-copy"], input=text.encode(),
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                       timeout=5)
        ok = True
    except Exception:  # noqa: BLE001
        ok = False
    try:
        Gdk.Display.get_default().get_clipboard().set(text)
    except Exception:  # noqa: BLE001
        pass
    return ok


# ---- the bar --------------------------------------------------------------
class Bar:
    def __init__(self):
        self.settings = load_settings()
        if not self.settings.get("mic_source"):
            self.settings["mic_source"] = default_mic_source()
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

        self.rec_proc = None  # screen-recorder Popen when active
        self.mic_btn = self._icon_btn("🎤", "Dictate (live transcription)", self.on_mic)
        self.new_btn = self._icon_btn("✏️", "New chat", self.on_new)
        self.attach_btn = self._icon_btn("📎", "Attach image (vision)",
                                         self.on_attach)
        self.shot_btn = self._icon_btn("📷", "Screenshot → vision",
                                       self.on_screenshot)
        self.rec_btn = self._icon_btn("🎬", "Record screen", self.on_record)
        self.hist_btn = self._icon_btn("📜", "History", self.on_history)
        self.clock_btn = self._icon_btn("🕘", "Clock", self.on_clock)
        self.set_btn = self._icon_btn("⚙", "Settings", self.on_settings)
        self.send_btn = self._icon_btn("➤", "Send", self.on_send, send=True)

        pill.append(self.mic_btn)
        pill.append(self.new_btn)
        pill.append(self.entry)
        pill.append(self.spinner)
        pill.append(self.attach_btn)
        pill.append(self.shot_btn)
        pill.append(self.rec_btn)
        pill.append(self.hist_btn)
        pill.append(self.clock_btn)
        pill.append(self.set_btn)
        pill.append(self.send_btn)

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
        self._clock_source = None

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
        if state & Gdk.ModifierType.CONTROL_MASK:
            if keyval in (Gdk.KEY_l, Gdk.KEY_L):
                self.on_new()
                return True
        return False

    def on_send(self, *a):
        self._close_pop()
        prompt = self.entry.get_text().strip()
        if not prompt:
            return
        self.entry.set_text("")
        self._set_busy(True)
        threading.Thread(target=self._work, args=(prompt, None),
                         daemon=True).start()

    def on_mic(self, *a):
        self._close_pop()
        self.entry.set_placeholder_text("🎤 listening… speak now")
        self._set_busy(True)
        threading.Thread(target=self._dictate, daemon=True).start()

    def on_new(self, *a):
        self._close_pop()
        self.entry.set_text("")
        self.entry.set_placeholder_text("Ask me anything…")
        self.entry.grab_focus()

    def on_attach(self, *a):
        self._close_pop()
        path = pick_file("Attach image",
                         mime="Image files (*.png;*.jpg;*.jpeg;*.webp)")
        if not path:
            self.entry.set_placeholder_text("📎 attach cancelled")
            return
        prompt = self.entry.get_text().strip() or "What's in this image?"
        self.entry.set_text("")
        self._set_busy(True)
        threading.Thread(target=self._work, args=(prompt, path),
                         daemon=True).start()

    def on_screenshot(self, *a):
        self._close_pop()
        self.entry.set_placeholder_text("📷 drag to select a region…")
        self._set_busy(True)
        threading.Thread(target=self._shoot, daemon=True).start()

    def on_record(self, *a):
        self._close_pop()
        if self.rec_proc is not None:
            # toggle -> stop
            stop_screen_recorder(self.rec_proc)
            self.rec_proc = None
            self.rec_btn.remove_css_class("rec-on")
            self.entry.set_placeholder_text("⏹ screen recording saved")
        else:
            out = os.path.expanduser(
                "~/Videos/meow_rec_%d.mp4" % int(time.time()))
            self.entry.set_text("")
            self.entry.set_placeholder_text("🎬 recording… tap 🎬 again to stop")
            self.rec_btn.add_css_class("rec-on")
            threading.Thread(target=self._record_toggle, args=(out,),
                             daemon=True).start()

    def _record_toggle(self, out):
        # portal backend => no cap_sys_admin needed; user approves share dialog
        proc = start_screen_recorder(out, "portal",
                                     int(self.settings.get("fps", 60)))
        if proc is None:
            GLib.idle_add(lambda: (self.rec_btn.remove_css_class("rec-on"),
                                   self.entry.set_placeholder_text(
                                       "🎬 recorder missing"), False))
            return
        self.rec_proc = proc

    def _shoot(self):
        png = take_screenshot()
        if not png:
            GLib.idle_add(self._dictate_done, "")
            GLib.idle_add(lambda: self.entry.set_placeholder_text(
                "📷 screenshot cancelled/failed"))
            return
        prompt = self.entry.get_text().strip() or "What's in this screenshot?"
        self.entry.set_text("")
        self._work(prompt, png)

    def on_history(self, *a):
        self._close_pop()
        pop = Gtk.Popover()
        pop.set_parent(self.hist_btn)
        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2)
        box.add_css_class("pop")
        title = Gtk.Label(label="Recent asks")
        title.add_css_class("pop-title")
        box.append(title)
        rows = read_history()
        if not rows:
            box.append(Gtk.Label(label="(none yet)"))
        else:
            for item in rows:
                q = item.get("q", "")
                row = Gtk.Button(
                    label=(q[:48] + "…") if len(q) > 48 else q)
                row.add_css_class("hist-row")
                row.connect("clicked",
                            lambda b, qq=q: self._use_hist(qq, pop))
                box.append(row)
        pop.set_child(box)
        pop.popup()
        self._pop = pop

    def _use_hist(self, q, pop):
        self.entry.set_text(q)
        self.entry.grab_focus()
        pop.popdown()

    def on_clock(self, *a):
        self._close_pop()
        pop = Gtk.Popover()
        pop.set_parent(self.clock_btn)
        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=6)
        box.add_css_class("pop")
        tlabel = Gtk.Label()
        tlabel.add_css_class("pop-title")
        dlabel = Gtk.Label()
        dlabel.add_css_class("pop-label")
        box.append(Gtk.Label(label="🕘 now"))
        box.children()[-1].add_css_class("pop-title")
        box.append(tlabel)
        box.append(dlabel)
        pop.set_child(box)
        pop.popup()
        self._pop = pop

        def tick():
            now = time.localtime()
            tlabel.set_label(time.strftime("%H:%M:%S", now))
            dlabel.set_label(time.strftime("%A %d %B %Y", now))
            return True
        tick()
        if self._clock_source:
            GLib.source_remove(self._clock_source)
        self._clock_source = GLib.timeout_add(1000, tick)

    def on_settings(self, *a):
        self._close_pop()
        pop = Gtk.Popover()
        pop.set_parent(self.set_btn)
        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)
        box.add_css_class("pop")
        entries = {}
        for label, key in (("Model", "model"), ("Endpoint", "endpoint"),
                           ("Mic source", "mic_source"),
                           ("Record secs", "record_seconds")):
            lab = Gtk.Label(label=label)
            lab.add_css_class("pop-label")
            lab.set_halign(Gtk.Align.START)
            box.append(lab)
            ent = Gtk.Entry()
            ent.set_text(str(self.settings.get(key, "")))
            ent.add_css_class("entry2")
            ent.set_name(key)
            box.append(ent)
            entries[key] = ent
        save = Gtk.Button(label="Save")
        save.add_css_class("round-btn")
        clr = Gtk.Button(label="Clear history")
        clr.add_css_class("round-btn")
        save.connect("clicked", lambda b: self._save_settings(pop, entries))
        clr.connect("clicked",
                    lambda b: (open(HIST, "w").close(), self._close_pop()))
        row = Gtk.Box(spacing=8)
        row.append(save)
        row.append(clr)
        box.append(row)
        pop.set_child(box)
        pop.popup()
        self._pop = pop

    def _save_settings(self, pop, entries):
        for k, e in entries.items():
            val = e.get_text().strip()
            if k == "record_seconds":
                try:
                    val = int(val)
                except Exception:
                    val = 4
            self.settings[k] = val
        save_settings(self.settings)
        global MODEL, URL
        MODEL = self.settings.get("model", MODEL)
        URL = self.settings.get("endpoint", URL)
        self._close_pop()

    def _close_pop(self):
        if self._clock_source:
            GLib.source_remove(self._clock_source)
            self._clock_source = None
        if self._pop:
            try:
                self._pop.popdown()
            except Exception:  # noqa: BLE001
                pass
            self._pop = None

    # ---- workers ----------------------------------------------------------
    def _dictate(self):
        secs = int(self.settings.get("record_seconds", 4) or 4)
        # stream interim transcripts into the box as the user speaks
        text = record_and_stream(
            secs, self.settings.get("mic_source"),
            lambda t: GLib.idle_add(self._live_text, t))
        GLib.idle_add(self._dictate_done, text)

    def _live_text(self, t):
        self.entry.set_text(t)
        self.entry.set_position(-1)
        return False

    def _dictate_done(self, text):
        self._set_busy(False)
        if text:
            self.entry.set_text(text)
            self.entry.grab_focus()
            self.entry.set_position(-1)
        else:
            self.entry.set_placeholder_text(
                "🎤 STT offline — type instead")
        return False

    def _work(self, prompt, image_path):
        ans = chat(prompt, image_path)
        log_history(prompt, ans)
        GLib.idle_add(self._done, ans)

    def _done(self, ans):
        self._set_busy(False)
        self._show_reply(ans)
        return False

    def _show_reply(self, ans):
        """Show the model's answer in a little dropdown (popover) under the
        bar instead of pushing it to the clipboard. Stays until Esc / new ask."""
        self._close_pop()
        pop = Gtk.Popover()
        pop.set_parent(self.send_btn)
        pop.set_has_arrow(True)

        vbox = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)
        vbox.add_css_class("pop")
        vbox.set_size_request(360, -1)

        title = Gtk.Label(label="✨ reply")
        title.add_css_class("pop-title")
        title.set_halign(Gtk.Align.START)
        vbox.append(title)

        lbl = Gtk.Label(label=ans)
        lbl.set_wrap(True)
        lbl.set_wrap_mode(Gtk.WrapMode.WORD_CHAR)
        lbl.set_selectable(True)
        lbl.set_xalign(0.0)
        lbl.set_valign(Gtk.Align.START)
        lbl.set_margin_start(6)
        lbl.set_margin_end(6)

        sc = Gtk.ScrolledWindow()
        sc.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
        sc.set_child(lbl)
        sc.set_max_content_height(260)
        sc.set_propagate_natural_height(True)
        vbox.append(sc)

        copy = Gtk.Button(label="📋 copy")
        copy.add_css_class("round-btn")
        copy.set_halign(Gtk.Align.END)
        copy.connect("clicked",
                     lambda b: (copy_text(ans), b.set_label("📋 copied ✅"),
                                GLib.timeout_add(1500,
                                                 lambda: b.set_label("📋 copy"))))
        vbox.append(copy)

        pop.set_child(vbox)
        pop.popup()
        self._pop = pop
        self.entry.set_placeholder_text("reply shown — ask again, or Esc to close")
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
