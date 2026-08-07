-- Cassiopeia Hyprland Lua extension
-- Loaded by hyprland.conf via source = ...
-- No dots-hyprland framework dependency

local home = os.getenv("HOME") or ""

local function is_file_exists(path)
  local f = io.open(path, "r")
  if f then
    f:close()
    return true
  end
  return false
end

-- DMS is managed by home-manager module; do not require its configs here
-- to avoid duplicate binds / conflicting exec-once.

-- === Custom configs ===
if home ~= "" then
  local custom_dir = home .. "/.config/hypr/custom"
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
