#!/usr/bin/env python3
"""meowbar — native GTK4 layer-shell overlay chat pill (Windows 7 Aero glass).

A real Hyprland layer-surface widget that mirrors the Cluely/Pluely floating
"Ask me anything..." bar, but talks to your local llm-stack LFM on :8080.
No webview, no license — just GTK4 on Wayland with real Aero glass.

Summon:  SUPER+Space   (bound in ~/.config/hypr/hyprland/keybinds.lua)
Type, Enter -> sends to :8080, reply shown in an in-surface panel (no clipboard).
SUPER+Space toggles the bar (show / hide); SUPER+SHIFT+Space also hides.
Every exchange is appended, timestamped and speaker-tagged, to
~/meow_transcript.md (configurable). Rename the speakers or repoint the
file under the ⚙ settings popover.
Buttons:  mic (live-dictate) . new . attach (image->vision) . screenshot .
          record (screen) . history . source . settings . send.

Env overrides:
  MEOWBAR_URL       default http://localhost:8080/v1
  MEOWBAR_MODEL     default LFM2.5-VL-1.6B
  MEOWBAR_KEY       default sk-local
  MEOWBAR_WHISPER   default http://localhost:8081/transcribe
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
WHISPER = os.environ.get("MEOWBAR_WHISPER", "http://localhost:8081/transcribe")
HIST = os.path.expanduser("~/.cache/meowbar/history.jsonl")
os.makedirs(os.path.dirname(HIST), exist_ok=True)
TRANSCRIPT_DEFAULT = os.path.expanduser("~/meow_transcript.md")
_transcript_lock = threading.Lock()
_transcript_day = [None]  # last-written date, so we insert a ## day header on change

CONFIG = os.path.expanduser("~/.config/meowbar/config.json")
SETTINGS_DEFAULT = {
    "model": MODEL,
    "endpoint": URL,
    "mic_source": "",   # empty => auto-detect first Audio/Source
    "record_seconds": 4,
    "speaker_name": "You",        # label for human input in the transcript
    "bot_name": "Neko-chan",      # label for assistant replies in the transcript
    "transcript_path": "",        # empty => ~/meow_transcript.md
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
    """Pick the real PipeWire/ALSA microphone input. Never returns the
    silent 'Dummy' driver or a monitor/sink — those produce empty audio
    and make transcription look broken."""
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
                if "node.description" in line:
                    cur["desc"] = line.split("=", 1)[-1].strip().strip('"')
                if "media.class" in line:
                    cur["cls"] = line.split("=", 1)[-1].strip().strip('"')
                    nm = cur.get("name", "")
                    # real microphone source, explicitly skip Dummy + monitors
                    if (cur.get("cls") == "Audio/Source"
                            and "dummy" not in nm.lower()
                            and "monitor" not in nm.lower()
                            and "mono-fallback" not in nm.lower()):
                        return nm
    except Exception:
        pass
    # hard fallback to the known-good ALSA mic on this machine
    return "alsa_input.pci-0000_00_1f.3.analog-stereo"


def default_monitor_source():
    """Pick the PipeWire monitor (system/computer-audio output capture).

    Returns the '*.monitor' source — the tap on the default output sink, so
    we record what the speakers are playing (meetings, video, music) instead
    of the mic. Falls back to the ALSA hw monitor on this machine.
    """
    try:
        out = subprocess.run(
            ["pw-cli", "list-objects", "Node"],
            capture_output=True, text=True, timeout=8).stdout
        for line in out.splitlines():
            line = line.strip()
            if "node.name" in line and ".monitor" in line:
                nm = line.split("=", 1)[-1].strip().strip('"')
                if "monitor" in nm.lower():
                    return nm
    except Exception:
        pass
    return "alsa_output.pci-0000_00_1f.3.analog-stereo.monitor"


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
.meowbar-reply { background: rgba(225,240,255,0.96); border-radius: 14px;
          border: 1px solid rgba(255,255,255,0.7);
          box-shadow: 0 10px 40px rgba(20,40,80,0.5); padding: 10px 12px;
          color: #0c1a2e; margin-top: 6px; }
.meowbar-reply-scroll { border-radius: 14px; }
.meowbar-reply-scroll > .meowbar-reply { margin-top: 0; }
.meowbar-reply-title { font-weight: 700; color: #0c1a2e;
          margin: 2px 6px 8px; }
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
    """meow-stt (:8081/transcribe) — multipart 'file=' -> diarized transcript.

    Returns the concatenated transcript text (so live-dictation keeps filling
    the entry box as before). Speaker labels are available via
    transcribe_segments() if the caller wants per-speaker lines.
    """
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
            body = r.read().decode().strip()
        # new server returns JSON {"text","segments":[{"speaker","text"}]};
        # the old whisper.cpp returned plain text. Tolerate both.
        if body.startswith("{"):
            try:
                return json.loads(body).get("text", "").strip()
            except Exception:  # noqa: BLE001
                return body
        return body
    except Exception:  # noqa: BLE001
        return ""


def transcribe_segments(wav_path):
    """Like transcribe() but returns the list of {speaker,text} segments
    from meow-stt's diarization, or [] if the server is down / plain text."""
    if not wav_path or not os.path.exists(wav_path):
        return []
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
            body = r.read().decode().strip()
        if body.startswith("{"):
            return json.loads(body).get("segments", [])
    except Exception:  # noqa: BLE001
        pass
    return []


