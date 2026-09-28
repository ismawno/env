# Build-time only: turns one Ghostty theme and its GTK theme, native or generated here from adw-gtk3, into the files every app reads through look-pick's state; themes.sh calls it once per theme.
set -euo pipefail

lookName=$1 slug=$2 gtkName=$3 gtkDir=$4 roles=$5
ghosttyTheme=$ghosttyThemes/$lookName

die() {
  printf 'theme-bundle: %s: %s\n' "$lookName" "$1" >&2
  exit 1
}

mkdir -p "$bundles/$slug/settings"
cd "$bundles/$slug"

# A theme themes.nix does not name is only left out, with the reason themes.sh logs; a named one that falls short fails the build.
reject() {
  [ -z "$gtkName" ] || die "$1"
  printf '%s\n' "$1" >rejected
  exit 0
}

[ -f "$ghosttyTheme" ] || die "Ghostty ships no theme called $lookName"
if [ -n "$gtkDir" ]; then
  for sheet in gtk-3.0/gtk.css gtk-4.0/gtk.css; do
    [ -f "$gtkDir/$sheet" ] || die "the GTK theme $gtkName has no $sheet"
  done
fi

declare -A color=()
while IFS= read -r line || [ -n "$line" ]; do
  if [[ $line =~ ^palette\ *=\ *([0-9]+)\ *=\ *#?([0-9A-Fa-f]{6})\ *$ ]]; then
    color[p${BASH_REMATCH[1]}]=#${BASH_REMATCH[2],,}
  elif [[ $line =~ ^(background|foreground)\ *=\ *#?([0-9A-Fa-f]{6})\ *$ ]]; then
    color[${BASH_REMATCH[1]}]=#${BASH_REMATCH[2],,}
  fi
done <"$ghosttyTheme"
for key in background foreground p{0..15}; do
  [ -n "${color[$key]:-}" ] || reject "the Ghostty theme sets no $key"
done

channels() {
  local hex=${1#\#}
  printf '%d %d %d' "$((16#${hex:0:2}))" "$((16#${hex:2:2}))" "$((16#${hex:4:2}))"
}

# mix A B P: P percent of B into A.
mix() {
  local -a a b
  read -ra a <<<"$(channels "$1")"
  read -ra b <<<"$(channels "$2")"
  printf '#%02x%02x%02x' \
    "$(((a[0] * (100 - $3) + b[0] * $3 + 50) / 100))" \
    "$(((a[1] * (100 - $3) + b[1] * $3 + 50) / 100))" \
    "$(((a[2] * (100 - $3) + b[2] * $3 + 50) / 100))"
}

triple() {
  local -a a
  read -ra a <<<"$(channels "$1")"
  printf '%d, %d, %d' "${a[@]}"
}

rgba() {
  printf 'rgba(%s, %s)' "$(triple "$1")" "$2"
}

# WCAG 2 contrast ratio of two colours, times 100.
contrast() {
  awk -v a="$1" -v b="$2" '
    function lin(hex, v) { v = strtonum("0x" hex) / 255; return v <= 0.04045 ? v / 12.92 : ((v + 0.055) / 1.055) ^ 2.4 }
    function lum(c) { return 0.2126 * lin(substr(c, 2, 2)) + 0.7152 * lin(substr(c, 4, 2)) + 0.0722 * lin(substr(c, 6, 2)) }
    BEGIN { x = lum(a); y = lum(b); if (x < y) { t = x; x = y; y = t } printf "%d\n", 100 * (x + 0.05) / (y + 0.05) }'
}

bg=${color[background]} fg=${color[foreground]}

# Text under 3:1, WCAG's floor even for large bold text, is unreadable in the bar, the menus and every GTK app alike.
ratio=$(contrast "$fg" "$bg")
[ "$ratio" -ge 300 ] || reject "its text contrast is $((ratio / 100)).$(printf '%02d' $((ratio % 100))):1, under 3:1"
for key in background foreground p{0..15}; do
  printf '%s ' "${color[$key]}"
done >palette

read -ra lum <<<"$(channels "$bg")"
if ((2126 * lum[0] + 7152 * lum[1] + 722 * lum[2] < 1280000)); then
  scheme=dark icons=$iconsDark
else
  scheme=light icons=$iconsLight
fi
[ -f "$icons/index.theme" ] || die "the icon theme ${icons##*/} is missing"

declare -A role=(
  [bg]=$bg
  [fg]=$fg
  [button]=$(mix "$bg" "$fg" 5)
  [bg1]=$(mix "$bg" "$fg" 10)
  [midlight]=$(mix "$bg" "$fg" 15)
  [bg2]=$(mix "$bg" "$fg" 20)
  [light]=$(mix "$bg" "$fg" 25)
  [bg_dark]=$(mix "$bg" "#000000" 25)
  [fg2]=$(mix "$fg" "$bg" 10)
  [dim]=$(mix "$bg" "$fg" 45)
  [subtle]=$(mix "$bg" "$fg" 60)
  [muted]=${color[p8]}
  [accent]=${color[p3]}
  [accent_dark]=$(mix "${color[p3]}" "$bg" 25)
  [warn]=${color[p11]}
  [crit]=${color[p1]}
  [crit_bright]=${color[p9]}
  [green]=${color[p2]}
  [blue]=${color[p4]}
  [blue_dark]=$(mix "${color[p4]}" "$bg" 35)
  [link]=${color[p12]}
  [visited]=${color[p13]}
  [week]=${color[p14]}
  [today]=${color[p13]}
)
role[inactive]=${role[subtle]}
role[on_crit]=$bg
[ "$scheme" = light ] || role[on_crit]=$(mix "$fg" "#ffffff" 30)
for pair in $roles; do
  key=${pair%%=*} value=${pair#*=}
  [ -n "${role[$key]:-}" ] || die "no role called $key to override"
  [[ $value =~ ^#[0-9a-f]{6}$ ]] || die "role $key wants #rrggbb, not $value"
  role[$key]=$value
done

printf 'theme = %s\n' "$lookName" >ghostty

for key in "${!role[@]}"; do
  printf '@define-color look_%s %s;\n' "$key" "${role[$key]}"
done | sort >gtk3.css

cat >swaync.css <<EOF
:root {
  --cc-bg: $(rgba "${role[bg]}" 0.86);
  --noti-bg: $(triple "${role[bg]}");
  --noti-bg-darker: ${role[bg_dark]};
  --noti-bg-hover: ${role[bg1]};
  --noti-bg-focus: $(rgba "${role[bg2]}" 0.9);
  --noti-border-color: $(rgba "${role[fg]}" 0.55);
  --noti-close-bg: $(rgba "${role[fg]}" 0.12);
  --noti-close-bg-hover: ${role[fg]};
  --text-color: ${role[fg]};
  --text-color-disabled: ${role[subtle]};
  --bg-selected: ${role[accent]};
  --border: 2px solid ${role[fg]};
  --look-bg: ${role[bg]};
  --look-fg: ${role[fg]};
  --look-scrim: $(rgba "${role[subtle]}" 0.22);
}
EOF

cat >rofi.rasi <<EOF
* {
  look-bg: ${role[bg]};
  look-window: ${role[bg]}ed;
  look-fg: ${role[fg]};
  look-subtle: ${role[subtle]};
  look-muted: ${role[muted]};
  look-dim: ${role[dim]};
  look-accent: ${role[accent]};
  look-accent-dark: ${role[accent_dark]};
  look-crit: ${role[crit]};
  look-crit-bright: ${role[crit_bright]};
  look-highlight: underline bold ${role[fg]};
}
EOF

# Pango markup in waybar's JSON, out of CSS's reach; waybar merges this into the clock module.
cat >waybar.json <<EOF
{
  "clock": {
    "calendar": {
      "format": {
        "days": "<span color='${role[fg]}'><b>{}</b></span>",
        "weeks": "<span color='${role[week]}'><b>W{}</b></span>",
        "weekdays": "<span color='${role[fg]}'><b>{}</b></span>",
        "today": "<span color='${role[today]}'><b><u>{}</u></b></span>"
      }
    }
  }
}
EOF

printf 'return { active_border = "rgb(%s)", inactive_border = "rgb(%s)" }\n' \
  "${role[fg]#\#}" "${role[inactive]#\#}" >hypr.lua
printf "hl.config({ general = { col = { active_border = { colors = { 'rgb(%s)' }, angle = 0 }, inactive_border = 'rgb(%s)' } } })\n" \
  "${role[fg]#\#}" "${role[inactive]#\#}" >hyprctl.lua

qt() {
  local name
  for name in "$@"; do
    printf '#ff%s\n' "${role[$name]#\#}"
  done | paste -sd ',' | sed 's/,/, /g'
}
# QPalette's role order: WindowText Button Light Midlight Dark Mid Text BrightText ButtonText Base Window Shadow Highlight HighlightedText Link LinkVisited AlternateBase NoRole ToolTipBase ToolTipText PlaceholderText.
normal=(fg button light midlight bg_dark button fg on_crit fg bg bg bg_dark fg2 bg link visited button bg button fg subtle)
disabled=(dim button light midlight bg_dark button dim on_crit dim bg bg bg_dark midlight muted link visited button bg button fg dim)
cat >qt6ct-colors.conf <<EOF
[ColorScheme]
active_colors=$(qt "${normal[@]}")
disabled_colors=$(qt "${disabled[@]}")
inactive_colors=$(qt "${normal[@]}")
EOF

# No native GTK theme: adw-gtk3 recoloured through its own named colours, the way it is meant to be themed; its GTK 4 sheet also gets gtk4.css below.
if [ -z "$gtkName" ]; then
  gtkName=look-$slug gtkDir=$PWD/gtk-theme
  base=$adwaita/adw-gtk3
  [ "$scheme" = light ] || base=$base-dark
  card="@headerbar_bg_color" popover="mix(@window_bg_color, @window_fg_color, 0.1)"
  [ "$scheme" = dark ] || card="@view_bg_color" popover="@view_bg_color"
  on_blue=$bg
  [ "$(contrast "$bg" "${role[blue]}")" -ge "$(contrast "$fg" "${role[blue]}")" ] || on_blue=$fg
  mkdir -p gtk-theme/gtk-3.0 gtk-theme/gtk-4.0
  cat >gtk-theme/named.css <<CSS
@define-color window_bg_color ${role[bg]};
@define-color window_fg_color ${role[fg]};
@define-color view_bg_color ${role[bg]};
@define-color view_fg_color ${role[fg]};
@define-color accent_bg_color ${role[blue]};
@define-color accent_fg_color $on_blue;
@define-color destructive_bg_color ${role[crit]};
@define-color success_bg_color ${role[green]};
@define-color warning_bg_color ${role[accent]};
@define-color error_bg_color ${role[crit]};
CSS
  {
    printf '@import url("file://%s/gtk-3.0/gtk.css");\n' "$base"
    cat gtk-theme/named.css
    cat <<CSS
@define-color headerbar_bg_color mix(@window_bg_color, @window_fg_color, 0.06);
@define-color headerbar_fg_color @window_fg_color;
@define-color headerbar_border_color @window_fg_color;
@define-color sidebar_bg_color @headerbar_bg_color;
@define-color sidebar_fg_color @window_fg_color;
@define-color sidebar_backdrop_color @window_bg_color;
@define-color card_bg_color $card;
@define-color card_fg_color @window_fg_color;
@define-color dialog_bg_color $popover;
@define-color dialog_fg_color @window_fg_color;
@define-color popover_bg_color @dialog_bg_color;
@define-color popover_fg_color @window_fg_color;
@define-color thumbnail_bg_color @dialog_bg_color;
@define-color thumbnail_fg_color @window_fg_color;
CSS
  } >gtk-theme/gtk-3.0/gtk.css
  {
    printf '@import url("file://%s/gtk-4.0/gtk.css");\n' "$base"
    cat gtk-theme/named.css
  } >gtk-theme/gtk-4.0/gtk.css
  rm gtk-theme/named.css
fi

# The GTK theme's own literal colour for the first name it defines, so libadwaita apps match the GTK apps beside them.
sheet() {
  local fallback=$1 name value
  shift
  if [ -n "$gtkDir" ]; then
    for name in "$@"; do
      value=$(sed -nE "s/^[[:space:]]*@define-color[[:space:]]+${name}[[:space:]]+(#[0-9a-fA-F]{3,8}|rgba?\([0-9., ]+\))[[:space:]]*;.*/\1/p" \
        "$gtkDir/gtk-4.0/gtk.css" | head -n 1)
      if [ -n "$value" ]; then
        printf '%s' "$value"
        return 0
      fi
    done
  fi
  printf '%s' "$fallback"
}
if [ -z "$gtkDir" ]; then
  : >gtk4.css
else
  bar="color-mix(in srgb, var(--window-bg-color) 94%, var(--window-fg-color))"
  card="var(--view-bg-color)" popover="var(--view-bg-color)"
  if [ "$scheme" = dark ]; then
    card=$bar
    popover="color-mix(in srgb, var(--window-bg-color) 90%, var(--window-fg-color))"
  fi
  cat >gtk4.css <<EOF
:root {
  --window-bg-color: $(sheet "${role[bg]}" window_bg_color theme_bg_color);
  --window-fg-color: $(sheet "${role[fg]}" window_fg_color theme_fg_color);
  --view-bg-color: $(sheet "${role[bg]}" view_bg_color theme_base_color);
  --view-fg-color: $(sheet "${role[fg]}" view_fg_color theme_text_color);
  --accent-bg-color: $(sheet "${role[blue]}" accent_bg_color theme_selected_bg_color);
  --accent-fg-color: $(sheet "${role[bg]}" accent_fg_color theme_selected_fg_color);
  --destructive-bg-color: ${role[crit]};
  --success-bg-color: ${role[green]};
  --warning-bg-color: ${role[accent]};
  --error-bg-color: ${role[crit]};
  --headerbar-bg-color: $(sheet "$bar" headerbar_bg_color);
  --headerbar-fg-color: var(--window-fg-color);
  --headerbar-border-color: var(--window-fg-color);
  --headerbar-backdrop-color: var(--window-bg-color);
  --sidebar-bg-color: $(sheet "$bar" sidebar_bg_color);
  --sidebar-fg-color: var(--window-fg-color);
  --sidebar-backdrop-color: var(--window-bg-color);
  --secondary-sidebar-bg-color: $card;
  --secondary-sidebar-fg-color: var(--window-fg-color);
  --secondary-sidebar-backdrop-color: var(--window-bg-color);
  --card-bg-color: $card;
  --card-fg-color: var(--window-fg-color);
  --dialog-bg-color: $popover;
  --dialog-fg-color: var(--window-fg-color);
  --popover-bg-color: $popover;
  --popover-fg-color: var(--window-fg-color);
  --thumbnail-bg-color: $popover;
  --thumbnail-fg-color: var(--window-fg-color);
}
EOF
fi
[ ! -d gtk-theme ] || cat gtk4.css >>gtk-theme/gtk-4.0/gtk.css

prefer_dark=false
[ "$scheme" = light ] || prefer_dark=true
for version in 3 4; do
  {
    printf '[Settings]\ngtk-theme-name=%s\ngtk-icon-theme-name=%s\ngtk-application-prefer-dark-theme=%s\n' \
      "$gtkName" "${icons##*/}" "$prefer_dark"
    [ "$version" = 3 ] || printf 'gtk-interface-color-scheme=%s\n' "$scheme"
  } >"settings/gtk$version.ini"
done
printf "[org/gnome/desktop/interface]\ngtk-theme='%s'\nicon-theme='%s'\ncolor-scheme='prefer-%s'\n" \
  "$gtkName" "${icons##*/}" "$scheme" >settings/dconf.ini
printf '[Appearance]\ncolor_scheme_path=@BUNDLE@/qt6ct-colors.conf\nicon_theme=%s\n' "${icons##*/}" >settings/qt6ct.ini
printf '%s\n' ghostty waybar swaync hyprland >pokes

stripes=()
for key in background p8 foreground p1 p2 p3 p4 p5; do
  stripes+=("xc:${color[$key]}")
done
magick -size 40x200 "${stripes[@]}" +append -strip -define png:exclude-chunks=date,time thumb.png
