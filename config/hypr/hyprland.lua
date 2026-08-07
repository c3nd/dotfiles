-- Cassiopeia Hyprland Lua extension
-- Loaded by hyprland.conf via source = ...
-- No dots-hyprland framework dependency

local home = os.getenv("HOME") or ""

-- === DMS integration ===
if home ~= "" then
  local dms_dir = home .. "/.config/hypr/dms"
  if is_file_exists(dms_dir .. "/colors.lua") then
    require("dms.colors")
  end
  if is_file_exists(dms_dir .. "/layout.lua") then
    require("dms.layout")
  end
  if is_file_exists(dms_dir .. "/outputs.lua") then
    require("dms.outputs")
  end

  -- === Custom configs ===
  local custom_dir = home .. "/.config/hypr/custom"
  if is_file_exists(custom_dir .. "/execs.lua") then
    require("custom.execs")
  end
  if is_file_exists(custom_dir .. "/keybinds.lua") then
    require("custom.keybinds")
  end
  if is_file_exists(custom_dir .. "/variables.lua") then
    require("custom.variables")
  end

  -- === Monitor config ===
  if is_file_exists(home .. "/.config/hypr/monitors.lua") then
    require("monitors")
  end
  if is_file_exists(home .. "/.config/hypr/workspaces.lua") then
    require("workspaces")
  end
end