# ---- audio recorder: transcribe + save (transcript md + wav) ------------
import re as _re

TRANSCRIPTS_DIR = os.path.expanduser("~/Documents/meow-transcripts")
RECORDINGS_DIR = os.path.expanduser("~/Pictures/meow-recordings")


def sanitize_filename(name, maxlen=60):
    """Turn arbitrary text into a safe single-path-segment filename."""
    name = _re.sub(r'[^\w\s\-]', '', name, flags=_re.UNICODE)
    name = _re.sub(r'\s+', ' ', name).strip()
    name = name[:maxlen].strip()
    return name or "untitled"


def autotitle(transcript):
    """Ask the local LFM for a SHORT (3-5 word) title for the transcript.

    Fully offline (uses chat() -> :8080). Falls back to 'untitled' on any
    error or empty reply."""
    if not transcript.strip():
        return "untitled"
    prompt = (
        "Summarize the following spoken transcript into a SHORT title of "
        "3 to 5 words. Reply with ONLY the title — no quotes, no trailing "
        "punctuation, no explanation.\n\n" + transcript[:2000]
    )
    t = chat(prompt).strip().strip('"').strip("'").strip()
    return sanitize_filename(t) or "untitled"


def save_recording(transcript, wav_path, title, settings):
    """Write transcript markdown to ~/Documents/meow-transcripts/<title>.md
    and copy the wav to ~/Pictures/meow-recordings/<title>.wav. Returns the
    two paths (rec_path may be None if the wav was missing)."""
    os.makedirs(TRANSCRIPTS_DIR, exist_ok=True)
    os.makedirs(RECORDINGS_DIR, exist_ok=True)
    ts = time.strftime("%Y-%m-%d %H:%M:%S")
    safe = sanitize_filename(title)
    stamp = f"-{int(time.time())}"
    md_path = os.path.join(TRANSCRIPTS_DIR, safe + ".md")
    if os.path.exists(md_path):
        md_path = os.path.join(TRANSCRIPTS_DIR, safe + stamp + ".md")
    with open(md_path, "w") as f:
        f.write(f"# {title}\n\n")
        f.write(f"_recorded {ts}_\n\n")
        f.write((transcript or "").strip() + "\n")
    rec_path = None
    if wav_path and os.path.exists(wav_path):
        rec_path = os.path.join(RECORDINGS_DIR, safe + ".wav")
        if os.path.exists(rec_path):
            rec_path = os.path.join(RECORDINGS_DIR, safe + stamp + ".wav")
        try:
            shutil.copy(wav_path, rec_path)
        except Exception:  # noqa: BLE001
            rec_path = None
    # also log into the running meow_transcript.md for continuity
    log_transcript(settings.get("speaker_name", "You"), transcript, settings)
    return md_path, rec_path


