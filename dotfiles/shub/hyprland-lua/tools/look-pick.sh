#!/usr/bin/env bash

# Switches the desktop look at once, then pins the pick into the flake in the background: ~/.local/state/look points each kind at a prebuilt bundle, derived from look-choice.nix at every activation and rewritten by a pick ahead of it.
set -euo pipefail
shopt -s inherit_errexit

kinds=${MAD_LOOK_KINDS:?look-pick was built without a kind}
declared=${MAD_LOOK_DECLARED:?look-pick was built without the declared look}
stock=${MAD_LOOK_STOCK:?look-pick was built without the stock look}
data=${MAD_LOOK_DATA:?look-pick was built without a bundle directory}
state=${MAD_LOOK_STATE:?look-pick was built without a state directory}
gtk3_base=${MAD_LOOK_GTK3_BASE:?look-pick was built without a GTK 3 settings.ini}
gtk4_base=${MAD_LOOK_GTK4_BASE:?look-pick was built without a GTK 4 settings.ini}
qt6ct_base=${MAD_LOOK_QT6CT_BASE:?look-pick was built without a qt6ct.conf}
qt6ct=${MAD_LOOK_QT6CT:?look-pick was built without a qt6ct.conf path}
env_dir=${MAD_LOOK_ENV:?look-pick was built without an env checkout}
choice=${MAD_LOOK_CHOICE:?look-pick was built without a choice file}
repo_path=${MAD_LOOK_REPO_PATH:?look-pick was built without a repo path}
hm=${MAD_LOOK_HM:-home-manager}
quiet=${MAD_LOOK_QUIET:-}
menu_theme=${MAD_LOOK_RASI:-${XDG_CONFIG_HOME:-$HOME/.config}/rofi/wallpapers.rasi}
read -ra dconf_wrap <<<"${MAD_LOOK_DCONF_WRAP:-}"
log=${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/look-pick.log

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

notify() {
  if [ -z "$quiet" ] && command -v notify-send >/dev/null 2>&1; then
    notify-send -u "$1" "Look" "$2" || true
  fi
}

warn() {
  printf 'look-pick: %s\n' "$1" >&2
}

die() {
  notify critical "$1"
  warn "$1"
  exit 1
}

# shellcheck source=flake-pin.sh
source "${MAD_PIN_LIB:?look-pick was built without the flake-pin library}"
pin_env=$env_dir pin_file=$choice pin_repo_path=$repo_path pin_hm=$hm
pin_undone="the previous look is back"

is_kind() {
  [[ " $kinds " == *" $1 "* ]]
}

# The value of kind $2 in the "kind=slug ..." list $1, empty when the list has none.
value_in() {
  local pair
  for pair in $1; do
    if [ "${pair%%=*}" = "$2" ]; then
      printf '%s' "${pair#*=}"
      return 0
    fi
  done
}

index() {
  printf '%s' "$data/${1}s/index.tsv"
}

name_of() {
  awk -F '\t' -v slug="$2" '$1 == slug { print $2; exit }' "$(index "$1")"
}

# A slug, or a display name in any case.
resolve() {
  awk -F '\t' -v query="$2" 'BEGIN { query = tolower(query) } $1 == query || tolower($2) == query { print $1; exit }' "$(index "$1")"
}

saved() {
  local slug=""
  [ ! -s "$state/$1.name" ] || read -r slug <"$state/$1.name" || true
  printf '%s' "$slug"
}

# The saved slug when this build has it; otherwise the declared one, then the stock one.
shown() {
  local slug
  for slug in "$(saved "$1")" "$(value_in "$declared" "$1")" "$(value_in "$stock" "$1")"; do
    if [ -n "$slug" ] && [ -n "$(name_of "$1" "$slug")" ]; then
      printf '%s' "$slug"
      return 0
    fi
  done
  die "this build has no $1 to show"
}

replace() {
  cat >"$1.look-pick-$$"
  mv -f "$1.look-pick-$$" "$1"
}

# Sections keep their first place and a later key replaces an earlier one where it stood, so bundles only add to the base.
merge_ini() {
  awk '
    /^[[:space:]]*([#;].*)?$/ { next }
    /^\[.*\]$/ {
      section = $0
      if (!(section in seen)) { seen[section] = 1; order[++sections] = section }
      next
    }
    {
      key = $0
      sub(/[[:space:]]*=.*/, "", key)
      if (!(section in seen)) { seen[section] = 1; order[++sections] = section }
      if (!((section, key) in line)) name[section, ++keys[section]] = key
      line[section, key] = $0
    }
    END {
      for (i = 1; i <= sections; i++) {
        section = order[i]
        if (i > 1) print ""
        if (section != "") print section
        for (j = 1; j <= keys[section]; j++) print line[section, name[section, j]]
      }
    }
  ' "$@"
}

# Links every kind to what it shows, then rebuilds the files that combine kinds or must be real files.
relink() {
  local kind slug dir file
  local -a gtk3=("$gtk3_base") gtk4=("$gtk4_base") qt=("$qt6ct_base") dconf=()
  mkdir -p "$state"
  for kind in $kinds; do
    slug=$(shown "$kind")
    [ "$(saved "$kind")" = "$slug" ] || printf '%s\n' "$slug" | replace "$state/$kind.name"
    dir=$data/${kind}s/$slug
    [ -d "$dir" ] || die "$dir is missing; is ~/.local/share/look from this Home Manager generation?"
    ln -sfn "$dir" "$state/$kind.new"
    mv -Tf "$state/$kind.new" "$state/$kind"
    for file in gtk3 gtk4 qt6ct dconf; do
      [ -f "$dir/settings/$file.ini" ] || continue
      sed "s|@BUNDLE@|$dir|g" "$dir/settings/$file.ini" >"$work/$kind.$file.ini"
      case $file in
        gtk3) gtk3+=("$work/$kind.$file.ini") ;;
        gtk4) gtk4+=("$work/$kind.$file.ini") ;;
        qt6ct) qt+=("$work/$kind.$file.ini") ;;
        dconf) dconf+=("$work/$kind.$file.ini") ;;
      esac
    done
  done

  merge_ini "${gtk3[@]}" | replace "$state/gtk3.ini"
  merge_ini "${gtk4[@]}" | replace "$state/gtk4.ini"
  # qt6ct watches its folder and reloads on a new file there, which a link into the state would never give it.
  mkdir -p "$(dirname -- "$qt6ct")"
  merge_ini "${qt[@]}" | replace "$qt6ct"
  if [ "${#dconf[@]}" -gt 0 ]; then
    merge_ini "${dconf[@]}" >"$work/dconf.ini"
    "${dconf_wrap[@]}" dconf load / <"$work/dconf.ini" ||
      warn "dconf did not take the interface keys; GTK apps started from here on still read settings.ini"
  fi
}

