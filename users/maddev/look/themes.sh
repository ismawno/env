# Build-time only: a bundle for every Ghostty theme whose palette can drive every target, native first so a duplicate palette keeps the native GTK theme; the log names each theme left out and why.
set -euo pipefail

slug_of() {
  printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9+]+/-/g; s/^-+//; s/-+$//'
}

export bundles=$TMPDIR/bundles
mkdir -p "$bundles" "$out" "$gtk/share/themes"

# One NUL-separated job of five fields per theme: name, slug, GTK theme name, GTK theme folder and role overrides, the last three empty for a generated theme.
declare -A native=() slugs=()
while IFS=$'\t' read -r name gtkName gtkDir roles; do
  native[$name]=1
  printf '%s\0%s\0%s\0%s\0%s\0' "$name" "$(slug_of "$name")" "$gtkName" "$gtkDir" "$roles"
done <"$nativeThemes" >"$TMPDIR/jobs"
for file in "$ghosttyThemes"/*; do
  name=${file##*/}
  [ -z "${native[$name]:-}" ] || continue
  printf '%s\0%s\0\0\0\0' "$name" "$(slug_of "$name")"
done >>"$TMPDIR/jobs"

while IFS= read -r -d '' name && IFS= read -r -d '' slug && IFS= read -r -d '' _ && IFS= read -r -d '' _ && IFS= read -r -d '' _; do
  if [ -z "$slug" ] || [ -n "${slugs[$slug]:-}" ]; then
    echo "look: $name and ${slugs[$slug]:-another theme} share the slug \"$slug\"" >&2
    exit 1
  fi
  slugs[$slug]=$name
done <"$TMPDIR/jobs"

xargs -0 -n 5 -P "${NIX_BUILD_CORES:-1}" bash "$bundleScript" <"$TMPDIR/jobs"

declare -A seen=()
: >"$TMPDIR/index"
while IFS= read -r -d '' name && IFS= read -r -d '' slug && IFS= read -r -d '' _ && IFS= read -r -d '' _ && IFS= read -r -d '' _; do
  dir=$bundles/$slug
  if [ -f "$dir/rejected" ]; then
    echo "look: left out $name: $(cat "$dir/rejected")"
    continue
  fi
  palette=$(cat "$dir/palette")
  if [ -n "${seen[$palette]:-}" ]; then
    echo "look: left out $name: the very palette of ${seen[$palette]}"
    continue
  fi
  seen[$palette]=$name
  rm "$dir/palette"
  if [ -d "$dir/gtk-theme" ]; then
    mv "$dir/gtk-theme" "$gtk/share/themes/look-$slug"
  fi
  mv "$dir" "$out/$slug"
  printf '%s\t%s\n' "$slug" "$name" >>"$TMPDIR/index"
done <"$TMPDIR/jobs"

LC_ALL=C sort -t "$(printf '\t')" -k 2,2f -k 2,2 "$TMPDIR/index" >"$out/index.tsv"
echo "look: $(wc -l <"$out/index.tsv") themes of $(find "$ghosttyThemes" -mindepth 1 -maxdepth 1 | wc -l)"
