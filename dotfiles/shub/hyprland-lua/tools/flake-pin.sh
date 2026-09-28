# shellcheck shell=bash disable=SC2154
# Sourced by the pickers that pin into the flake: one lock for all of them, the tracked file rewritten whole, a home-manager switch behind it and every failure undone; the caller sets pin_env, pin_file, pin_repo_path, pin_hm, pin_undone and work, and defines notify, die, warn and pin_restore, which puts the previous pick back on screen and may add to pin_back.

pin_lock=${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/flake-pin.lock
pin_saved="" pin_switching="" pin_hm_pid="" pin_failing="" pin_back=""

pin_busy() {
  notify normal "still pinning the previous pick into the flake; try again in a moment"
  warn "still pinning the previous pick into the flake; try again in a moment"
  if [ "$1" = menu ]; then exit 0; fi
  exit 75
}

# Refused before a menu opens rather than after browsing; the lock is not kept while it is open.
pin_probe() {
  exec 9>>"$pin_lock"
  flock -n 9 || pin_busy "$1"
  exec 9>&-
}

# Held on fd 9 from the moment a pick touches anything until its switch is over; tmpfs, so it never outlives the login, and a detached --pin inherits it.
pin_take() {
  exec 9>>"$pin_lock"
  flock -n 9 || pin_busy "$1"
}

pin_held() {
  flock -n 9 2>/dev/null
}

pin_tracked() {
  git -C "$pin_env" ls-files --error-unmatch -- "$pin_repo_path" >/dev/null 2>&1
}

pin_save() {
  pin_saved=$work/pin-previous
  cp -f "$pin_file" "$pin_saved"
}

pin_put() {
  cp -f "$1" "$pin_file.new"
  mv -f "$pin_file.new" "$pin_file"
}

# $1 is the new file, $2 what it holds for the messages.
pin_write() {
  pin_put "$1"
  pin_tracked || pin_fail "$pin_repo_path is not tracked by git, so the flake would not see it"
  nix-instantiate --eval --strict -- "$pin_file" >/dev/null 2>&1 ||
    pin_fail "the $2 just written does not evaluate as Nix"
}

pin_switch() {
  pin_switching=1
  "$pin_hm" switch --flake "$pin_env" -b backup >"$work/switch" 2>&1 &
  pin_hm_pid=$!
  wait "$pin_hm_pid" || pin_fail "home-manager switch failed: $(tail -1 "$work/switch")"
  pin_hm_pid=""
}

# Every failure puts the old file back, switches to it again when a switch had begun, and lets the picker restore the screen, so the flake never keeps a pick that did not verify.
pin_fail() {
  pin_failing=1
  pin_back="; $pin_undone"
  if [ -n "$pin_saved" ]; then
    pin_put "$pin_saved"
    if [ -n "$pin_switching" ]; then
      "$pin_hm" switch --flake "$pin_env" -b backup >/dev/null 2>&1 ||
        pin_back="; $pin_repo_path is back, but the switch that would show it failed too"
    fi
  fi
  pin_restore
  die "$1$pin_back"
}

# shellcheck disable=SC2329 # invoked by the trap the picker sets
pin_on_signal() {
  [ -z "$pin_failing" ] || return 0
  if [ -n "$pin_hm_pid" ]; then
    pkill -TERM -P "$pin_hm_pid" 2>/dev/null || true
    kill "$pin_hm_pid" 2>/dev/null || true
    wait "$pin_hm_pid" 2>/dev/null || true
  fi
  pin_fail "interrupted"
}

pin_done() {
  pin_saved=""
  notify normal "$1; $pin_repo_path changed, review the diff and commit it"
}
