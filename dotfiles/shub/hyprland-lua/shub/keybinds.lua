local host = require("host")
local profile = require("shub." .. host.kind)
local programs = require("shub.programs")

local dsp = hl.dsp
local win = hl.dsp.window

local mod = "SUPER"

local locked = { locked = true }
local repeating = { repeating = true }
local held = { locked = true, repeating = true }
local mouse = { mouse = true }

local centred = { float = true, center = true }
local half = { silent = true, float = true, size = "(monitor_w*0.5) (monitor_h*0.5)", center = true }
local mid = { float = true, size = "(monitor_w*0.6) (monitor_h*0.6)", center = true }

hl.bind(mod .. " + ALT + W", dsp.exec_cmd(programs.scripts .. "/waybarRestart.sh"))
hl.bind(mod .. " + SHIFT + W", dsp.exec_cmd(programs.scripts .. "/waybarLumi.sh"))

local shots = programs.home .. "/Pictures/Screenshots"
hl.bind("code:107", dsp.exec_cmd("mkdir -p " .. shots .. " && hyprshot -o " .. shots .. " -m region"), locked)
hl.bind("SHIFT + code:107", dsp.exec_cmd("mkdir -p " .. shots .. " && hyprshot -o " .. shots .. " -m output -z"), locked)

hl.bind(mod .. " + Q", dsp.exec_cmd(programs.terminal))
hl.bind(mod .. " + SHIFT + Q", dsp.exec_cmd(programs.terminal2))
hl.bind(mod .. " + ALT + Q", dsp.exec_cmd(programs.terminal, half))
hl.bind(mod .. " + E", dsp.exec_cmd(programs.editor))
hl.bind(mod .. " + W", dsp.exec_cmd(programs.file_manager))
hl.bind(mod .. " + Z", dsp.exec_cmd(programs.browser))
hl.bind(mod .. " + SHIFT + Z", dsp.exec_cmd(programs.browser .. " --private-window"))
hl.bind(mod .. " + Y", dsp.exec_cmd(programs.youtube))
hl.bind(mod .. " + G", dsp.exec_cmd(programs.browser .. " --new-window https://github.com/"))
hl.bind(mod .. " + ALT + T", dsp.exec_cmd(programs.gemini))
hl.bind(mod .. " + D", dsp.exec_cmd(programs.emoji_picker))
hl.bind(mod .. " + P", dsp.exec_cmd(programs.video_player))
hl.bind(mod .. " + A", dsp.exec_cmd(programs.local_music))
hl.bind(mod .. " + SHIFT + A", dsp.exec_cmd(programs.scripts .. "/lofi.sh"))
hl.bind(mod .. " + CTRL + A", dsp.exec_cmd(programs.terminal .. " -e cava", half))
hl.bind(mod .. " + M", dsp.exec_cmd(programs.terminal .. " -e nmtui", mid))
hl.bind(mod .. " + O", dsp.exec_cmd(programs.scripts .. "/scrcpy.sh", centred))
hl.bind(mod .. " + B", dsp.exec_cmd(programs.scripts .. "/hyprsunset.sh"))
hl.bind(mod .. " + H", dsp.exec_cmd("hyprpicker -a"))
hl.bind(mod .. " + J", dsp.exec_cmd("pkill java"))
hl.bind(mod .. " + I", dsp.exec_cmd("playerctl play-pause"))
hl.bind(mod .. " + V", dsp.exec_cmd("copyq toggle"))
hl.bind(mod .. " + X", dsp.exec_cmd("sleep 0.1 && swaync-client -t -sw"))
hl.bind(mod .. " + SPACE", dsp.exec_cmd(programs.menu .. " -show drun"))
hl.bind(mod .. " + N", dsp.exec_cmd("hyprpaper -c " .. programs.config_dir .. "/hyprpaper/hyprpaper.conf"))

-- pkill succeeding means the menu was dismissed, so only launch when nothing was killed.
hl.bind(
  mod .. " + L",
  dsp.exec_cmd(
    "pkill -x wlogout || wlogout -l "
      .. programs.home
      .. "/.config/wlogout/layout --css "
      .. programs.home
      .. "/.config/wlogout/style.css"
  )
)

hl.bind(mod .. " + F", win.fullscreen({ mode = "fullscreen" }))
hl.bind(mod .. " + T", win.float())
hl.bind(mod .. " + C", win.close())
hl.bind(mod .. " + ALT + C", win.center())
hl.bind(mod .. " + SHIFT + V", win.pin())
hl.bind(mod .. " + R", dsp.layout("togglesplit"))

-- Close every window of the focused window's process, so the app quits itself and can save its session.
hl.bind(mod .. " + SHIFT + C", function()
  local active = hl.get_active_window()
  if not active then
    return
  end
  local addresses = {}
  for _, window in ipairs(hl.get_windows()) do
    if window.pid == active.pid then
      addresses[#addresses + 1] = window.address
    end
  end
  for _, address in ipairs(addresses) do
    hl.dispatch(win.close({ window = "address:" .. address }))
  end
end)

-- Caps Lock and Escape trade places by default; this puts them back for as long as you want.
hl.bind(mod .. " + SHIFT + SPACE", function()
  local swapped = hl.get_config("input.kb_options") == "caps:swapescape"
  hl.config({ input = { kb_options = swapped and "" or "caps:swapescape" } })
end)

-- One combo, two dispatchers: cycle to the next window and raise it if it floats.
hl.bind("ALT + TAB", function()
  hl.dispatch(win.cycle_next())
  hl.dispatch(win.bring_to_top())
end)

hl.bind(mod .. " + F3", dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+"), held)
hl.bind(mod .. " + F2", dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"), held)
hl.bind(mod .. " + F4", dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), locked)

-- A number key means "go there": hide whatever scratchpad is open first, then switch.
local function switch_to(index)
  return function()
    local special = hl.get_active_special_workspace()
    if special then
      hl.dispatch(dsp.workspace.toggle_special((special.name:gsub("^special:", ""))))
    end
    hl.dispatch(dsp.focus({ workspace = index }))
  end
end

for index = 1, 10 do
  local key = index % 10
  hl.bind(mod .. " + " .. key, switch_to(index))
  hl.bind(mod .. " + SHIFT + " .. key, win.move({ workspace = index }))
end

for _, scratchpad in ipairs({ { "code:49", "overveiw" }, { "code:67", "running" } }) do
  hl.bind(mod .. " + " .. scratchpad[1], dsp.workspace.toggle_special(scratchpad[2]))
  hl.bind(mod .. " + SHIFT + " .. scratchpad[1], win.move({ workspace = "special:" .. scratchpad[2] }))
end

hl.bind(mod .. " + mouse_down", dsp.focus({ workspace = "e+1" }))
hl.bind(mod .. " + mouse_up", dsp.focus({ workspace = "e-1" }))

hl.bind(mod .. " + mouse:272", win.drag(), mouse)
hl.bind(mod .. " + mouse:273", win.resize(), mouse)

for _, arrow in ipairs({
  { "left", -20, 0 },
  { "right", 40, 0 },
  { "up", 0, -20 },
  { "down", 0, 40 },
}) do
  hl.bind(mod .. " + " .. arrow[1], win.resize({ x = arrow[2], y = arrow[3], relative = true }), repeating)
  hl.bind(mod .. " + SHIFT + " .. arrow[1], win.move({ direction = arrow[1] }))
end

profile.binds(locked)
