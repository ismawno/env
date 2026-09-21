#!/usr/bin/env bash

# Pins one picture of the public wallpaper repo into the flake and puts it on screen.
# No argument opens a rofi picker, "<folder>/<file>.png" runs headless, --reset goes back to the
# stock background, --list prints "<folder>/<file>.png TAB <pretty name>" per picture without opening rofi.
# Paths, the repo slug and the quiet switch arrive in the environment, so nothing here knows about Nix.

set -euo pipefail

env_dir=${MAD_WP_ENV:?wallpaper-pick was built without an env checkout}
selection=${MAD_WP_SELECTION:?wallpaper-pick was built without a selection file}
repo_path=${MAD_WP_REPO_PATH:?wallpaper-pick was built without a repo path}
slug=${MAD_WP_SLUG:?wallpaper-pick was built without a wallpaper repo}
prefix=${MAD_WP_PREFIX:?wallpaper-pick was built without a repo prefix}
collection=${MAD_WP_COLLECTION:?wallpaper-pick was built without a collection directory}
thumb_base=${MAD_WP_THUMB_BASE:?wallpaper-pick was built without a thumbnail base url}
stable=${MAD_WP_STABLE:?wallpaper-pick was built without the stable wallpaper path}
conf=${MAD_WP_CONF:?wallpaper-pick was built without a hyprpaper config}
quiet=${MAD_WP_QUIET:-}
cache=${XDG_CACHE_HOME:-$HOME/.cache}/wallpaper-pick
theme=${MAD_WP_THEME:-${XDG_CONFIG_HOME:-$HOME/.config}/rofi/wallpapers.rasi}

# Must match the name width wallpapers.rasi leaves under each thumbnail, in characters of its font.
wrap_width=33
wrap_lines=3

declare -A pretty=()
lines=()
wrapped=""
commit=""
name=""
url=""
hash=""
color=""
saved=""
thumb_dir=""

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

notify() {
  if [ -z "$quiet" ] && command -v notify-send >/dev/null 2>&1; then
    notify-send -u "$1" "Wallpaper" "$2" || true
  fi
}

die() {
  notify critical "$1"
  printf 'wallpaper-pick: %s\n' "$1" >&2
  exit 1
}

need() {
  command -v "$1" >/dev/null 2>&1 || die "$1 is not on PATH"
}

hyprpaper_pids() {
  pgrep -u "$(id -u)" -f 'hyprpaper -c' || true
}

# hyprpaper 0.8.4 answers "invalid hyprpaper request" to its IPC verbs under this setup, so the
# picture changes by restarting it exactly the way startup.lua starts it.
restart_hyprpaper() {
  local pids count
  # Without a session to start it in, the running hyprpaper stays: better the old picture than none.
  hyprctl version >/dev/null 2>&1 || [ -n "${WAYLAND_DISPLAY:-}" ] || return 1
  pids=$(hyprpaper_pids)
  if [ -n "$pids" ]; then
    printf '%s\n' "$pids" | xargs -r kill
    for _ in $(seq 40); do
      [ -n "$(hyprpaper_pids)" ] || break
      sleep 0.1
    done
    printf '%s\n' "$(hyprpaper_pids)" | xargs -r kill -9
  fi
  if ! hyprctl eval "hl.exec_cmd('hyprpaper -c $conf')" >/dev/null 2>&1; then
    setsid -f hyprpaper -c "$conf" >/dev/null 2>&1 </dev/null
  fi
  for _ in $(seq 40); do
    [ -z "$(hyprpaper_pids)" ] || break
    sleep 0.1
  done
  count=$(hyprpaper_pids | grep -c . || true)
  [ "$count" = 1 ]
}

