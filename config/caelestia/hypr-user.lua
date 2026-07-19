-- User Hyprland overrides (loaded last, after caelestia defaults).

-- Game mode (end4-style): SUPER+F kills blur/shadows/animations/gaps for max FPS.
hl.bind("SUPER + F", hl.dsp.exec_cmd("caelestia shell gameMode toggle"))

------------------------------------------------------------------------
-- Handy (speech-to-text) — Wayland/Hyprland workarounds
-- Issue: Handy's in-app global hotkey engine (muda) does NOT register on
-- wlroots/Hyprland (Handy issue #949), and its overlay renders as a full
-- tiled window instead of a layer-shell pill (#1555 / #1375).
-- Fix: let Hyprland own the key and drive Handy's single-instance CLI flags
-- (`handy --toggle-transcription`). NOTE: Handy's docs recommend `pkill -USR2`
-- for Wayland, but the Nix wrapper renames the process to `.handy-wrapped`, so
-- `pkill -x handy` never matches — CLI flags are the reliable path here. The
-- overlay window is floated so it doesn't disturb tiling.
------------------------------------------------------------------------

-- SUPER+SHIFT+Space  -> start/stop dictation
hl.bind("SUPER + SHIFT + Space", hl.dsp.exec_cmd("handy --toggle-transcription"))

-- SUPER+SHIFT+P      -> start/stop dictation WITH post-processing
hl.bind("SUPER + SHIFT + P", hl.dsp.exec_cmd("handy --toggle-post-process"))

-- SUPER+SHIFT+Escape -> cancel current recording
hl.bind("SUPER + SHIFT + Escape", hl.dsp.exec_cmd("handy --cancel"))

-- Handy's recording "overlay" window shares class=handy with its settings
-- window, and gtk-layer-shell doesn't present a proper layer on wlroots
-- here (#1555 / #1375). So we float + center + size it into a clean panel
-- instead of a full tiled window. (No `pin` — that would also stick the
-- settings dialog to every workspace.)
hl.window_rule({
    match   = { class = "handy" },
    float   = true,
    center  = true,
    no_blur = true,
    size    = "(monitor_w*0.42) (monitor_h*0.7)",
})

-- Autostart Handy hidden on login (same mechanism as caelestia's execs.lua
-- launches zen-beta/equibop/kopuz). Needed so the --toggle-transcription
-- keybinds have a running instance to talk to.
hl.on("hyprland.start", function()
    hl.exec_cmd("handy --start-hidden")
end)