# Ghostty's own CLI actions (ghostty +show-config and the like) run as the same binary and would die of the signal.
ghostty_pids() {
  local pid
  for pid in $(pgrep -u "$(id -u)" -x 'ghostty|\.ghostty-wrappe' || true); do
    tr '\0' '\n' <"/proc/$pid/cmdline" 2>/dev/null | sed -n 2p | grep -q '^+' || printf '%s\n' "$pid"
  done
}

# swaync-client waits for good when no swaync runs, hence its timeout.
poke() {
  case $1 in
    ghostty) ghostty_pids | xargs -r kill -USR2 2>/dev/null || true ;;
    waybar) pkill -USR2 -u "$(id -u)" -f 'waybar -c [^ ]*/waybar/config(-cava)?( |$)' || true ;;
    swaync) timeout 5 swaync-client --reload-css >/dev/null 2>&1 || true ;;
    hyprland)
      if command -v hyprctl >/dev/null 2>&1 && [ -f "$2/hyprctl.lua" ]; then
        hyprctl eval "$(cat "$2/hyprctl.lua")" >/dev/null 2>&1 || true
      fi
      ;;
  esac
}

# Writes the "kind=slug ..." list $2 into the state, relinks and, when $1 is live, pokes the running apps each named kind reaches.
show() {
  local live=$1 kind slug token
  exec 8>"$state/.lock"
  flock 8
  for kind in $kinds; do
    slug=$(value_in "$2" "$kind")
    [ -z "$slug" ] || printf '%s\n' "$slug" | replace "$state/$kind.name"
  done
  relink
  if [ "$live" = live ]; then
    for kind in $kinds; do
      [ -n "$(value_in "$2" "$kind")" ] && [ -f "$state/$kind/pokes" ] || continue
      while read -r token; do
        poke "$token" "$state/$kind"
      done <"$state/$kind/pokes"
    done
  fi
  exec 8>&-
}

