-- Cassiopeia custom keybinds
-- Uses plain Hyprland Lua API
-- DMS IPC commands stay shell-level (dms ipc call ...)

-- === DMS IPC: Audio ===
bind("XF86AudioRaiseVolume", "exec, dms ipc call audio increment 2", "Audio: Volume up")
bind("XF86AudioLowerVolume", "exec, dms ipc call audio decrement 2", "Audio: Volume down")
bind("XF86AudioMute", "exec, dms ipc call audio mute", "Audio: Mute")
bind("CTRL + SUPER + M", "exec, dms ipc call mic mute", "Audio: Mic mute toggle")

-- === DMS IPC: Media ===
bind("XF86AudioPlay", "exec, dms ipc call mpris playPause", "Media: Play/Pause")
bind("XF86AudioNext", "exec, dms ipc call mpris next", "Media: Next track")
bind("XF86AudioPrev", "exec, dms ipc call mpris previous", "Media: Prev track")
bind("XF86AudioStop", "exec, dms ipc call mpris stop", "Media: Stop")

-- === DMS IPC: Brightness ===
bind("XF86MonBrightnessUp", "exec, dms ipc call brightness increment 10", "Display: Brightness up")
bind("XF86MonBrightnessDown", "exec, dms ipc call brightness decrement 10", "Display: Brightness down")

-- === DMS IPC: Night mode ===
bind("SUPER + SHIFT + N", "exec, dms ipc call night toggle", "Display: Night mode toggle")

-- === DMS IPC: Lock / Inhibit ===
bind("SUPER + L", "exec, dms ipc call lock lock", "Session: Lock")
bind("SUPER + SHIFT + L", "exec, dms ipc call inhibit toggle || loginctl suspend", "Session: Sleep / Inhibit idle")

-- === DMS IPC: Power profile ===
bind("SUPER + SHIFT + P", "exec, dms ipc call powerprofile cycle", "Power: Cycle power profile")

-- === DMS IPC: Wallpaper ===
bind("SUPER + SHIFT + W", "exec, dms ipc call wallpaper next", "Wallpaper: Next wallpaper")

-- === DMS IPC: Theme ===
bind("SUPER + SHIFT + T", "exec, dms ipc call theme toggle", "Appearance: Theme toggle")

-- === DMS IPC: Sessions ===
bind("SUPER + SHIFT + S", "exec, dms ipc call sessions open", "Session: Switch user")

-- === Direct utilities ===
bind("SUPER + SHIFT + C", "exec, hyprpicker -a", "Utilities: Pick color #RRGGBB >> clipboard")
bind("SUPER + SHIFT + R", "exec, wf-recorder -f /tmp/recording_" .. os.date("%s") .. ".mp4", "Utilities: Record region")
bind("Print", "exec, grim -o \"$(hyprctl activeworkspace -j | jq -r '.monitor')\" - | wl-copy", "Utilities: Screenshot >> clipboard")
bind("SUPER + Print", "exec, hyprshot --freeze --clipboard-only --mode region --silent", "Utilities: Screen snip")

-- === Hyprland window management ===
bind("SUPER + Q", "closewindow", "Window: Close")
bind("SUPER + D", "fullscreen, 1", "Window: Maximize")
bind("SUPER + F", "fullscreen, 0", "Window: Fullscreen")
bind("SUPER + ALT + Space", "togglefloating", "Window: Float/Tile")

-- Direction focus/move
bind("SUPER + Left", "movefocus, l", "Window: Focus left")
bind("SUPER + Right", "movefocus, r", "Window: Focus right")
bind("SUPER + Up", "movefocus, u", "Window: Focus up")
bind("SUPER + Down", "movefocus, d", "Window: Focus down")

bind("SUPER + SHIFT + Left", "movewindow, l", "Window: Move left")
bind("SUPER + SHIFT + Right", "movewindow, r", "Window: Move right")
bind("SUPER + SHIFT + Up", "movewindow, u", "Window: Move up")
bind("SUPER + SHIFT + Down", "movewindow, d", "Window: Move down")

-- === Workspaces ===
for i = 1, 10 do
    local ws = (i == 10) and 0 or i
    bind("SUPER + " .. ws, "workspace, " .. ws, "Workspace: Focus " .. i)
    bind("SUPER + SHIFT + " .. ws, "movetoworkspace, " .. ws, "Workspace: Move to " .. i)
    bind("SUPER + ALT + " .. ws, "movetoworkspace, silent, " .. ws .. "; workspace, " .. ws, "Workspace: Move+follow " .. i)
end

-- === Apps ===
bind("SUPER + Return", "exec, kitty", "App: Terminal")
bind("SUPER + E", "exec, kitty --class file-manager -e ranger || thunar || pcmanfm", "App: File manager")
bind("SUPER + W", "exec, brave || zen-browser || firefox", "App: Browser")
bind("SUPER + C", "exec, lapce", "App: Code editor")
bind("SUPER + X", "exec, kitty --class scratchpad", "App: Text editor")
bind("SUPER + V", "exec, pavucontrol || paman", "App: Volume mixer")
bind("SUPER + B", "exec, brave", "App: Brave browser")

-- === System ===
bind("SUPER + SHIFT + Q", "exit", "Session: Exit Hyprland")
bind("SUPER + SHIFT + R", "reload", "Hyprland: Reload config")
