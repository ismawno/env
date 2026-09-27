# Build-time only: one mono font's files for look-pick's state, and its preview drawn in that very font; FONTCONFIG_FILE sees nothing but the font's own package.
set -euo pipefail

sample='myObj->myFunction(args);'

die() {
  printf 'font-bundle: %s: %s\n' "$lookName" "$1" >&2
  exit 1
}

export HOME=$TMPDIR XDG_CACHE_HOME=$TMPDIR/cache
for name in "$family" "$mono"; do
  [ -n "$(fc-list "$name:charset=20-7e" family)" ] || die "no face of $name covers ASCII"
done

mkdir -p "$out/settings"
cd "$out"

printf 'font-family = ""\nfont-family = "%s"\n' "$family" >ghostty

# Icons come from the symbols-only Nerd Font look.nix installs, behind a font that has none of its own.
cat >fontconfig.conf <<EOF
<?xml version="1.0"?>
<!DOCTYPE fontconfig SYSTEM "urn:fontconfig:fonts.dtd">
<fontconfig>
  <alias binding="strong">
    <family>monospace</family>
    <prefer><family>$mono</family><family>Symbols Nerd Font Mono</family></prefer>
  </alias>
</fontconfig>
EOF

printf "[org/gnome/desktop/interface]\nmonospace-font-name='%s 11'\n" "$mono" >settings/dconf.ini
printf '[Fonts]\nfixed="%s,11"\n' "$mono" >settings/qt6ct.ini
printf '%s\n' ghostty >pokes

# Fitted to 296 px from a 20 pt measure, then shrunk while whole-pixel advances still overshoot, so every font fills the thumb alike.
markup() {
  printf '<span font_family="%s" size="%s" foreground="#ebdbb2">%s</span>' "$family" "$1" \
    "$(sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g' <<<"$sample")"
}
measure() {
  magick -background none "pango:$(markup "$1")" -format '%w' info:
}
width=$(measure 20480)
[ "$width" -gt 0 ] || die "pango drew nothing"
size=$((20480 * 296 / width)) width=$(measure "$size")
while [ "$width" -gt 296 ]; do
  size=$((size * 296 / width)) width=$(measure "$size")
done
magick -background none "pango:$(markup "$size")" "$TMPDIR/text.png"
magick -size 320x200 xc:'#282828' "$TMPDIR/text.png" -gravity center -composite \
  -depth 8 -strip -define png:exclude-chunks=date,time thumb.png
