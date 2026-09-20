for _, rule in ipairs({
  { match = { class = "(jetbrains-studio|jetbrains-rustrover|scrcpy)" }, opaque = true },
  { match = { class = "(firefox)" }, opacity = 1, rounding = 3 },
  { match = { class = "^(vesktop)$" }, workspace = "3 silent" },
  { match = { class = "^(com.github.neithern.g4music|org.qbittorrent.qBittorrent)$" }, float = true },
  { match = { class = "^(it.mijorus.smile)" }, float = true },
  { match = { class = "^(xdg-desktop-portal-gtk)$" }, float = true },
  -- Waybar sizes the mixer itself through popup.sh; this only catches launches from rofi.
  { match = { class = "^(org\\.pulseaudio\\.pavucontrol)$" }, float = true, center = true },
  { match = { class = "(pinentry-)" }, stay_focused = true },
  { match = { class = "^(.*jetbrains.*)$", title = "^(win.*)$" }, no_initial_focus = true },
  { match = { class = "^(.*jetbrains.*)$", title = "^$", float = true }, stay_focused = true },
  { match = { class = "^(.*jetbrains.*)$", title = "^\\s$" }, no_initial_focus = true },
  { match = { class = "^(jetbrains-*)", float = false }, tile = true },
  {
    match = { title = "(Picture-in-Picture)" },
    float = true,
    size = "585 330",
    move = "(monitor_w-816) 50",
    pin = true,
    no_dim = true,
    opacity = "1 0.8",
    no_initial_focus = true,
  },
  { match = { title = "(Picture-in-Picture)", float = false }, opacity = 1 },
}) do
  hl.window_rule(rule)
end

-- ignore_alpha is a floor: pixels below it are skipped, and order breaks the z-tie on the overlay layer.
for _, rule in ipairs({
  { match = { namespace = "waybar" }, blur = true },
  { match = { namespace = "logout_dialog" }, blur = true },
  { match = { namespace = "rofi" }, blur = true, ignore_alpha = 0 },
  { match = { namespace = "swaync-control-center" }, blur = true, ignore_alpha = 0.05, order = 3 },
  { match = { namespace = "swaync-notification-window" }, blur = true, ignore_alpha = 0.05, order = 2 },
}) do
  hl.layer_rule(rule)
end

hl.workspace_rule({ workspace = "special:overveiw", gaps_out = 80 })
hl.workspace_rule({ workspace = "special:running", gaps_out = 80 })
