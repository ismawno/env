-- The one screen list. host.monitors_file means a pure-data monitors.lua sits next to host.lua and replaces host.monitors.
local host = require("host")

local list = {}
for _, monitor in ipairs(host.monitors_file and require("monitors") or host.monitors or {}) do
  list[#list + 1] = monitor
end

local panel
for _, monitor in ipairs(list) do
  if host.lid and monitor.output == host.lid.output then
    panel = monitor
  end
end

-- An unknown screen goes right of the panel: "auto" strands waybar and hyprpaper at the old origin when the panel leaves the layout.
if panel and host.catchall then
  local width = tonumber(panel.mode:match("^(%d+)x"))
  local x, y = panel.position:match("^(-?%d+)x(-?%d+)$")
  assert(width and x, "the panel entry needs a WxH@R mode and an XxY position")
  local logical = math.floor(width / (tonumber(panel.scale) or 1) + 0.5)
  list[#list + 1] = {
    output = "",
    mode = host.catchall.mode,
    position = (tonumber(x) + logical) .. "x" .. y,
    scale = host.catchall.scale,
  }
end

return { list = list, panel = panel }
