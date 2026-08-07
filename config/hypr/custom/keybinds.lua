-- Cassiopeia custom keybinds
-- Integrated with DankMaterialShell IPC where applicable
-- Window/workspace management stays Hyprland-native

require("hyprland.lib")
require("hyprland.variables")
if is_file_exists(HOME .. "/.config/hypr/custom/variables.lua") then
    require("custom.variables")
end

-- === DMS IPC: Audio ===
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("dms ipc call audio increment 2"), { locked = true, repeating = true, description = "Audio: Volume up" })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("dms ipc call audio decrement 2"), { locked = true, repeating = true, description = "Audio: Volume down" })
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("dms ipc call audio mute"), { locked = true, description = "Audio: Mute" })
hl.bind("CTRL + SUPER + M", hl.dsp.exec_cmd("dms ipc call mic mute"), { description = "Audio: Mic mute toggle" })

-- === DMS IPC: Media ===
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("dms ipc call mpris playPause"), { locked = true, description = "Media: Play/Pause" })
hl.bind("XF86AudioNext", hl.dsp.exec_cmd("dms ipc call mpris next"), { locked = true, description = "Media: Next track" })
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("dms ipc call mpris previous"), { locked = true, description = "Media: Prev track" })
hl.bind("XF86AudioStop", hl.dsp.exec_cmd("dms ipc call mpris stop"), { locked = true, description = "Media: Stop" })

-- === DMS IPC: Brightness ===
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("dms ipc call brightness increment 10"), { locked = true, repeating = true, description = "Display: Brightness up" })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("dms ipc call brightness decrement 10"), { locked = true, repeating = true, description = "Display: Brightness down" })

-- === DMS IPC: Night mode ===
hl.bind("SUPER + SHIFT + N", hl.dsp.exec_cmd("dms ipc call night toggle"), { description = "Display: Night mode toggle" })

-- === DMS IPC: Lock / Inhibit ===
hl.bind("SUPER + L", hl.dsp.exec_cmd("dms ipc call lock lock"), { description = "Session: Lock" })
hl.bind("SUPER + SHIFT + L", hl.dsp.exec_cmd("dms ipc call inhibit toggle || loginctl suspend"), { locked = true, description = "Session: Sleep / Inhibit idle" })

-- === DMS IPC: Power profile ===
hl.bind("SUPER + SHIFT + P", hl.dsp.exec_cmd("dms ipc call powerprofile cycle"), { description = "Power: Cycle power profile" })

-- === DMS IPC: Wallpaper ===
hl.bind("SUPER + SHIFT + W", hl.dsp.exec_cmd("dms ipc call wallpaper next"), { description = "Wallpaper: Next wallpaper" })

-- === DMS IPC: Theme ===
hl.bind("SUPER + SHIFT + T", hl.dsp.exec_cmd("dms ipc call theme toggle"), { description = "Appearance: Theme toggle" })

-- === DMS IPC: Sessions ===
hl.bind("SUPER + SHIFT + S", hl.dsp.exec_cmd("dms ipc call sessions open"), { description = "Session: Switch user" })

-- === Direct utilities: Screenshot / Clipboard / Color / Recording ===
hl.bind("SUPER + SHIFT + C", hl.dsp.exec_cmd("hyprpicker -a"), { description = "Utilities: Pick color #RRGGBB >> clipboard" })
hl.bind("SUPER + SHIFT + R", hl.dsp.exec_cmd("wf-recorder -f /tmp/recording_$(date +%s).mp4"), { locked = true, description = "Utilities: Record region" })
hl.bind("Print", hl.dsp.exec_cmd("grim -o \"$(hyprctl activeworkspace -j | jq -r '.monitor')\" - | wl-copy"), { locked = true, description = "Utilities: Screenshot >> clipboard" })
hl.bind("SUPER + Print", hl.dsp.exec_cmd("hyprshot --freeze --clipboard-only --mode region --silent"), { description = "Utilities: Screen snip" })

-- === Hyprland window management ===
for i = 1, 4 do
    local arrowkey = { "Left", "Right", "Up", "Down" }
    local focusdir = { "l", "r", "u", "d" }
    hl.bind("SUPER + " .. arrowkey[i], hl.dsp.focus({ direction = focusdir[i] }), { description = "Window: Focus " .. arrowkey[i] })
end
for i = 1, 4 do
    local arrowkey = { "Left", "Right", "Up", "Down" }
    local focusdir = { "l", "r", "u", "d" }
    hl.bind("SUPER + SHIFT + " .. arrowkey[i], hl.dsp.window.move({ direction = focusdir[i] }), { description = "Window: Move " .. arrowkey[i] })
end
hl.bind("SUPER + Q", hl.dsp.window.close(), { description = "Window: Close" })
hl.bind("SUPER + D", hl.dsp.window.fullscreen({ mode = "maximized", action = "toggle" }), { description = "Window: Maximize" })
hl.bind("SUPER + F", hl.dsp.window.fullscreen({ mode = "fullscreen", action = "toggle" }), { description = "Window: Fullscreen" })
hl.bind("SUPER + ALT + Space", hl.dsp.window.float({ action = "toggle" }), { description = "Window: Float/Tile" })

-- === Workspaces ===
for i = 1, 10 do
    hl.bind("SUPER + " .. (i % 10), function()
        hl.dispatch(hl.dsp.focus({ workspace = workspace_in_group(i) }))
    end, { description = "Workspace: Focus " .. i })
end

-- === Apps ===
hl.bind("SUPER + Return", hl.dsp.exec_cmd(terminal), { description = "App: Terminal" })
hl.bind("SUPER + E", hl.dsp.exec_cmd(fileManager), { description = "App: File manager" })
hl.bind("SUPER + W", hl.dsp.exec_cmd(browser), { description = "App: Browser" })
hl.bind("SUPER + C", hl.dsp.exec_cmd(codeEditor), { description = "App: Code editor" })
hl.bind("SUPER + X", hl.dsp.exec_cmd(textEditor), { description = "App: Text editor" })
hl.bind("SUPER + V", hl.dsp.exec_cmd(volumeMixer), { description = "App: Volume mixer" })
hl.bind("SUPER + B", hl.dsp.exec_cmd("brave"), { description = "App: Brave browser" })
