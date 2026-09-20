local host = require("host")
local profile = require("shub." .. host.kind)

for _, monitor in ipairs(host.monitors) do
  hl.monitor(monitor)
end

hl.config({
  input = {
    kb_layout = "us",
    kb_options = "caps:swapescape",
    follow_mouse = 1,
    sensitivity = 0,
  },

  general = {
    gaps_in = 0,
    gaps_out = 0,
    gaps_workspaces = 50,
    border_size = 2,
    layout = "dwindle",
    allow_tearing = false,
    -- The explicit angle stops a lone colour from being read as one end of a gradient.
    col = {
      active_border = { colors = { "rgb(EBDBB2)" }, angle = 0 },
      inactive_border = "rgb(A4997F)",
    },
  },

  decoration = {
    active_opacity = 1,
    inactive_opacity = profile.inactive_opacity,
    rounding = 0,
    blur = {
      enabled = profile.blur,
      size = 5,
      passes = 3,
      new_optimizations = true,
      ignore_opacity = true,
      xray = false,
    },
  },

  animations = { enabled = true },
  dwindle = { preserve_split = true },
  misc = { force_default_wallpaper = 0 },
  xwayland = { force_zero_scaling = true },
})

for _, curve in ipairs({
  { "linear", 0, 0, 1, 1 },
  { "md3_standard", 0.2, 0, 0, 1 },
  { "md3_decel", 0.05, 0.7, 0.1, 1 },
  { "md3_accel", 0.3, 0, 0.8, 0.15 },
  { "overshot", 0.05, 0.9, 0.1, 1.1 },
  { "crazyshot", 0.1, 1.5, 0.76, 0.92 },
  { "hyprnostretch", 0.05, 0.9, 0.1, 1.0 },
  { "menu_decel", 0.1, 1, 0, 1 },
  { "menu_accel", 0.38, 0.04, 1, 0.07 },
  { "easeInOutCirc", 0.85, 0, 0.15, 1 },
  { "easeOutCirc", 0, 0.55, 0.45, 1 },
  { "easeOutExpo", 0.16, 1, 0.3, 1 },
  { "softAcDecel", 0.26, 0.26, 0.15, 1 },
  { "md2", 0.4, 0, 0.2, 1 },
}) do
  hl.curve(curve[1], { type = "bezier", points = { { curve[2], curve[3] }, { curve[4], curve[5] } } })
end

for _, animation in ipairs({
  { "windows", 5, "overshot", "popin 80%" },
  { "windowsIn", 5, "overshot", "popin 80%" },
  { "windowsOut", 5, "md3_accel", "popin 80%" },
  { "border", 10, "default" },
  { "fade", 3, "md3_decel" },
  { "workspaces", 4, "md3_decel", "slide" },
  { "specialWorkspace", 3, "md3_decel", "slidevert" },
}) do
  hl.animation({
    leaf = animation[1],
    enabled = true,
    speed = animation[2],
    bezier = animation[3],
    style = animation[4],
  })
end
