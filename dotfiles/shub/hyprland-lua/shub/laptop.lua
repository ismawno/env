-- Laptop profile: inactive windows stay opaque, so blur only costs the bar and the menus; the lid drives the panel.
local lid = require("host").lid

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
  local spec = {}
  for key, value in pairs(panel) do
    spec[key] = value
  end
  spec.disabled = false
  hl.monitor(spec)
  dpms("on")
end

-- A start or a reload brings the panel back whatever the lid is doing; the ACPI file is the one that knows.
local function sync()
  local state = io.open(lid.state)
  if not state then return end
  local closed = state:read("*a"):match("closed") ~= nil
  state:close()
  if closed then close() end
end

hl.on("hyprland.start", sync)
hl.on("config.reloaded", sync)
hl.bind("switch:on:" .. lid.switch, close, { locked = true })
hl.bind("switch:off:" .. lid.switch, open, { locked = true })

return { inactive_opacity = 1.0 }
