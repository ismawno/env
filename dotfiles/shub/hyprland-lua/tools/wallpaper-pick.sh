#!/usr/bin/env bash

# Puts one picture of the public wallpaper repo on screen at once, then pins it into the flake in the background; nothing here knows about Nix.
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
hm=${MAD_WP_HM:-home-manager}
runtime=${XDG_RUNTIME_DIR:-/run/user/$(id -u)}
# Held from the moment a pick touches anything until its switch is over; tmpfs, so it never outlives the login.
lock=$runtime/wallpaper-pick.lock
gcroot=$runtime/wallpaper-pick.gcroot
tmpconf=$runtime/wallpaper-pick.conf
log=$runtime/wallpaper-pick.log

# Must match the name width wallpapers.rasi leaves beside each thumbnail, in characters of its font.
wrap_width=60
wrap_lines=3

declare -A pretty=()
lines=() wrapped="" commit="" name="" url="" hash="" color=""
saved="" store="" switching="" hm_pid="" failing="" thumb_dir="" names_file="" source_base=""

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

# hyprpaper 0.8.4 refuses its IPC verbs here, so it restarts the way startup.lua starts it; hyprctl refuses an eval holding "/hyprpaper", hence the escaped slashes.
restart_hyprpaper() {
  local config=${1:-$conf} escaped pids count
  escaped=$(printf '%s' "$config" | sed 's|/|\\047|g')
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
  if ! hyprctl eval "hl.exec_cmd('hyprpaper -c $escaped')" >/dev/null 2>&1; then
    setsid -f hyprpaper -c "$config" >/dev/null 2>&1 </dev/null 9>&-
  fi
  for _ in $(seq 40); do
    [ -z "$(hyprpaper_pids)" ] || break
    sleep 0.1
  done
  count=$(hyprpaper_pids | grep -c . || true)
  [ "$count" = 1 ]
}

busy() {
  notify normal "still pinning the previous pick into the flake; try again in a moment"
  printf 'wallpaper-pick: %s\n' "still pinning the previous pick into the flake; try again in a moment" >&2
  if [ "$mode" = menu ]; then exit 0; fi
  exit 75
}

# Every failure of the background pin puts the old selection and the old picture back, so the flake never keeps a wallpaper that did not verify.
fail_back() {
  local back="; the previous wallpaper is back"
  failing=1
  if [ -n "$saved" ]; then
    cp -f "$saved" "$selection.new"
    mv -f "$selection.new" "$selection"
    if [ -n "$switching" ]; then
      "$hm" switch --flake "$env_dir" -b backup >/dev/null 2>&1 ||
        back="; $repo_path is back, but the switch that would show it failed too"
    fi
  fi
  if ! restart_hyprpaper "$conf"; then
    if [ -n "$(hyprpaper_pids)" ]; then
      back="$back, and hyprpaper was left as it was: Super+N starts it again"
    else
      back="$back, and hyprpaper is not running: start it with Super+N"
    fi
  fi
  rm -f "$gcroot" "$tmpconf"
  die "$1$back"
}

# shellcheck disable=SC2329 # invoked by the trap in pin
on_signal() {
  [ -z "$failing" ] || return 0
  if [ -n "$hm_pid" ]; then
    pkill -TERM -P "$hm_pid" 2>/dev/null || true
    kill "$hm_pid" 2>/dev/null || true
    wait "$hm_pid" 2>/dev/null || true
  fi
  fail_back "interrupted"
}

# Same name as the module's fetchurl, so the prefetched file is the very store path the switch pins.
store_name() {
  printf '%s' "wallpaper-$1" | LC_ALL=C sed -E 's/[^A-Za-z0-9+._?=-]+/-/g; s/^\.+//' | tail -c 207
}

# A monitor still waiting for hyprpaper clears to this colour; the picture's own average beats a fixed grey under an AMOLED wallpaper.
sample_color() {
  printf 'rgb(%s)' "$(magick "$1[0]" -alpha off -depth 8 -resize '1x1!' -format '%[hex:p{0,0}]' info: | tr 'A-F' 'a-f')"
}

