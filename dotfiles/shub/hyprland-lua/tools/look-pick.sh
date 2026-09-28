#!/usr/bin/env bash

# Switches the desktop look at runtime: a pick points ~/.local/state/look/<kind> at a prebuilt bundle, rewrites the few files that cannot link through it and pokes the running apps; nothing here knows about Nix.
set -euo pipefail
shopt -s inherit_errexit

kinds=${MAD_LOOK_KINDS:?look-pick was built without a kind}
defaults=${MAD_LOOK_DEFAULTS:?look-pick was built without defaults}
data=${MAD_LOOK_DATA:?look-pick was built without a bundle directory}
state=${MAD_LOOK_STATE:?look-pick was built without a state directory}
gtk3_base=${MAD_LOOK_GTK3_BASE:?look-pick was built without a GTK 3 settings.ini}
gtk4_base=${MAD_LOOK_GTK4_BASE:?look-pick was built without a GTK 4 settings.ini}
qt6ct_base=${MAD_LOOK_QT6CT_BASE:?look-pick was built without a qt6ct.conf}
qt6ct=${MAD_LOOK_QT6CT:?look-pick was built without a qt6ct.conf path}
quiet=${MAD_LOOK_QUIET:-}
menu_theme=${MAD_LOOK_RASI:-${XDG_CONFIG_HOME:-$HOME/.config}/rofi/wallpapers.rasi}
read -ra dconf_wrap <<<"${MAD_LOOK_DCONF_WRAP:-}"

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

notify() {
  if [ -z "$quiet" ] && command -v notify-send >/dev/null 2>&1; then
    notify-send -u "$1" "Look" "$2" || true
  fi
}

die() {
  notify critical "$1"
  printf 'look-pick: %s\n' "$1" >&2
  exit 1
}

warn() {
  printf 'look-pick: %s\n' "$1" >&2
}

is_kind() {
  [[ " $kinds " == *" $1 "* ]]
}

default_of() {
  local pair
  for pair in $defaults; do
    if [ "${pair%%=*}" = "$1" ]; then
      printf '%s' "${pair#*=}"
      return 0
    fi
  done
  die "this build has no default $1"
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

# The saved slug when this build has it; otherwise the default, while the saved name waits for a build that has it again.
shown() {
  local slug
  slug=$(saved "$1")
  if [ -z "$slug" ] || [ -z "$(name_of "$1" "$slug")" ]; then
    slug=$(default_of "$1")
  fi
  printf '%s' "$slug"
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
    [ -s "$state/$kind.name" ] || default_of "$kind" | replace "$state/$kind.name"
    slug=$(shown "$kind")
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

poke() {
  case $1 in
    ghostty) ghostty_pids | xargs -r kill -USR2 2>/dev/null || true ;;
    waybar) pkill -USR2 -u "$(id -u)" -f 'waybar -c [^ ]*/waybar/config(-cava)?( |$)' || true ;;
    swaync) swaync-client --reload-css >/dev/null 2>&1 || true ;;
    hyprland)
      if command -v hyprctl >/dev/null 2>&1 && [ -f "$2/hyprctl.lua" ]; then
        hyprctl eval "$(cat "$2/hyprctl.lua")" >/dev/null 2>&1 || true
      fi
      ;;
  esac
}

apply() {
  local live=$1 kind token
  shift
  relink
  [ "$live" = live ] || return 0
  for kind in "$@"; do
    [ -f "$state/$kind/pokes" ] || continue
    while read -r token; do
      poke "$token" "$state/$kind"
    done <"$state/$kind/pokes"
  done
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

choose() {
  local kind=$1 slug=$2 name
  name=$(name_of "$kind" "$slug")
  printf '%s\n' "$slug" | replace "$state/$kind.name"
  apply "$live" "$kind"
  case $kind in
    theme) notify low "$name is on; libadwaita apps take its colours when they next start" ;;
    *) notify low "$name is on; wlogout, rofi, the lock screen and Zen's web pages take it when they next open" ;;
  esac
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
look-pick KIND                 pick a KIND (font or theme) in rofi
look-pick KIND NAME            switch to NAME, a display name or a slug, without asking
look-pick --list [KIND]        print kind, slug and name of every entry, the shown one marked current
look-pick --reset [KIND]       go back to the defaults this build was made with
look-pick --apply              relink every kind from the saved names; each Home Manager activation runs it
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
esac

mkdir -p "$state"
exec 9>"$state/.lock"
flock 9

case "$1" in
  --apply)
    # shellcheck disable=SC2086 # the kinds are single words
    apply "$live" $kinds
    ;;
  --reset)
    [ -z "${2:-}" ] || is_kind "$2" || die "no kind called $2; there is: $kinds"
    for kind in ${2:-$kinds}; do
      default_of "$kind" | replace "$state/$kind.name"
    done
    # shellcheck disable=SC2086 # the kinds are single words
    apply "$live" ${2:-$kinds}
    ;;
  -*) die "unknown option $1" ;;
  *)
    is_kind "$1" || die "no kind called $1; there is: $kinds"
    kind=$1
    if [ -n "${2:-}" ]; then
      slug=$(resolve "$kind" "$2")
      [ -n "$slug" ] || die "no $kind called \"$2\"; look-pick --list $kind names them all"
    else
      # The lock is not kept while the menu is open.
      flock -u 9
      slug=$(menu "$kind")
      [ -n "$slug" ] || exit 0
      flock 9
    fi
    choose "$kind" "$slug"
    ;;
esac
