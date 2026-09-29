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
  elif [[ $line =~ ^(background|foreground|selection-background|selection-foreground)\ *=\ *#?([0-9A-Fa-f]{6})\ *$ ]]; then
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

# Colour maths on #rrggbb, as colours MODE ARG...: WCAG 2 contrast, mixes, and HSL lightness moved only as far as 4.5:1 needs, or 3:1 where a mid-tone base under a tint caps every shade.
colours() {
  awk -v mode="$1" -v args="${*:2}" '
    function ch(c, i) { return strtonum("0x" substr(c, 2 * i + 2, 2)) / 255 }
    function lin(v) { return v <= 0.04045 ? v / 12.92 : ((v + 0.055) / 1.055) ^ 2.4 }
    function lum(c) { return 0.2126 * lin(ch(c, 0)) + 0.7152 * lin(ch(c, 1)) + 0.0722 * lin(ch(c, 2)) }
    function cr(a, b, x, y) { x = lum(a); y = lum(b); return x > y ? (x + 0.05) / (y + 0.05) : (y + 0.05) / (x + 0.05) }
    function hex(r, g, b) { return sprintf("#%02x%02x%02x", r * 255 + 0.5, g * 255 + 0.5, b * 255 + 0.5) }
    function mix(a, b, f) { return hex(ch(a, 0) + (ch(b, 0) - ch(a, 0)) * f, ch(a, 1) + (ch(b, 1) - ch(a, 1)) * f, ch(a, 2) + (ch(b, 2) - ch(a, 2)) * f) }
    function hue(p, q, t) { t = t < 0 ? t + 1 : t > 1 ? t - 1 : t; return t < 1 / 6 ? p + (q - p) * 6 * t : t < 1 / 2 ? q : t < 2 / 3 ? p + (q - p) * (2 / 3 - t) * 6 : p }
    function shade(c, d, r, g, b, hi, lo, h, s, l, q) {
      r = ch(c, 0); g = ch(c, 1); b = ch(c, 2)
      hi = r > g ? (r > b ? r : b) : (g > b ? g : b); lo = r < g ? (r < b ? r : b) : (g < b ? g : b)
      l = (hi + lo) / 2; h = s = 0
      if (hi > lo) {
        s = l > 0.5 ? (hi - lo) / (2 - hi - lo) : (hi - lo) / (hi + lo)
        h = (hi == r ? (g - b) / (hi - lo) + (g < b ? 6 : 0) : hi == g ? (b - r) / (hi - lo) + 2 : (r - g) / (hi - lo) + 4) / 6
      }
      l = l + d < 0 ? 0 : l + d > 1 ? 1 : l + d
      q = l < 0.5 ? l * (1 + s) : l + s - l * s
      return hex(hue(2 * l - q, q, h + 1 / 3), hue(2 * l - q, q, h), hue(2 * l - q, q, h - 1 / 3))
    }
    function onfill(f, t, lift, x, y) { x = cr(t, f); y = cr(t, mix(f, "#ffffff", lift)); return x < y ? x : y }
    function fill(f, dark, lift, i, c) {
      if (onfill(f, "#ffffff", lift) >= onfill(f, dark, lift) && onfill(f, "#ffffff", lift) >= 4.5) return f " #ffffff"
      if (onfill(f, dark, lift) >= 4.5) return f " " dark
      for (i = 1; i <= 200; i++) {
        c = shade(f, -i / 200); if (onfill(c, "#ffffff", lift) >= 4.5) return c " #ffffff"
        c = shade(f, i / 200); if (onfill(c, dark, lift) >= 4.5) return c " " dark
      }
    }
    function infobar(x, bg, fg, dark, tint, i, c) {
      tint = mix(bg, x, 0.3)
      for (i = 0; i <= 200; i++) {
        c = i ? shade(tint, -i / 200) : tint
        if (cr(fg, c) >= 4.5) return c " " fg
        if (cr("#ffffff", c) >= 4.5) return c " #ffffff"
        c = shade(tint, i / 200)
        if (cr(dark, c) >= 4.5) return c " " dark
      }
    }
    function apart(c, i, x, v) { x = 99; for (i = 3; i <= n; i++) { v = cr(c, mix(a[i], c, a[2])); x = v < x ? v : x } return x }
    function flat(c, over, m) {
      if (c ~ /^#[0-9a-fA-F]{3}$/) c = "#" substr(c, 2, 1) substr(c, 2, 1) substr(c, 3, 1) substr(c, 3, 1) substr(c, 4, 1) substr(c, 4, 1)
      if (c ~ /^#[0-9a-fA-F]{6}/) return tolower(substr(c, 1, 7))
      if (match(c, /^rgba?\(([0-9.]+),([0-9.]+),([0-9.]+)(,([0-9.]+))?\)$/, m)) return mix(over, hex(m[1] / 255, m[2] / 255, m[3] / 255), m[5] == "" ? 1 : m[5])
      print "colours: cannot read " c > "/dev/stderr"
      exit 1
    }
    BEGIN {
      n = split(args, a, " ")
      if (mode == "contrast") printf "%d\n", 100 * cr(a[1], a[2])
      else if (mode == "mix") print mix(a[1], a[2], a[3])
      else if (mode == "darker") print (lum(a[1]) <= lum(a[2]) ? a[1] : a[2])
      else if (mode == "flat") print flat(a[1], a[2])
      else if (mode == "fill") print fill(a[1], a[2], a[3])
      else if (mode == "infobar") print infobar(a[1], a[2], a[3], a[4])
      else if (mode == "apart") {
        for (goal = 4.5; goal >= 3; goal -= 1.5) {
          for (i = 0; i <= 200; i++) {
            if (apart(c = i ? shade(a[1], i / 200) : a[1]) >= goal || apart(c = shade(a[1], -i / 200)) >= goal) { print c; exit }
          }
        }
        print a[1]
      }
    }'
}

bg=${color[background]} fg=${color[foreground]}

# Text under 3:1, WCAG's floor even for large bold text, is unreadable in the bar, the menus and every GTK app alike.
ratio=$(colours contrast "$fg" "$bg")
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

# Rofi's selected row takes the theme's own selection colours (Ghostty inverts fg and bg without them) while they read at 4.5:1, else bg on the accent moved as far as that needs; its current row whichever of bg and fg reads better on the accent.
select_bg=${color[selection-background]:-$fg} select_fg=${color[selection-foreground]:-$bg}
if [ "$(colours contrast "$select_fg" "$select_bg")" -lt 450 ]; then
  select_fg=${role[bg]} select_bg=$(colours apart "${role[accent]}" 0 "${role[bg]}")
fi

on() {
  if [ "$(colours contrast "${role[bg]}" "$1")" -ge "$(colours contrast "${role[fg]}" "$1")" ]; then
    printf '%s' "${role[bg]}"
  else
    printf '%s' "${role[fg]}"
  fi
}

cat >rofi.rasi <<EOF
* {
  look-bg: ${role[bg]};
  look-window: ${role[bg]}ed;
  look-fg: ${role[fg]};
  look-select: $select_bg;
  look-on-select: $select_fg;
  look-muted: ${role[muted]};
  look-dim: ${role[dim]};
  look-accent: ${role[accent]};
  look-on-accent: $(on "${role[accent]}");
  look-accent-dark: ${role[accent_dark]};
  look-on-accent-dark: $(on "${role[accent_dark]}");
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
flat() {
  colours flat "${1// /}" "$2"
}

# What GTK writes on or in colour: accent and status fills under white or the theme's dark end (GTK 3 lifts suggested buttons 10% toward white), status text (adw-gtk3's shade of the fill) on its own tint, 23.5% under a destructive button and 10% in an entry, infobars.
win_bg=$(flat "$(sheet "${role[bg]}" window_bg_color theme_bg_color)" "#000000")
win_fg=$(flat "$(sheet "${role[fg]}" window_fg_color theme_fg_color)" "$win_bg")
dark=$(colours darker "$win_bg" "$win_fg")
dialog=$win_bg
[ "$scheme" = light ] || dialog=$(colours mix "$win_bg" "$win_fg" 0.1)
read -r accent_bg accent_fg <<<"$(colours fill "$(flat "$(sheet "${role[blue]}" accent_bg_color theme_selected_bg_color)" "$win_bg")" "$dark" 0.1)"
kinds=(destructive success warning error)
declare -A status=([destructive]=crit [success]=green [warning]=accent [error]=crit) alpha=([destructive]=0.235 [success]=0.1 [warning]=0.1 [error]=0.1) fill=() on_fill=() text=()
for kind in "${kinds[@]}"; do
  read -r "fill[$kind]" "on_fill[$kind]" <<<"$(colours fill "${role[${status[$kind]}]}" "$dark" 0)"
  shade=$(colours mix "${role[${status[$kind]}]}" "#ffffff" 0.4)
  [ "$scheme" = dark ] || shade=$(colours mix "${role[${status[$kind]}]}" "#000000" 0.17)
  text[$kind]=$(colours apart "$shade" "${alpha[$kind]}" "$win_bg" "$dialog")
done

# No native GTK theme: adw-gtk3 recoloured through its own named colours, the way it is meant to be themed; its GTK 4 sheet also gets gtk4.css below.
if [ -z "$gtkName" ]; then
  gtkName=look-$slug gtkDir=$PWD/gtk-theme
  base=$adwaita/adw-gtk3
  [ "$scheme" = light ] || base=$base-dark
  card="@headerbar_bg_color" popover="mix(@window_bg_color, @window_fg_color, 0.1)"
  [ "$scheme" = dark ] || card="@view_bg_color" popover="@view_bg_color"
  mkdir -p gtk-theme/gtk-3.0 gtk-theme/gtk-4.0
  {
    cat <<CSS
@define-color window_bg_color ${role[bg]};
@define-color window_fg_color ${role[fg]};
@define-color view_bg_color ${role[bg]};
@define-color view_fg_color ${role[fg]};
@define-color accent_bg_color $accent_bg;
@define-color accent_fg_color $accent_fg;
CSS
    for kind in "${kinds[@]}"; do
      printf '@define-color %s_bg_color %s;\n@define-color %s_fg_color %s;\n@define-color %s_color %s;\n' \
        "$kind" "${fill[$kind]}" "$kind" "${on_fill[$kind]}" "$kind" "${text[$kind]}"
    done
    for kind in warning error; do
      read -r tint ink <<<"$(colours infobar "${fill[$kind]}" "$win_bg" "$win_fg" "$dark")"
      printf 'infobar.%s > revealer > box {\n  background-color: %s;\n  color: %s;\n}\n' "$kind" "$tint" "$ink"
    done
  } >gtk-theme/common.css
  {
    printf '@import url("file://%s/gtk-3.0/gtk.css");\n' "$base"
    cat gtk-theme/common.css
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
button.suggested-action, button.suggested-action:hover, button.suggested-action:active, button.suggested-action:checked {
  color: @accent_fg_color;
}
label.error, entry.error, spinbutton.error:not(.vertical), headerbar entry.error, .titlebar entry.error {
  color: @error_color;
}
entry.warning, spinbutton.warning:not(.vertical), headerbar entry.warning, .titlebar entry.warning {
  color: @warning_color;
}
CSS
  } >gtk-theme/gtk-3.0/gtk.css
  {
    printf '@import url("file://%s/gtk-4.0/gtk.css");\n' "$base"
    cat gtk-theme/common.css
  } >gtk-theme/gtk-4.0/gtk.css
  rm gtk-theme/common.css
fi

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
  --accent-bg-color: $accent_bg;
  --accent-fg-color: $accent_fg;
$(for kind in "${kinds[@]}"; do
    printf '  --%s-bg-color: %s;\n  --%s-fg-color: %s;\n  --%s-color: %s;\n' \
      "$kind" "${fill[$kind]}" "$kind" "${on_fill[$kind]}" "$kind" "${text[$kind]}"
  done)
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

# Zen's userChrome.css, read at its start: the GTK window colours, accent and scheme over the ones Zen derives from a space's Edit Theme dots; private and unsynced windows keep Zen's own tint.
win=':root:not([zen-private-window], [zen-unsynced-window])'
cat >zen.css <<EOF
$win {
  --zen-primary-color: $accent_bg !important;
  --zen-branding-bg: $win_bg !important;
  --zen-branding-bg-reverse: $win_fg !important;
  --toolbox-textcolor: $win_fg !important;
  --toolbar-color-scheme: $scheme !important;
  --arrowpanel-background: $dialog !important;
  --zen-dialog-background: $dialog !important;
}
$win zen-workspace {
  --zen-primary-color: $accent_bg !important;
  --toolbox-textcolor: $win_fg !important;
}
$win .zen-browser-generic-background {
  --zen-main-browser-background: $win_bg !important;
  --zen-main-browser-background-toolbar: $win_bg !important;
  --zen-main-browser-background-old: $win_bg !important;
  --zen-main-browser-background-toolbar-old: $win_bg !important;
}
$win :is(panel, menupopup) {
  --panel-text-color: $win_fg !important;
}
$win#main-window,
$win#main-window :is(panel, menupopup, zen-workspace, #browser, .zen-browser-generic-background, #urlbar[breakout-extend], #zen-toast-container, #tabbrowser-tabpanels browser[type="content"]) {
  color-scheme: $scheme !important;
}
EOF

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
