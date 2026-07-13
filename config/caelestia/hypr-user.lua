-- User Hyprland overrides (loaded last, after caelestia defaults).

-- AI scratchpad: SUPER+A toggles a floating aichat TUI (foot, class "aichat")
-- on special:ai, talking to the local llm-stack LFM on :8080.
hl.bind("SUPER + A", hl.dsp.exec_cmd("caelestia toggle ai"))

-- meowbar: SUPER+Space summons the native GTK4 overlay chat pill (Pluely-style),
-- wired to :8080. Re-launch if already running so it re-grabs focus.
hl.bind("SUPER + SPACE", hl.dsp.exec_cmd(
  "pkill -f meowbar.py 2>/dev/null; sleep 0.1; nohup meowbar >/dev/null 2>&1 &"))

-- Game mode (end4-style): SUPER+F kills blur/shadows/animations/gaps for max FPS.
hl.bind("SUPER + F", hl.dsp.exec_cmd("caelestia shell gameMode toggle"))

-- Reuse caelestia's built-in 60%x70% centered-floater tag for the scratchpad.
hl.window_rule({ match = { class = "aichat" }, tag = "+float_60_70" })
