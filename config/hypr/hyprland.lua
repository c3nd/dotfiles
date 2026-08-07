-- Cassiopeia Hyprland config
-- Official DMS Lua-based pattern
-- https://danklinux.com/docs/dankmaterialshell/compositors#hyprland-configuration

local home = os.getenv("HOME") or ""
local mod = SUPER

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

  if is_file_exists(dms_dir .. "/colors.lua") then
    require("dms.colors")
  end
  if is_file_exists(dms_dir .. "/layout.lua") then
    require("dms.layout")
  end
  if is_file_exists(dms_dir .. "/outputs.lua") then
    require("dms.outputs")
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
      active_border = "rgba(FF0000ff) rgba(00FF00ff) rgba(0000FFff)",
      inactive_border = "rgba(111111ff)"
    },
    resize_on_border = true,
    allow_tearing = false,
    layout = "dwindle"
  },
  decoration = {
    rounding = 8,
    drop_shadow = true,
    shadow_range = 4,
    shadow_render_power = 3,
    col_shadow = "0x000000"
  },
  animations = {
    enabled = true,
    bezier = { smoothOut = { 0.36, 0, 0.66, -0.56 }, smoothIn = { 0.36, 0, 0.66, -0.56 } },
    animation = { windows = { 1, 6, smoothOut, "slide" }, border = { 1, 10, "default" }, fade = { 1, 10, "default" } }
  },
  dwindle = {
    pseudotile = true,
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
hl.bind(mod .. " + space", hl.dsp.exec_cmd("dms ipc call spotlight toggle"))
hl.bind(mod .. " + V", hl.dsp.exec_cmd("dms ipc call clipboard toggle"))
hl.bind(mod .. " + M", hl.dsp.exec_cmd("dms ipc call processlist focusOrToggle"))
hl.bind(mod .. " + comma", hl.dsp.exec_cmd("dms ipc call settings focusOrToggle"))
hl.bind(mod .. " + N", hl.dsp.exec_cmd("dms ipc call notifications toggle"))
hl.bind(mod .. " + Y", hl.dsp.exec_cmd("dms ipc call dankdash wallpaper"))
hl.bind(mod .. " + TAB", hl.dsp.exec_cmd("dms ipc call hypr toggleOverview"))

hl.bind(mod .. " + ALT + L", hl.dsp.exec_cmd("dms ipc call lock lock"))

hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("dms ipc call audio increment 2", { locked = true, repeating = true }))
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("dms ipc call audio decrement 2", { locked = true, repeating = true }))
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("dms ipc call audio mute", { locked = true }))

hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("dms ipc call brightness increment 10", { locked = true, repeating = true }))
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("dms ipc call brightness decrement 10", { locked = true, repeating = true }))

-- === Custom keybinds ===
hl.bind(mod .. " + Return", hl.dsp.exec_cmd("kitty"))
hl.bind(mod .. " + E", hl.dsp.exec_cmd("kitty --class file-manager -e ranger || thunar || pcmanfm"))
hl.bind(mod .. " + W", hl.dsp.exec_cmd("brave || zen-browser || firefox"))
hl.bind(mod .. " + C", hl.dsp.exec_cmd("lapce"))
hl.bind(mod .. " + X", hl.dsp.exec_cmd("kitty --class scratchpad"))
hl.bind(mod .. " + SHIFT + V", hl.dsp.exec_cmd("pavucontrol || paman"))
hl.bind(mod .. " + B", hl.dsp.exec_cmd("brave"))

hl.bind(mod .. " + Q", "closewindow")
hl.bind(mod .. " + D", "fullscreen, 1")
hl.bind(mod .. " + F", "fullscreen, 0")
hl.bind(mod .. " + ALT + space", "togglefloating")

hl.bind(mod .. " + Left", "movefocus, l")
hl.bind(mod .. " + Right", "movefocus, r")
hl.bind(mod .. " + Up", "movefocus, u")
hl.bind(mod .. " + Down", "movefocus, d")

hl.bind(mod .. " + SHIFT + Left", "movewindow, l")
hl.bind(mod .. " + SHIFT + Right", "movewindow, r")
hl.bind(mod .. " + SHIFT + Up", "movewindow, u")
hl.bind(mod .. " + SHIFT + Down", "movewindow, d")

for i = 1, 10 do
  local ws = (i == 10) and 0 or i
  hl.bind(mod .. " + " .. ws, "workspace, " .. ws)
  hl.bind(mod .. " + SHIFT + " .. ws, "movetoworkspace, " .. ws)
  hl.bind(mod .. " + ALT + " .. ws, "movetoworkspace, silent, " .. ws .. "; workspace, " .. ws)
end

hl.bind(mod .. " + SHIFT + Q", "exit")
hl.bind(mod .. " + SHIFT + R", "reload")
