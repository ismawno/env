local home = os.getenv("HOME")

return {
  home = home,
  scripts = home .. "/.config/hypr/scripts",
  wallpaper = "hyprpaper -c " .. home .. "/.config/hypr/hyprpaper/hyprpaper.conf",
}