# Every failure past the write puts the old selection back, so the flake never keeps a wallpaper that did not verify.
fail_back() {
  local back="; the previous wallpaper is back"
  if [ -n "$saved" ]; then
    cp -f "$saved" "$selection"
    home-manager switch --flake "$env_dir" -b backup >/dev/null 2>&1 ||
      back="; $repo_path is back, but the switch that would show it failed too"
    if ! restart_hyprpaper; then
      if [ -n "$(hyprpaper_pids)" ]; then
        back="$back, and hyprpaper was left as it was: Super+N starts it again"
      else
        back="$back, and hyprpaper is not running: start it with Super+N"
      fi
    fi
    die "$1$back"
  fi
  die "$1"
}

nix_string() {
  printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' -e 's/\$[{]/\\${/g'
}

render_selection() {
  printf '%s\n' '# The wallpaper this flake shows, rewritten whole by wallpaper-pick. An empty set keeps the stock background.'
  if [ "$1" = reset ]; then
    printf '{ }\n'
  else
    printf '{\n'
    printf '  name = "%s";\n' "$(nix_string "$name")"
    printf '  url = "%s";\n' "$(nix_string "$url")"
    printf '  hash = "%s";\n' "$(nix_string "$hash")"
    printf '  color = "%s";\n' "$(nix_string "$color")"
    printf '}\n'
  fi
}

resolve_commit() {
  local out
  out=$(GIT_TERMINAL_PROMPT=0 git ls-remote "https://github.com/$slug" refs/heads/main 2>&1) ||
    die "cannot reach https://github.com/$slug: $(printf '%s' "$out" | tail -1)"
  commit=${out%%$'\t'*}
  [[ $commit =~ ^[0-9a-f]{40}$ ]] || die "https://github.com/$slug has no main branch"
}

collection_names() {
  (cd "$collection" && find . -mindepth 2 -maxdepth 2 -type f -name '*.png' -printf '%P\n') | LC_ALL=C sort
}

# Rofi would decode 221 full-size pictures on every open; the cache keeps one small jpeg each instead.
build_local_thumbs() {
  local rel src thumb
  while IFS= read -r rel; do
    src=$collection/$rel
    thumb=$cache/local/${rel%.png}.jpg
    if [ ! -f "$thumb" ] || [ "$src" -nt "$thumb" ]; then
      mkdir -p "$(dirname -- "$thumb")"
      printf '%s\0%s\0' "$src" "$thumb"
    fi
  done <"$work/names" |
    xargs -0 -r -P "$(nproc)" -n 2 bash "$0" --thumb
}

tree_names() {
  local tree
  tree=$(curl -fsSL --max-time 60 "https://api.github.com/repos/$slug/git/trees/$commit?recursive=1") ||
    die "$slug main carries no thumbnails and the GitHub API did not answer either"
  printf '%s' "$tree" |
    jq -r --arg p "$prefix/" '.tree[] | select(.type == "blob") | .path
      | select(startswith($p)) | select(endswith(".png")) | ltrimstr($p)' |
    LC_ALL=C sort
}

# Without the collection on disk the rows still carry pictures: thumbnails/index.tsv and the small
# jpegs beside it are plain git files on main, so listing and previewing costs no Git LFS bandwidth.
remote_names() {
  local key index name thumb out
  [ -n "$commit" ] || resolve_commit
  key=$(printf '%s\n%s\n' "$thumb_base" "$commit" | sha1sum | cut -c 1-12)
  thumb_dir=$cache/remote/$key
  index=$thumb_dir/index.tsv
  mkdir -p "$thumb_dir"
  find "$cache/remote" -mindepth 1 -maxdepth 1 -type d ! -name "$key" -exec rm -rf {} + 2>/dev/null || true

  if [ ! -s "$index" ]; then
    if curl -fsL --max-time 60 -o "$index.part" "$thumb_base/thumbnails/index.tsv"; then
      mv -f "$index.part" "$index"
    else
      rm -f "$index.part"
    fi
  fi

  if [ ! -s "$index" ]; then
    notify low "$slug main carries no thumbnails yet; the list comes without pictures"
    tree_names
    return 0
  fi

  jq -Rr --arg p "$prefix/" --arg base "$thumb_base" \
    'split("\t") | select(length == 2) | select(.[0] | startswith($p))
     | [ (.[0] | ltrimstr($p)), ($base + "/" + (.[1] | split("/") | map(@uri) | join("/"))) ] | @tsv' \
    <"$index" >"$work/index"
  [ -s "$work/index" ] || die "thumbnails/index.tsv on $slug main lists nothing under $prefix/"

  : >"$work/fetch"
  while IFS=$'\t' read -r name thumb; do
    out=$thumb_dir/${name%.png}.jpg
    [ -s "$out" ] && continue
    mkdir -p "$(dirname -- "$out")"
    printf '%s\0%s\0' "$thumb" "$out" >>"$work/fetch"
  done <"$work/index"

  if [ -s "$work/fetch" ]; then
    xargs -0 -r -P 8 -n 2 bash "$0" --download <"$work/fetch" >/dev/null 2>&1 || true
  fi

  cut -f 1 <"$work/index" | LC_ALL=C sort
}

# names.tsv at the repo root maps "<folder>/<file>.png" TAB "<pretty name>", cached per main commit like index.tsv.
load_pretty_names() {
  local head key dir path title code
  dir=$cache/names
  head=$commit
  if [ -z "$head" ]; then
    head=$(GIT_TERMINAL_PROMPT=0 git ls-remote "https://github.com/$slug" refs/heads/main 2>/dev/null | cut -f 1) || head=""
  fi
  key=$(printf '%s\n%s\n' "$thumb_base" "$head" | sha1sum | cut -c 1-12)
  mkdir -p "$dir"
  if [ -n "$head" ] && [ "$(cat "$dir/key" 2>/dev/null)" != "$key" ]; then
    code=0
    curl -fsL --max-time 30 -o "$dir/names.tsv.part" "$thumb_base/names.tsv" || code=$?
    case $code in
      0) mv -f "$dir/names.tsv.part" "$dir/names.tsv" ;;
      # 22 is an HTTP error and 37 a missing file:// path: main has no map, so every name falls back.
      22 | 37) : >"$dir/names.tsv" ;;
    esac
    rm -f "$dir/names.tsv.part"
    case $code in
      0 | 22 | 37) printf '%s\n' "$key" >"$dir/key" ;;
    esac
  fi
  [ -s "$dir/names.tsv" ] || return 0
  while IFS=$'\t' read -r path title || [ -n "$path" ]; do
    title=${title%$'\r'}
    case $path in
      '' | '#'*) continue ;;
    esac
    [ -z "$title" ] || pretty[$path]=$title
  done <"$dir/names.tsv"
}