# Runs detached with the picture already on screen, holding the lock on fd 9 until the flake agrees; hyprpaper restarts only for a store name that drifted from the module's.
pin() {
  mode=$1 name=$2 url=$3 hash=$4 store=$5 commit=$6
  flock -n 9 2>/dev/null || die "--pin only runs from a pick that holds $lock"
  trap on_signal TERM INT HUP

  saved="$work/previous"
  cp -f "$selection" "$saved"
  if [ "$mode" != reset ]; then
    color=$(sample_color "$store") || fail_back "cannot sample the colour of $name"
  fi
  render_selection "$mode" >"$selection.new"
  mv -f "$selection.new" "$selection"

  git -C "$env_dir" ls-files --error-unmatch -- "$repo_path" >/dev/null 2>&1 ||
    fail_back "$repo_path is not tracked by git, so the flake would not see it"
  nix-instantiate --eval --strict -- "$selection" >/dev/null 2>&1 ||
    fail_back "the selection just written does not evaluate as Nix"

  switching=1
  "$hm" switch --flake "$env_dir" -b backup >"$work/switch" 2>&1 &
  hm_pid=$!
  wait "$hm_pid" || fail_back "home-manager switch failed: $(tail -1 "$work/switch")"
  hm_pid=""

  target=$(readlink -f "$stable" || true)
  [ -n "$target" ] && [ -f "$target" ] || fail_back "$stable does not resolve to a file"
  if [ "$mode" = reset ]; then
    [ "$(basename "$target")" = "1.png" ] || fail_back "$stable resolves to $target, not the stock background"
  else
    [ "$(nix hash file --sri --type sha256 "$target")" = "$hash" ] ||
      fail_back "$stable resolves to $target, which is not the picture that was fetched"
  fi
  if [ "$target" != "$store" ] && ! cmp -s "$target" "$store"; then
    restart_hyprpaper "$conf" || fail_back "hyprpaper did not come back as exactly one process"
  fi

  saved=""
  rm -f "$gcroot" "$tmpconf"
  if [ "$mode" = reset ]; then
    notify normal "back to the stock background; $repo_path changed, review the diff and commit it"
  else
    notify normal "$name is up, pinned at ${commit:0:12}; $repo_path changed, review the diff and commit it"
  fi
  exit 0
}

nix_string() {
  printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' -e 's/\$[{]/\\${/g'
}

render_selection() {
  printf '%s\n' '# The wallpaper this flake shows, rewritten whole by wallpaper-pick. An empty set keeps the stock background.'
  if [ "$1" = reset ]; then
    printf '{ }\n'
  else
    printf '{\n  name = "%s";\n  url = "%s";\n  hash = "%s";\n  color = "%s";\n}\n' \
      "$(nix_string "$name")" "$(nix_string "$url")" "$(nix_string "$hash")" "$(nix_string "$color")"
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
    die "$slug main carries no names.tsv and the GitHub API did not answer either"
  printf '%s' "$tree" |
    jq -r --arg p "$prefix/" '.tree[] | select(.type == "blob") | .path
      | select(startswith($p)) | select(endswith(".png")) | ltrimstr($p)' |
    LC_ALL=C sort
}

# names.tsv, the list of the collection, maps "<folder>/<file>.png" TAB "<pretty name>"; it is read by commit because .../main is served stale for minutes, and curl's 22 or 37 means the commit carries none.
load_pretty_names() {
  local key dir path title code
  dir=$cache/names
  if [ -z "$commit" ]; then
    commit=$(GIT_TERMINAL_PROMPT=0 git ls-remote "https://github.com/$slug" refs/heads/main 2>/dev/null | cut -f 1) || commit=""
    [[ $commit =~ ^[0-9a-f]{40}$ ]] || commit=""
  fi
  source_base=$thumb_base
  [ -z "$commit" ] || [[ $thumb_base != */main ]] || source_base=${thumb_base%/main}/$commit
  key=$(printf '%s\n%s\n' "$thumb_base" "$commit" | sha1sum | cut -c 1-12)

  mkdir -p "$dir"
  if [ -n "$commit" ] && [ "$(cat "$dir/key" 2>/dev/null)" != "$key" ]; then
    code=0
    curl -fsL --max-time 30 -o "$dir/names.tsv.part" "$source_base/names.tsv" || code=$?
    case $code in
      0) mv -f "$dir/names.tsv.part" "$dir/names.tsv" ;;
      22 | 37) : >"$dir/names.tsv" ;;
    esac
    rm -f "$dir/names.tsv.part"
    case $code in
      0 | 22 | 37) printf '%s\n' "$key" >"$dir/key" ;;
    esac
  fi
  [ -s "$dir/names.tsv" ] || return 0
  names_file=$dir/names.tsv
  while IFS=$'\t' read -r path title || [ -n "$path" ]; do
    title=${title%$'\r'}
    case $path in
      '' | '#'*) continue ;;
    esac
    [ -z "$title" ] || pretty[$path]=$title
  done <"$names_file"
}

