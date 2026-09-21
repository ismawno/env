local host = require("host")
local programs = require("shub.programs")

for _, variable in ipairs({
  { "CLUTTER_BACKEND", "wayland" },
  { "GDK_BACKEND", "wayland,x11" },
  { "QT_AUTO_SCREEN_SCALE_FACTOR", "1" },
  { "QT_QPA_PLATFORMTHEME", "qt6ct" },
  { "QT_SCALE_FACTOR", "1" },
  { "QT_WAYLAND_DISABLE_WINDOWDECORATION", "1" },
  { "XDG_CURRENT_DESKTOP", "Hyprland" },
  { "XDG_SESSION_DESKTOP", "Hyprland" },
  { "XDG_SESSION_TYPE", "wayland" },
  { "MOZ_ENABLE_WAYLAND", "1" },
  { "NIXOS_OZONE_WL", "1" },
  { "HYPRCURSOR_THEME", "Bibata-Modern-Ice" },
  { "HYPRCURSOR_SIZE", "24" },
  { "XCURSOR_THEME", "Bibata-Modern-Ice" },
  { "XCURSOR_SIZE", "24" },
}) do
  hl.env(variable[1], variable[2])
end
for name, value in pairs(host.env or {}) do
  hl.env(name, value)
end

-- swaync is missing on purpose: its D-Bus unit starts it, and a second copy makes that unit fail.
hl.on("hyprland.start", function()
  for _, command in ipairs({
    "copyq --start-server",
    programs.wallpaper,
    "waybar -c " .. programs.home .. "/.config/waybar/config -s " .. programs.home .. "/.config/waybar/style.css",
    host.polkit_agent or "/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1",
  }) do
    hl.exec_cmd(command)
  end
end)
