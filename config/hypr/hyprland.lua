-- Cassiopeia Hyprland config
-- Self-contained plain Hyprland config
-- No dots-hyprland framework dependency

-- === DMS integration ===
if is_file_exists(HOME .. "/.config/hypr/dms/colors.lua") then
    require("dms.colors")
end
if is_file_exists(HOME .. "/.config/hypr/dms/layout.lua") then
    require("dms.layout")
end
if is_file_exists(HOME .. "/.config/hypr/dms/outputs.lua") then
    require("dms.outputs")
end

-- === Custom configs ===
if is_file_exists(HOME .. "/.config/hypr/custom/execs.lua") then
    require("custom.execs")
end
if is_file_exists(HOME .. "/.config/hypr/custom/keybinds.lua") then
    require("custom.keybinds")
end
if is_file_exists(HOME .. "/.config/hypr/custom/variables.lua") then
    require("custom.variables")
end

-- === Monitor config ===
if is_file_exists(HOME .. "/.config/hypr/monitors.lua") then
    require("monitors")
end
if is_file_exists(HOME .. "/.config/hypr/workspaces.lua") then
    require("workspaces")
end

-- === Basic Hyprland settings ===
general {
    gaps_in = 4
    gaps_out = 8
    border_size = 1
    col.active_border = "rgb(FF0000) rgb(00FF00) rgb(0000FF)"
    col.inactive_border = "rgb(111111)"
    resize_on_border = true
    allow_tearing = false
    layout = "dwindle"
}

decoration {
    rounding = 8
    drop_shadow = true
    shadow_range = 4
    shadow_render_power = 3
    col.shadow = "0x000000"
}

animations {
    enabled = true
    bezier = "smoothOut, 0.36, 0, 0.66, -0.56"
    bezier = "smoothIn, 0.36, 0, 0.66, -0.56"
    animation = "windows, 1, 6, smoothOut, slide"
    animation = "border, 1, 10, default"
    animation = "fade, 1, 10, default"
}

dwindle {
    pseudotile = true
    preserve_split = true
}

master {
    new_status = "master"
}

misc {
    force_default_wallpaper = 0
    disable_hyprland_logo = true
    disable_splash_rendering = true
    vrr = 1
    animate_manual_resizes = true
}