# Without the collection the rows still carry pictures: every path in names.tsv has a thumbnail of the same name beside it, and those jpegs are plain git files, so no Git LFS bandwidth.
remote_names() {
  local key name thumb out
  [ -n "$commit" ] || resolve_commit
  key=$(printf '%s\n%s\n' "$thumb_base" "$commit" | sha1sum | cut -c 1-12)
  thumb_dir=$cache/remote/$key
  mkdir -p "$thumb_dir"
  find "$cache/remote" -mindepth 1 -maxdepth 1 -type d ! -name "$key" -exec rm -rf {} + 2>/dev/null || true

  if [ -z "$names_file" ]; then
    notify low "$slug carries no names.tsv at ${commit:0:12}; the list comes without pictures"
    tree_names
    return 0
  fi

  jq -Rr --arg base "$source_base" \
    'split("\t")[0] | select(startswith("#") | not) | select(endswith(".png"))
     | [ ., ($base + "/thumbnails/" + (rtrimstr(".png") | split("/") | map(@uri) | join("/")) + ".jpg") ]
     | @tsv' <"$names_file" >"$work/thumbs"
  [ -s "$work/thumbs" ] || die "names.tsv on $slug at ${commit:0:12} lists no picture"

  : >"$work/fetch"
  while IFS=$'\t' read -r name thumb; do
    out=$thumb_dir/${name%.png}.jpg
    [ -s "$out" ] && continue
    mkdir -p "$(dirname -- "$out")"
    printf '%s\0%s\0' "$thumb" "$out" >>"$work/fetch"
  done <"$work/thumbs"

  if [ -s "$work/fetch" ]; then
    xargs -0 -r -P 8 -n 2 bash "$0" --download <"$work/fetch" >/dev/null 2>&1 || true
  fi

  cut -f 1 <"$work/thumbs" | LC_ALL=C sort
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

# Rofi cannot wrap an element's text, so a name arrives already broken, preferably right after " - "; one too long for every line ends ellipsized.
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
  load_pretty_names
  if [ -s "$work/names" ]; then
    build_local_thumbs
    thumb_dir=$cache/local
  else
    remote_names >"$work/names"
    [ -s "$work/names" ] || die "neither $collection nor $slug main lists a picture"
  fi
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

for binary in cmp curl find flock git "$hm" identify jq magick nix nix-instantiate nix-store pgrep setsid sha1sum; do
  need "$binary"
done

mode="set"
case "${1:-}" in
  --pin)
    shift
    pin "$@"
    ;;
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

# Refused before rofi opens rather than after browsing; the lock is not kept while the picker is open.
exec 9>>"$lock"
flock -n 9 || busy
exec 9>&-

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

  fetched=$(nix store prefetch-file --json --name "$(store_name "$name")" "$url" 2>"$work/prefetch") ||
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
else
  store=$(readlink -f "$(dirname -- "$stable")")/1.png
  [ -f "$store" ] || die "$store, the stock background, is missing"
fi

# Taken again now: two pickers may both have passed the probe, and only one may touch the screen.
exec 9>>"$lock"
flock -n 9 || busy

# The colour is only sampled later, so it cannot tell two selections apart here.
render_selection "$mode" | grep -v '^  color = ' >"$work/new"
if grep -v '^  color = ' "$selection" | cmp -s - "$work/new" && [ -e "$stable" ]; then
  notify low "already showing what $repo_path says"
  exit 0
fi

if [ "$mode" != reset ]; then
  nix-store --add-root "$gcroot" --indirect --realise "$store" >/dev/null 2>&1 ||
    die "cannot keep $name in the Nix store while it is being pinned"
fi
sed -E "s|^([[:space:]]*path[[:space:]]*=).*|\1 $store|" "$conf" >"$tmpconf"
grep -qF "= $store" "$tmpconf" || die "$conf has no path line to point at $store"

if ! restart_hyprpaper "$tmpconf"; then
  rm -f "$gcroot" "$tmpconf"
  restart_hyprpaper "$conf" || true
  die "could not put $name on screen; nothing was pinned"
fi

# The switch takes its time behind the picture; the detached pin inherits fd 9 and with it the lock.
: >"$log"
setsid -f "$BASH" "$0" --pin "$mode" "$name" "$url" "$hash" "$store" "$commit" </dev/null >>"$log" 2>&1
exit 0
