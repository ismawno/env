local host = require("host")
local profile = require("shub." .. host.kind)
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
  { "HYPRCURSOR_THEME", "Bibata-Modern-Ice" },
  { "HYPRCURSOR_SIZE", "24" },
  { "XCURSOR_THEME", "Bibata-Modern-Ice" },
  { "XCURSOR_SIZE", "24" },
}) do
  hl.env(variable[1], variable[2])
end

-- swaync is missing on purpose: its D-Bus unit starts it, and a second copy makes that unit fail.
local autostart = {
  "copyq --start-server",
  "hyprpaper -c " .. programs.config_dir .. "/hyprpaper/hyprpaper.conf",
  "waybar -c " .. programs.home .. "/.config/waybar/config -s " .. programs.home .. "/.config/waybar/style.css",
  host.polkit_agent or "/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1",
  "/usr/libexec/xdg-desktop-portal-hyprland",
  "/usr/libexec/xdg-desktop-portal",
}

for _, command in ipairs(profile.autostart) do
  autostart[#autostart + 1] = command
end

hl.on("hyprland.start", function()
  for _, command in ipairs(autostart) do
    hl.exec_cmd(command)
  end
end)
