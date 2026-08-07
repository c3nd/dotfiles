-- Cassiopeia Hyprland Lua extension
-- Loaded by hyprland.conf via source = ...
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