# The "kind=slug ..." list look-choice.nix holds now; a kind it leaves out has no entry.
chosen() {
  local json kind slug
  json=$(nix-instantiate --eval --strict --json -- "$choice" 2>/dev/null) ||
    die "$repo_path does not evaluate as Nix"
  for kind in $kinds; do
    slug=$(printf '%s' "$json" | jq -r --arg kind "$kind" '.[$kind] // empty')
    [ -z "$slug" ] || printf '%s=%s ' "$kind" "$slug"
  done
}

nix_string() {
  printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' -e 's/\$[{]/\\${/g'
}

render_choice() {
  local kind slug
  printf '%s\n' '# The look this flake shows, rewritten whole by look-pick: a theme and a font by slug; a kind left out keeps the stock one.'
  printf '{\n'
  for kind in $kinds; do
    slug=$(value_in "$1" "$kind")
    [ -z "$slug" ] || printf '  %s = "%s";\n' "$kind" "$(nix_string "$slug")"
  done
  printf '}\n'
}

# A failed pin puts back the look that was on screen before, every kind of it.
pin_restore() {
  show "$live" "$previous"
}

# Runs detached with the pick already on screen, holding the flake lock on fd 9 until the switch agrees.
pin() {
  local target=$1 label=$2 kind want
  previous=$3
  pin_held || die "--pin only runs from a pick that holds $pin_lock"
  trap pin_on_signal TERM INT HUP

  pin_save
  render_choice "$target" >"$work/new"
  pin_write "$work/new" choice
  pin_switch

  for kind in $kinds; do
    want=$(value_in "$target" "$kind")
    [ -n "$want" ] || want=$(value_in "$stock" "$kind")
    [ "$(saved "$kind")" = "$want" ] && [ "$(readlink -f "$state/$kind")" = "$(readlink -f "$data/${kind}s/$want")" ] ||
      pin_fail "the switch left the $kind at \"$(saved "$kind")\", not \"$want\""
  done
  pin_done "$label is pinned"
  exit 0
}

menu() {
  local kind=$1 current slug name row=0 i=0 pick
  local -a theme_args=()
  current=$(shown "$kind")
  while IFS=$'\t' read -r slug name; do
    [ "$slug" != "$current" ] || row=$i
    printf '%s\0icon\x1f%s\n' "$name" "$data/${kind}s/$slug/thumb.png"
    i=$((i + 1))
  done <"$(index "$kind")" >"$work/rows"
  [ ! -r "$menu_theme" ] || theme_args=(-theme "$menu_theme" -theme-str "entry { placeholder: \"Search ${kind}s\"; }")
  pick=$(rofi -dmenu -i -no-custom -show-icons -format i -a "$row" -selected-row "$row" \
    -p "${kind^}" "${theme_args[@]}" <"$work/rows") || return 0
  [[ $pick =~ ^[0-9]+$ ]] || return 0
  sed -n "$((pick + 1))p" "$(index "$kind")" | cut -f 1
}

list() {
  local kind slug name current
  for kind in "$@"; do
    current=$(shown "$kind")
    while IFS=$'\t' read -r slug name; do
      printf '%s\t%s\t%s' "$kind" "$slug" "$name"
      [ "$slug" != "$current" ] || printf '\tcurrent'
      printf '\n'
    done <"$(index "$kind")"
  done
}

usage() {
  cat <<'USAGE'
look-pick KIND                 pick a KIND (font or theme) in rofi and pin it in the flake
look-pick KIND NAME            show and pin NAME, a display name or a slug, without asking
look-pick --list [KIND]        print kind, slug and name of every entry, the shown one marked current
look-pick --reset [KIND]       go back to the stock look and pin that
look-pick --apply              show what look-choice.nix declared for this build; each Home Manager activation runs it
look-pick --no-live ...        any of the above without poking the running apps
USAGE
}

live=live
if [ "${1:-}" = --no-live ]; then
  live=no
  shift
fi

case "${1:-}" in
  -h | --help | "")
    usage
    exit 0
    ;;
  --list)
    [ -z "${2:-}" ] || is_kind "$2" || die "no kind called $2; there is: $kinds"
    # shellcheck disable=SC2086 # the kinds are single words
    list ${2:-$kinds}
    exit 0
    ;;
  --apply)
    mkdir -p "$state"
    show "$live" "$declared"
    exit 0
    ;;
  --pin)
    shift
    pin "$@"
    ;;
  --reset)
    [ -z "${2:-}" ] || is_kind "$2" || die "no kind called $2; there is: $kinds"
    mode=reset picked=${2:-$kinds}
    ;;
  -*) die "unknown option $1" ;;
  *)
    is_kind "$1" || die "no kind called $1; there is: $kinds"
    mode=menu picked=$1
    [ -z "${2:-}" ] || mode="set"
    ;;
