-- Laptop profile: inactive windows stay readable, no blur on the integrated GPU, and the lid drives the panel.
local host = require("host")
local lid = host.lid

return {
  inactive_opacity = 1.0,
  blur = false,
  autostart = { lid.script .. " sync" },
  binds = function(locked)
    hl.bind("switch:on:" .. lid.switch, hl.dsp.exec_cmd(lid.script .. " close"), locked)
    hl.bind("switch:off:" .. lid.switch, hl.dsp.exec_cmd(lid.script .. " open"), locked)
  end,
}