greedy_lines() {
  local width=$1 word line=""
  shift
  lines=()
  for word in "$@"; do
    if [ -z "$line" ]; then
      line=$word
    elif [ $((${#line} + 1 + ${#word})) -le "$width" ]; then
      line+=" $word"
    else
      lines+=("$line")
      line=$word
    fi
  done
  [ -z "$line" ] || lines+=("$line")
}

# As few lines as wrap_width allows, then the narrowest width that still needs no more of them.
balanced_lines() {
  local joined="$*" count width
  greedy_lines "$wrap_width" "$@"
  count=${#lines[@]}
  [ "$count" -gt 1 ] || return 0
  width=$(((${#joined} + count - 1) / count))
  while [ "$width" -lt "$wrap_width" ]; do
    greedy_lines "$width" "$@"
    [ "${#lines[@]}" -gt "$count" ] || return 0
    width=$((width + 1))
  done
  greedy_lines "$wrap_width" "$@"
}

# A lone dash sticks to the word before it, so no line starts with "- ".
words_of() {
  local word
  local -a raw
  read -ra raw <<<"$1"
  words=()
  for word in "${raw[@]}"; do
    if [ "$word" = - ] && [ "${#words[@]}" -gt 0 ]; then
      words[-1]+=" -"
    else
      words+=("$word")
    fi
  done
}

# Rofi cannot wrap an element's text, so a name arrives already broken, preferably right after " - ".
wrap_name() {
  local LC_ALL=C.UTF-8
  local -a words plain first
  words_of "$1"
  balanced_lines "${words[@]}"
  if [ "${#lines[@]}" -gt 1 ] && [[ $1 == *" - "* ]]; then
    plain=("${lines[@]}")
    words_of "${1%% - *} -"
    balanced_lines "${words[@]}"
    first=("${lines[@]}")
    words_of "${1#* - }"
    balanced_lines "${words[@]}"
    lines=("${first[@]}" "${lines[@]}")
    if [ "${#lines[@]}" -gt "${#plain[@]}" ] || [ "${#lines[@]}" -gt "$wrap_lines" ]; then
      lines=("${plain[@]}")
    fi
  fi
  # A name too long even for all the lines ends on one long line, which rofi then ellipsizes.
  if [ "${#lines[@]}" -gt "$wrap_lines" ]; then
    lines=("${lines[@]:0:wrap_lines-1}" "${lines[*]:wrap_lines-1}")
  fi
  wrapped=$(printf '%s\n' "${lines[@]}")
}

load_pictures() {
  : >"$work/names"
  if [ -d "$collection" ]; then
    collection_names >"$work/names" || true
  fi
  if [ -s "$work/names" ]; then
    build_local_thumbs
    thumb_dir=$cache/local
  else
    remote_names >"$work/names"
    [ -s "$work/names" ] || die "neither $collection nor $slug main lists a picture"
  fi
  load_pretty_names
}

# Rows follow $work/names line for line, so the index rofi prints (-format i) names the file.
rows() {
  local rel title thumb icon
  while IFS= read -r rel; do
    title=${rel##*/}
    title=${pretty[$rel]:-${title%.png}}
    thumb=$thumb_dir/${rel%.png}.jpg
    icon=""
    [ ! -f "$thumb" ] || icon=$'\x1f'icon$'\x1f'$thumb
    if [ "$1" = list ]; then
      printf '%s\t%s' "$rel" "$title"
      [ -z "$icon" ] || printf '\0%s' "${icon#$'\x1f'}"
      printf '\n'
    else
      wrap_name "$title"
      printf '%s\0meta\x1f%s %s%s\x1e' "$wrapped" "$title" "${rel%.png}" "$icon"
    fi
  done <"$work/names"
}

usage() {
  cat <<'USAGE'
wallpaper-pick                       pick a wallpaper in rofi and pin it in the flake
wallpaper-pick <folder>/<file>.png   pin that picture without asking
wallpaper-pick --reset               go back to the stock background
wallpaper-pick --list                print every picture with its pretty name and stop
USAGE
}

# xargs calls the script back for one cache entry at a time; a thumbnail that fails just stays missing.
case "${1:-}" in
  --thumb)
    magick "$2[0]" -auto-orient -thumbnail 320x -strip -quality 82 "$3" >/dev/null 2>&1 || true
    exit 0
    ;;
  --download)
    curl -fsSL --max-time 30 -o "$3" "$2" || rm -f "$3"
    exit 0
    ;;
esac

for binary in curl find git home-manager identify jq magick nix nix-instantiate pgrep setsid sha1sum; do
  need "$binary"
done

mode="set"
case "${1:-}" in
  --reset) mode=reset ;;
  --list) mode=list ;;
  -h | --help)
    usage
    exit 0
    ;;
  -*) die "unknown option $1" ;;
  "") mode=menu ;;
  *) name=$1 ;;
esac

if [ "$mode" = list ]; then
  load_pictures
  rows list
  exit 0
fi

git -C "$env_dir" ls-files --error-unmatch -- "$repo_path" >/dev/null 2>&1 ||
  die "$repo_path is not tracked by git, so the flake would not see it"
[ -r "$selection" ] || die "cannot read $selection"

if [ "$mode" != reset ]; then
  resolve_commit
  if [ "$mode" = menu ]; then
    load_pictures
    rows menu >"$work/rows"
    theme_args=()
    [ ! -r "$theme" ] || theme_args=(-theme "$theme")
    pick=$(rofi -dmenu -i -no-custom -show-icons -sep $'\x1e' -eh "$wrap_lines" -format i \
      -p "Wallpaper" "${theme_args[@]}" <"$work/rows") || exit 0
    [[ $pick =~ ^[0-9]+$ ]] || exit 0
    mapfile -t pictures <"$work/names"
    name=${pictures[pick]:-}
    [ -n "$name" ] || exit 0
  fi
  [[ $name =~ ^[^/]+/[^/]+\.png$ ]] || die "pick a picture as \"<folder>/<file>.png\", not \"$name\""
  case "$name" in
    .* | */.*) die "\"$name\" is not a plain name" ;;
  esac

  encoded=$(jq -rn --arg s "$prefix/$name" '$s | split("/") | map(@uri) | join("/")')
  url="https://media.githubusercontent.com/media/$slug/$commit/$encoded"

  fetched=$(nix store prefetch-file --json --name wallpaper-pick-probe "$url" 2>"$work/prefetch") ||
    die "$name is not in $slug at ${commit:0:12}: $(tail -1 "$work/prefetch")"
  hash=$(printf '%s' "$fetched" | jq -r .hash)
  store=$(printf '%s' "$fetched" | jq -r .storePath)

  if head -c 64 "$store" | grep -q '^version https://git-lfs'; then
    die "$name came back as a Git LFS pointer, not a picture"
  fi
  identify -format '%m %w %h' "${store}[0]" >"$work/image" 2>/dev/null ||
    die "$name came back as something that is not an image"
  read -r format width _ <"$work/image" || true
  [ "${width:-0}" -gt 0 ] || die "$name came back as a ${format:-file} with no pixels"

  # A monitor still waiting for hyprpaper clears to this colour; the picture's own average beats a fixed grey under an AMOLED wallpaper.
  color="rgb($(magick "${store}[0]" -alpha off -depth 8 -resize '1x1!' -format '%[hex:p{0,0}]' info: | tr 'A-F' 'a-f'))"
fi

render_selection "$mode" >"$work/new"
if cmp -s "$work/new" "$selection" && [ -e "$stable" ]; then
  notify low "already showing what $repo_path says"
  exit 0
fi

saved="$work/previous"
cp -f "$selection" "$saved"
cp -f "$work/new" "$selection.new"
mv -f "$selection.new" "$selection"

nix-instantiate --eval --strict -- "$selection" >/dev/null 2>&1 ||
  fail_back "the selection just written does not evaluate as Nix"

home-manager switch --flake "$env_dir" -b backup >"$work/switch" 2>&1 ||
  fail_back "home-manager switch failed: $(tail -1 "$work/switch")"

restart_hyprpaper || fail_back "hyprpaper did not come back as exactly one process"

target=$(readlink -f "$stable" || true)
[ -n "$target" ] && [ -f "$target" ] || fail_back "$stable does not resolve to a file"

if [ "$mode" = reset ]; then
  [ "$(basename "$target")" = "1.png" ] || fail_back "$stable resolves to $target, not the stock background"
else
  [ "$(nix hash file --sri --type sha256 "$target")" = "$hash" ] ||
    fail_back "$stable resolves to $target, which is not the picture that was fetched"
fi

saved=""
if [ "$mode" = reset ]; then
  notify normal "back to the stock background; $repo_path changed, review the diff and commit it"
else
  notify normal "$name is up, pinned at ${commit:0:12}; $repo_path changed, review the diff and commit it"
fi