esac

for binary in flock git jq "$hm" nix-instantiate setsid; do
  command -v "$binary" >/dev/null 2>&1 || die "$binary is not on PATH"
done
pin_tracked || die "$repo_path is not tracked by git, so the flake would not see it"
[ -r "$choice" ] || die "cannot read $choice"
mkdir -p "$state"

case $mode in
  reset)
    slug="" label="the stock look"
    [ "$picked" = "$kinds" ] || label="the stock $picked"
    ;;
  set)
    slug=$(resolve "$picked" "$2")
    [ -n "$slug" ] || die "no $picked called \"$2\"; look-pick --list $picked names them all"
    ;;
  menu)
    pin_probe menu
    slug=$(menu "$picked")
    [ -n "$slug" ] || exit 0
    ;;
esac
[ -z "$slug" ] || label=$(name_of "$picked" "$slug")

# Taken again now: two pickers may both have passed the probe, and only one may touch the screen.
pin_take "$mode"

# target is what look-choice.nix will hold, wanted what the screen will show, previous what it shows now.
was=$(chosen) target="" wanted="" previous="" changed=""
for kind in $kinds; do
  previous+="$kind=$(shown "$kind") "
  if [[ " $picked " == *" $kind "* ]]; then
    want=${slug:-$(value_in "$stock" "$kind")}
    [ -z "$slug" ] || target+="$kind=$slug "
    wanted+="$kind=$want "
    [ "$(shown "$kind")" = "$want" ] || changed=1
  else
    kept=$(value_in "$was" "$kind")
    [ -z "$kept" ] || target+="$kind=$kept "
  fi
done
[ "$target" = "$was" ] || changed=1

if [ -z "$changed" ]; then
  notify low "already showing what $repo_path says"
  exit 0
fi

show "$live" "$wanted"
case $picked in
  theme) notify low "$label is on; libadwaita apps take its colours when they next start" ;;
  font) notify low "$label is on; wlogout, rofi, the lock screen and Zen's web pages take it when they next open" ;;
  *) notify low "$label is on" ;;
esac

# The switch takes its time behind the pick; the detached pin inherits fd 9 and with it the lock.
: >"$log"
args=(--pin)
[ "$live" = live ] || args=(--no-live --pin)
setsid -f "$BASH" "$0" "${args[@]}" "$target" "$label" "$previous" </dev/null >>"$log" 2>&1
exit 0
