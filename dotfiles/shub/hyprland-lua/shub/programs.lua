local host = require("host")

local home = os.getenv("HOME")
local override = host.programs or {}

local browser = override.browser or "zen-beta"

return {
  terminal = override.terminal or "ghostty",
  terminal2 = override.terminal2 or "ghostty",
  editor = override.editor or "ghostty -e nvim",
  browser = browser,
  file_manager = override.file_manager or "thunar",
  menu = override.menu or ("rofi -config " .. home .. "/.config/rofi/apps.rasi"),
  tasks_mode = home .. "/.config/rofi/tasks.sh",
  local_music = override.local_music or "spotify",
  emoji_picker = override.emoji_picker or "smile",
  video_player = override.video_player or "mpv",

  youtube = browser .. " --new-window https://youtube.com",
  chatgpt = browser .. " --new-window https://chat.openai.com/",
  gemini = browser .. " --new-window https://aistudio.google.com/",

  home = home,
  config_dir = home .. "/.config/hypr",
  scripts = home .. "/.config/hypr/scripts",
}
