-- Laptop profile: inactive windows stay readable, no blur on the integrated GPU, and the lid drives the panel.
local host = require("host")
local lid = host.lid

local panel = require("shub.monitors").panel
assert(panel, "host.lid.output names no monitor in the screen list")

local function dpms(action)
  hl.dispatch(hl.dsp.dpms({ action = action, monitor = panel.output }))
end

-- Hyprland wants one live monitor, so the panel only leaves the layout while another display is there.
local function close()
  if #hl.get_monitors() > 1 then
    hl.monitor({ output = panel.output, disabled = true })
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
