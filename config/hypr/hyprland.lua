-- Cassiopeia Hyprland config
-- Official DMS Lua-based pattern
-- https://danklinux.com/docs/dankmaterialshell/compositors#hyprland-configuration

local home = os.getenv("HOME") or ""

-- === DMS integration ===
if home ~= "" then
  local dms_dir = home .. "/.config/hypr/dms"
  local function is_file_exists(path)
    local f = io.open(path, "r")
    if f then
      f:close()
      return true
    end
    return false
  end

  for _, name in ipairs({ "colors", "layout", "outputs", "keybinds", "bindings" }) do
    if is_file_exists(dms_dir .. "/" .. name .. ".lua") then
      require("dms." .. name)
    end
  end
end

-- === Environment ===
hl.env("QT_QPA_PLATFORM", "wayland")
hl.env("QT_QPA_PLATFORMTHEME", "gtk3")
hl.env("QT_QPA_PLATFORMTHEME_QT6", "gtk3")
hl.env("ELECTRON_OZONE_PLATFORM_HINT", "auto")

-- === Hyprland config ===
hl.config({
  general = {
    gaps_in = 4,
    gaps_out = 8,
    border_size = 1,
    col = {
      active_border = "rgba(ff0000ff)",
      inactive_border = "rgba(111111ff)"
    },
    resize_on_border = true,
    allow_tearing = false,
    layout = "dwindle"
  },
  decoration = {
    rounding = 8,
    active_opacity = 1.0,
    inactive_opacity = 0.9,
    shadow = {
      enabled = true,
      range = 30,
      render_power = 4,
      offset = {0, 5},
      color = "rgba(00000070)"
    }
  },
  animations = {
    enabled = true,
    bezier = { smoothOut = { 0.36, 0, 0.66, -0.56 }, smoothIn = { 0.36, 0, 0.66, -0.56 } },
    animation = { windows = { 1, 6, smoothOut, "slide" }, border = { 1, 10, "default" }, fade = { 1, 10, "default" } }
  },
  dwindle = {
    preserve_split = true
  },
  master = {
    new_status = "master"
  },
  misc = {
    force_default_wallpaper = 0,
    disable_hyprland_logo = true,
    disable_splash_rendering = true,
    vrr = 1,
    animate_manual_resizes = true
  }
})

-- === Layer rules ===
hl.layer_rule({ match = { namespace = "dms" }, no_anim = true })

-- === Window rules ===
hl.window_rule({ match = { float = false, focus = false }, opacity = "0.9 0.9" })
hl.window_rule({ match = { class = "^(org%.gnome%.).*" }, border_size = 0, rounding = 12 })
hl.window_rule({ match = { class = "^kitty$" }, border_size = 0 })

-- === DMS autostart ===
hl.on("hyprland.start", function()
  hl.exec_cmd("dms run")
  -- Optional: Clipboard history
  hl.exec_cmd("bash -c 'wl-paste --watch cliphist store &'")
end)

-- === DMS keybinds ===
hl.bind("SUPER + space", hl.dsp.exec_cmd("dms ipc call spotlight toggle"))
hl.bind("SUPER + V", hl.dsp.exec_cmd("dms ipc call clipboard toggle"))
hl.bind("SUPER + M", hl.dsp.exec_cmd("dms ipc call processlist focusOrToggle"))
hl.bind("SUPER + comma", hl.dsp.exec_cmd("dms ipc call settings focusOrToggle"))
hl.bind("SUPER + N", hl.dsp.exec_cmd("dms ipc call notifications toggle"))
hl.bind("SUPER + Y", hl.dsp.exec_cmd("dms ipc call dankdash wallpaper"))
hl.bind("SUPER + TAB", hl.dsp.exec_cmd("dms ipc call hypr toggleOverview"))

hl.bind("SUPER + ALT + L", hl.dsp.exec_cmd("dms ipc call lock lock"))

hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("dms ipc call audio increment 2", { locked = true, repeating = true }))
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("dms ipc call audio decrement 2", { locked = true, repeating = true }))
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("dms ipc call audio mute", { locked = true }))

hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("dms ipc call brightness increment 10", { locked = true, repeating = true }))
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("dms ipc call brightness decrement 10", { locked = true, repeating = true }))

-- === Custom keybinds ===
hl.bind("SUPER + Return", hl.dsp.exec_cmd("kitty"))
hl.bind("SUPER + E", hl.dsp.exec_cmd("thunar"))
hl.bind("SUPER + W", hl.dsp.exec_cmd("brave || zen-browser || firefox"))
hl.bind("SUPER + C", hl.dsp.exec_cmd("lapce"))
hl.bind("SUPER + X", hl.dsp.exec_cmd("kitty --class scratchpad"))
hl.bind("SUPER + SHIFT + V", hl.dsp.exec_cmd("pavucontrol || paman"))
hl.bind("SUPER + B", hl.dsp.exec_cmd("brave"))

hl.bind("SUPER + Q", hl.dsp.exec_cmd("hyprctl dispatch closewindow"))
hl.bind("SUPER + D", hl.dsp.exec_cmd("hyprctl dispatch fullscreen 1"))
hl.bind("SUPER + F", hl.dsp.exec_cmd("hyprctl dispatch fullscreen 0"))
hl.bind("SUPER + ALT + space", hl.dsp.exec_cmd("hyprctl dispatch togglefloating"))

hl.bind("SUPER + Left", hl.dsp.exec_cmd("hyprctl dispatch movefocus l"))
hl.bind("SUPER + Right", hl.dsp.exec_cmd("hyprctl dispatch movefocus r"))
hl.bind("SUPER + Up", hl.dsp.exec_cmd("hyprctl dispatch movefocus u"))
hl.bind("SUPER + Down", hl.dsp.exec_cmd("hyprctl dispatch movefocus d"))

hl.bind("SUPER + SHIFT + Left", hl.dsp.exec_cmd("hyprctl dispatch movewindow l"))
hl.bind("SUPER + SHIFT + Right", hl.dsp.exec_cmd("hyprctl dispatch movewindow r"))
hl.bind("SUPER + SHIFT + Up", hl.dsp.exec_cmd("hyprctl dispatch movewindow u"))
hl.bind("SUPER + SHIFT + Down", hl.dsp.exec_cmd("hyprctl dispatch movewindow d"))

for i = 1, 10 do
  local ws = (i == 10) and 0 or i
  hl.bind("SUPER + " .. ws, hl.dsp.exec_cmd("hyprctl dispatch workspace " .. ws))
  hl.bind("SUPER + SHIFT + " .. ws, hl.dsp.exec_cmd("hyprctl dispatch movetoworkspace " .. ws))
  hl.bind("SUPER + ALT + " .. ws, hl.dsp.exec_cmd("hyprctl dispatch movetoworkspace silent " .. ws .. "; hyprctl dispatch workspace " .. ws))
end

hl.bind("SUPER + SHIFT + Q", hl.dsp.exec_cmd("hyprctl dispatch exit"))
hl.bind("SUPER + SHIFT + R", hl.dsp.exec_cmd("hyprctl dispatch reload"))
