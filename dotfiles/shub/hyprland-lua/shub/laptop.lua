-- Laptop profile: inactive windows stay readable, no blur on the integrated GPU, and the lid drives the panel.
local host = require("host")
local lid = host.lid
local programs = require("shub.programs")

local panel
for _, monitor in ipairs(host.monitors) do
  if monitor.output == lid.output then
    panel = monitor
  end
end
assert(panel, "host.lid.output names no monitor in host.monitors")

local function dpms(action)
  hl.dispatch(hl.dsp.dpms({ action = action, monitor = panel.output }))
end

-- The bar and the wallpaper keep their old position when a monitor leaves or rejoins the layout, so start them again.
local function redraw()
  hl.exec_cmd("sleep 1; pkill hyprpaper; hyprpaper -c " .. programs.config_dir .. "/hyprpaper/hyprpaper.conf")
  hl.exec_cmd("sleep 1; " .. programs.scripts .. "/waybarRestart.sh quiet")
end

-- Hyprland wants one live monitor, so the panel only leaves the layout while another display is there.
local function close()
  if #hl.get_monitors() > 1 then
    hl.monitor({ output = panel.output, disabled = true })
    redraw()
  else
    dpms("off")
  end
end

local function open()
  hl.monitor({
    output = panel.output,
    mode = panel.mode,
    position = panel.position,
    scale = panel.scale,
    disabled = false,
  })
  dpms("on")
  if #hl.get_monitors() > 1 then
    redraw()
  end
end

-- A start or a reload brings the panel back whatever the lid is doing; the ACPI file is the one that knows.
local function sync()
  local state = io.open(lid.state)
  if not state then
    return
  end
  local closed = state:read("*a"):match("closed") ~= nil
  state:close()
  if closed then
    close()
  end
end

hl.on("hyprland.start", sync)
hl.on("config.reloaded", sync)

return {
  inactive_opacity = 1.0,
  blur = false,
  autostart = {},
  binds = function(locked)
    hl.bind("switch:on:" .. lid.switch, close, locked)
    hl.bind("switch:off:" .. lid.switch, open, locked)
  end,
}