def start_audio_capture(wav_path, source):
    """Start ffmpeg capturing mic -> 16k mono wav. Returns the Popen."""
    src = source or default_mic_source()
    # avoid the PipeWire null sink if a real source exists
    if src in ("Dummy-Driver", "dummy-output", "null"):
        real = default_mic_source()
        if real and real != src:
            src = real
    return subprocess.Popen(
        ["ffmpeg", "-y", "-f", "pulse", "-i", src, "-ar", "16000", "-ac", "1",
         wav_path],
        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def stop_audio_capture(proc):
    if proc is None:
        return
    try:
        proc.terminate()
        proc.wait(timeout=4)
    except Exception:  # noqa: BLE001
        try:
            proc.kill()
        except Exception:  # noqa: BLE001
            pass


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


def transcript_path(settings):
    p = (settings.get("transcript_path") or "").strip()
    return os.path.expanduser(p) if p else TRANSCRIPT_DEFAULT


def log_transcript(speaker, text, settings):
    """Append one timestamped, speaker-tagged line to the markdown transcript.

    On a new calendar day a '## Monday 13 July 2026' header is written first,
    so a long-running file groups entries by day. Idempotent per (speaker,text)
    is NOT enforced — every call logs (the user may re-ask the same thing)."""
    text = (text or "").strip()
    if not text:
        return
    now = time.localtime()
    ts = time.strftime("%H:%M:%S", now)
    day = time.strftime("%A %d %B %Y", now)
    path = transcript_path(settings)
    try:
        os.makedirs(os.path.dirname(path) or ".", exist_ok=True)
        with _transcript_lock:
            new = not os.path.exists(path) or os.path.getsize(path) == 0
            with open(path, "a") as f:
                if new:
                    f.write("# meowbar transcript\n\n")
                if _transcript_day[0] != day:
                    if not new:
                        f.write("\n")
                    f.write(f"## {day}\n\n")
                    _transcript_day[0] = day
                # speaker-tagged line:  HH:MM:SS — Speaker: text
                f.write(f"- {ts} — {speaker}: {text}\n")
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
        self.app = Gtk.Application(
            application_id="me.c3nd.meowbar",
            flags=Gio.ApplicationFlags.HANDLES_COMMAND_LINE)
        self.app.connect("activate", self.on_activate)
        self.app.connect("command-line", self.on_command_line)
        self._activated = False
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
        self.audio_proc = None  # mic capture Popen when recording
        self.audio_wav = "/tmp/meow_audio.wav"
        # capture source for the 🎤 audio recorder: "mic" or "system"
        self.audio_source = "mic"
        self.mic_btn = self._icon_btn("🎤", "Record audio (tap to start/stop)", self.on_mic)
        self.new_btn = self._icon_btn("✏️", "New chat", self.on_new)
        self.attach_btn = self._icon_btn("📎", "Attach image (vision)",
                                         self.on_attach)
        self.shot_btn = self._icon_btn("📷", "Screenshot → vision",
                                       self.on_screenshot)
        self.rec_btn = self._icon_btn("🎬", "Record screen", self.on_record)
        self.hist_btn = self._icon_btn("📜", "History", self.on_history)
        self.src_btn = self._icon_btn("🎙", "Capture: Microphone (tap to switch to System audio)", self.on_toggle_source)
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
        pill.append(self.src_btn)
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

        # in-surface reply panel (below the pill) — grows on reply, hidden when
        # empty. Wrapped in a ScrolledWindow capped at a max height so a long
        # transcript/answer scrolls inside instead of inflating the whole bar.
        self.reply_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=6)
        self.reply_box.add_css_class("meowbar-reply")
        self.reply_box.set_visible(True)

        self.reply_scroll = Gtk.ScrolledWindow()
        self.reply_scroll.set_child(self.reply_box)
        self.reply_scroll.set_propagate_natural_height(True)
        self.reply_scroll.set_max_content_height(300)
        self.reply_scroll.set_min_content_height(40)
        self.reply_scroll.set_policy(Gtk.PolicyType.NEVER,
                                     Gtk.PolicyType.AUTOMATIC)
        self.reply_scroll.add_css_class("meowbar-reply-scroll")
        self.reply_scroll.set_visible(False)
        self.reply_scroll.set_margin_top(6)

        vbox = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=0)
        vbox.append(overlay)
        vbox.append(self.reply_scroll)

        self.win.set_child(vbox)
        self.win.present()
        self.entry.grab_focus()
        self._pop = None
        self._activated = True

    def on_command_line(self, app, cmdline):
        # With HANDLES_COMMAND_LINE, GApplication does NOT auto-activate, so we
        # must present the window ourselves on the first launch. Later launches
        # (the SUPER+Space keybind) toggle/hide the already-running instance.
        args = cmdline.get_arguments()
        force_hide = len(args) > 1 and args[1] == "hide"
        if not self._activated:
            # first launch: show the bar (on_activate builds + presents it)
            self.app.activate()
        else:
            GLib.idle_add(lambda: (self._hide() if force_hide else self.toggle())
                          or False)
        return 0

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
            # first Esc closes any reply panel; second Esc hides the bar
            if self.reply_scroll.get_visible():
                self.reply_scroll.set_visible(False)
                self.entry.set_placeholder_text("Ask me anything…")
                return True
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
        """Toggle audio recorder. First tap starts capture; second tap stops
        it, transcribes, and shows the transcript with a Save (auto-title)
        action in the reply panel."""
        self._close_pop()
        if self.audio_proc is not None:
            # stop -> transcribe
            self.mic_btn.remove_css_class("rec-on")
            self.entry.set_placeholder_text("🎤 transcribing…")
            self._set_busy(True)
            threading.Thread(target=self._transcribe_recording,
                             daemon=True).start()
        else:
            # start capture
            src = (default_monitor_source() if self.audio_source == "system"
                   else self.settings.get("mic_source"))
            self.entry.set_text("")
            label = ("🎤 recording SYSTEM audio… tap 🎤 again to stop"
                     if self.audio_source == "system"
                     else "🎤 recording… tap 🎤 again to stop")
            self.entry.set_placeholder_text(label)
            self.mic_btn.add_css_class("rec-on")
            self.audio_proc = start_audio_capture(self.audio_wav, src)

    def _transcribe_recording(self):
        stop_audio_capture(self.audio_proc)
        self.audio_proc = None
        wav = self.audio_wav
        has_audio = os.path.exists(wav) and os.path.getsize(wav) > 44
        text = transcribe(wav).strip() if has_audio else ""
        segs = transcribe_segments(wav) if has_audio else []
        if not text:
            GLib.idle_add(self._rec_done_empty, has_audio)
            return
        # render diarized (or flat) body text. Speaker identity is NOT
        # inferred here — segments are shown as neutral "Speaker N:" and the
        # user relabels them in the transcript panel after seeing the text.
        if segs:
            spk = sorted({s.get("speaker", "") for s in segs
                         if s.get("speaker")})
            default_names = {k: f"Speaker {i+1}"
                             for i, k in enumerate(spk)}
            body = "\n".join(
                f"{default_names[s.get('speaker','')]}: "
                f"{s.get('text','').strip()}" for s in segs)
        else:
            default_names = {}
            body = text
        # generate an AI title (offline, local LFM) in the same worker
        title = autotitle(body)
        GLib.idle_add(self._rec_done, body, title, segs, default_names)

    def _rec_done_empty(self, had_audio):
        self._set_busy(False)
        self.mic_btn.remove_css_class("rec-on")
        msg = ("🎤 no speech detected" if had_audio
               else "🎤 no audio captured (mic source?)")
        self.entry.set_placeholder_text(msg)
        return False

    def _rec_done(self, text, title, segs=None, default_names=None):
        self._set_busy(False)
        self.mic_btn.remove_css_class("rec-on")
        self._show_transcript(text, title, segs or [], default_names or {})
        return False

    def _show_transcript(self, text, title, segs=None, default_names=None):
        """Reply panel showing the transcript, an editable title, and a
        Save button that writes md + wav to the transcripts/recordings dirs.

        When the server returned per-speaker segments, the transcript is shown
        as neutral 'Speaker N:' lines and — only if there are 2+ speakers — a
        relabel row lets you rename each speaker *after* reading the text
        (identity is never guessed up front).
        """
        segs = segs or []
        default_names = default_names or {}
        while self.reply_box.get_first_child() is not None:
            self.reply_box.remove(self.reply_box.get_first_child())

        title_lbl = Gtk.Label(label="✍️ transcript")
        title_lbl.add_css_class("meowbar-reply-title")
        title_lbl.set_halign(Gtk.Align.START)
        self.reply_box.append(title_lbl)

        # live speaker-name map (mutable; edited by the relabel dropdowns)
        names = dict(default_names)

        def render_body():
            if segs and names:
                return "\n".join(
                    f"{names.get(s.get('speaker',''), s.get('speaker',''))}: "
                    f"{s.get('text','').strip()}" for s in segs)
            return text

        body = Gtk.Label(label=render_body())
        body.set_wrap(True)
        body.set_wrap_mode(Gtk.WrapMode.WORD_CHAR)
        body.set_selectable(True)
        body.set_xalign(0.0)
        body.set_valign(Gtk.Align.START)
        body.set_margin_start(6)
        body.set_margin_end(6)
        self.reply_box.append(body)

        # relabel row: only when 2+ distinct speakers exist
        speakers = list(default_names.keys())
        if len(speakers) >= 2:
            relbl = Gtk.Label(label="who's who:")
            relbl.add_css_class("pop-label")
            relbl.set_halign(Gtk.Align.START)
            self.reply_box.append(relbl)
            for spk in speakers:
                r = Gtk.Box(spacing=6)
                lab = Gtk.Label(label=default_names[spk])
                lab.add_css_class("pop-label")
                lab.set_halign(Gtk.Align.START)
                combo = Gtk.DropDown.new_from_strings(
                    [default_names[spk], "You", "Bot", "Them", "Other"])
                combo.set_selected(0)
                combo.connect("notify::selected",
                              lambda c, spk=spk, *_: (
                                  names.__setitem__(
                                      spk, c.get_selected_item().get_string()),
                                  body.set_label(render_body())))
                r.append(lab)
                r.append(combo)
                self.reply_box.append(r)

        # title row: editable entry + Save / Don't-save buttons
        row = Gtk.Box(spacing=8)
        title_ent = Gtk.Entry()
        title_ent.set_text(title)
        title_ent.set_hexpand(True)
        title_ent.add_css_class("entry2")
        title_ent.set_placeholder_text("title (auto-generated)")
        row.append(title_ent)

        save = Gtk.Button(label="💾 Save")
        save.add_css_class("round-btn")
        row.append(save)

        nosave = Gtk.Button(label="✖ Don't save")
        nosave.add_css_class("round-btn")
        row.append(nosave)
        self.reply_box.append(row)

        def do_save(b):
            chosen = (title_ent.get_text().strip() or title
                      or "untitled")
            # re-render with any relabels applied before saving
            md_path, rec_path = save_recording(
                render_body(), self.audio_wav, chosen, self.settings)
            save.set_label("💾 saved ✅")
            nosave.set_sensitive(False)
            self.entry.set_placeholder_text(
                "💾 saved to Documents/meow-transcripts")
            conf = Gtk.Label(label=f"saved: {os.path.basename(md_path)}")
            conf.add_css_class("pop-label")
            conf.set_halign(Gtk.Align.START)
            self.reply_box.append(conf)

        def do_nosave(b):
            # dismiss without writing anything; transcript panel hidden
            self.reply_scroll.set_visible(False)
            self.mic_btn.remove_css_class("rec-on")
            self.entry.set_placeholder_text("🎤 transcript discarded")

        save.connect("clicked", do_save)
        nosave.connect("clicked", do_nosave)
        self.reply_scroll.set_visible(True)
        self.win.set_visible(True)
        self.entry.set_placeholder_text(
            "transcript ready — edit title, hit 💾 Save")
        return False

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

    def on_toggle_source(self, *a):
        """Toggle the 🎤 recorder's capture source between microphone and
        system (computer) audio. Updates the source button label/icon + the
        recorder placeholder so the user knows what they'll capture."""
        self._close_pop()
        if self.audio_source == "mic":
            self.audio_source = "system"
            self.src_btn.set_label("🔊")  # speaker = system capture active
            self.src_btn.set_tooltip_text(
                "Capture: System audio (tap to switch to Microphone)")
            self.entry.set_placeholder_text(
                "🎤 will record SYSTEM audio — tap 🎤 to start")
        else:
            self.audio_source = "mic"
            self.src_btn.set_label("🎙")
            self.src_btn.set_tooltip_text(
                "Capture: Microphone (tap to switch to System audio)")
            self.entry.set_placeholder_text(
                "🎤 will record MIC — tap 🎤 to start")

    def on_settings(self, *a):
        self._close_pop()
        pop = Gtk.Popover()
        pop.set_parent(self.set_btn)
        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)
        box.add_css_class("pop")
        entries = {}
        for label, key in (("Model", "model"), ("Endpoint", "endpoint"),
                           ("Mic source", "mic_source"),
                           ("Record secs", "record_seconds"),
                           ("Your name (transcript)", "speaker_name"),
                           ("Bot name (transcript)", "bot_name"),
                           ("Transcript path (blank=~/meow_transcript.md)",
                            "transcript_path")):
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
        if self._pop:
            try:
                self._pop.popdown()
            except Exception:  # noqa: BLE001
                pass
            self._pop = None


    def _work(self, prompt, image_path):
        ans = chat(prompt, image_path)
        log_history(prompt, ans)
        # timestamped, speaker-tagged transcript
        log_transcript(self.settings.get("speaker_name", "You"), prompt,
                       self.settings)
        log_transcript(self.settings.get("bot_name", "Neko-chan"), ans,
                       self.settings)
        GLib.idle_add(self._done, ans)

    def _done(self, ans):
        self._set_busy(False)
        self._show_reply(ans)
        return False

    def _show_reply(self, ans):
        """Show the model's answer in an in-surface panel below the pill (no
        Gtk.Popover — those are flaky on wlroots layer-surfaces and only show
        ~half the time). Stays until Esc / new ask / hide."""
        # (re)build the panel content
        while self.reply_box.get_first_child() is not None:
            self.reply_box.remove(self.reply_box.get_first_child())

        title = Gtk.Label(label="✨ reply")
        title.add_css_class("meowbar-reply-title")
        title.set_halign(Gtk.Align.START)
        self.reply_box.append(title)

        lbl = Gtk.Label(label=ans)
        lbl.set_wrap(True)
        lbl.set_wrap_mode(Gtk.WrapMode.WORD_CHAR)
        lbl.set_selectable(True)
        lbl.set_xalign(0.0)
        lbl.set_valign(Gtk.Align.START)
        lbl.set_margin_start(6)
        lbl.set_margin_end(6)
        self.reply_box.append(lbl)

        copy = Gtk.Button(label="📋 copy")
        copy.add_css_class("round-btn")
        copy.set_halign(Gtk.Align.END)
        copy.connect("clicked",
                     lambda b: (copy_text(ans), b.set_label("📋 copied ✅"),
                                GLib.timeout_add(1500,
                                                 lambda: b.set_label("📋 copy"))))
        self.reply_box.append(copy)

        self.reply_scroll.set_visible(True)
        self.win.set_visible(True)  # ensure bar is up when reply arrives
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
        self.reply_scroll.set_visible(False)
        self.win.set_visible(False)

    def toggle(self):
        """Show if hidden, hide if visible (SUPER+Space)."""
        if self.win.get_visible():
            self._hide()
        else:
            self.win.set_visible(True)
            self.entry.grab_focus()
        return False


if __name__ == "__main__":
    Bar()

