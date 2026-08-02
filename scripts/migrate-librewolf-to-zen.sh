#!/usr/bin/env bash
# Clone the LibreWolf profile into Zen Browser: open tabs, extensions and their
# settings, bookmarks, history, cookies, logins, permissions, search engines.
#
# Zen is a Firefox fork, so the profile format is shared. LibreWolf here is
# Firefox 145, Zen 1.21 is Firefox 152 — a forward upgrade, which Gecko handles.
#
# Re-runnable: every run archives the current Zen profile before replacing it,
# so you can keep browsing in LibreWolf and re-sync until you fully switch over.
#
#   ./migrate-librewolf-to-zen.sh [--dry-run]
#
set -euo pipefail

DRY_RUN=0
if [ "${1:-}" = "--dry-run" ]; then
	DRY_RUN=1
fi

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP_DIR="$HOME/.local/share/zen-migration"

say() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m!!\033[0m %s\n' "$*" >&2; }
die() {
	printf '\033[1;31mxx\033[0m %s\n' "$*" >&2
	exit 1
}

# --- 1. no browser may hold either profile open ------------------------------

# -x matches the whole process name, so the script's own name can never match.
running() { pgrep -x "$1" >/dev/null 2>&1; }

# --dry-run writes nothing to either profile, so a running browser is only a
# warning there (the exported tab list may just be a few minutes stale).
busy() {
	if [ "$DRY_RUN" = 1 ]; then warn "$1"; else die "$1"; fi
}

if running '\.?.*librewolf.*'; then
	busy "LibreWolf is running. Close it fully (check the tray) and re-run."
fi
# The '-' guard keeps unrelated binaries such as zenity from matching.
if running '\.?zen(-.*)?'; then
	busy "Zen is running. Close it and re-run."
fi

command -v rsync >/dev/null 2>&1 || die "rsync is required but not on PATH"

# --- 2. locate the LibreWolf profile ----------------------------------------

LW_ROOT="$HOME/.librewolf"
[ -d "$LW_ROOT" ] || die "no LibreWolf directory at $LW_ROOT"

# Path= of the profile marked Default=1, falling back to the first one listed.
lw_profile_name="$(awk -F= '
	/^\[Profile/ { path=""; def=0 }
	/^Path=/     { path=$2; if (!first) first=path }
	/^Default=1/ { def=1 }
	path && def  { print path; exit }
	END          { if (!def) print first }
' "$LW_ROOT/profiles.ini" 2>/dev/null || true)"

SRC="$LW_ROOT/$lw_profile_name"
[ -n "$lw_profile_name" ] && [ -d "$SRC" ] || die "could not resolve the LibreWolf profile from $LW_ROOT/profiles.ini"
say "source profile: $SRC ($(du -sh "$SRC" | cut -f1))"

# --- 3. locate the Zen binary and bootstrap its profile ---------------------

ZEN_BIN=""
for c in zen-beta zen zen-browser zen-twilight; do
	if command -v "$c" >/dev/null 2>&1; then
		ZEN_BIN="$c"
		break
	fi
done
[ -n "$ZEN_BIN" ] || die "Zen is not installed — rebuild first (./home-rebuild.sh or ./nixos-rebuild.sh)"

# Zen follows the XDG base dirs (~/.config/zen); ~/.zen is the legacy layout.
zen_root() {
	for r in "${XDG_CONFIG_HOME:-$HOME/.config}/zen" \
		"${XDG_CONFIG_HOME:-$HOME/.config}/zen-beta" \
		"$HOME/.zen" "$HOME/.zen-beta"; do
		if [ -f "$r/profiles.ini" ]; then
			echo "$r"
			return 0
		fi
	done
	return 1
}

if ! ZEN_ROOT="$(zen_root)"; then
	say "no Zen profile yet — starting $ZEN_BIN headless once to create one"
	timeout 60 "$ZEN_BIN" --headless >/dev/null 2>&1 &
	zen_pid=$!
	for _ in $(seq 30); do
		sleep 1
		zen_root >/dev/null 2>&1 && break
	done
	kill "$zen_pid" 2>/dev/null || true
	wait "$zen_pid" 2>/dev/null || true
	sleep 2
	ZEN_ROOT="$(zen_root)" || die "Zen did not create a profile. Launch '$ZEN_BIN' once by hand, close it, then re-run."
fi

# The Nix wrapper exports MOZ_LEGACY_PROFILES=1, so Zen ignores the per-install
# [InstallXXXX] indirection and simply opens the profile marked Default=1 —
# which also means a Zen update (new store path) will not strand this profile.
zen_profile_rel="$(awk -F= '
	/^\[Profile/ { path=""; def=0 }
	/^Path=/     { path=$2; if (!first) first=path }
	/^Default=1/ { def=1 }
	path && def  { print path; exit }
	END          { if (!def) print first }
' "$ZEN_ROOT/profiles.ini")"

[ -n "$zen_profile_rel" ] || die "could not resolve the Zen profile from $ZEN_ROOT/profiles.ini"
case "$zen_profile_rel" in
/*) DST="$zen_profile_rel" ;; # IsRelative=0
*) DST="$ZEN_ROOT/$zen_profile_rel" ;;
esac
say "target profile: $DST"

# --- 4. export the open tabs as an importable bookmarks file ----------------

mkdir -p "$BACKUP_DIR"
TABS_PREFIX="$BACKUP_DIR/librewolf-tabs-$STAMP"
if python3 "$HERE/firefox-tabs.py" "$SRC" "$TABS_PREFIX"; then
	say "tab list saved to ${TABS_PREFIX}.html (importable) and .txt"
else
	warn "could not export the tab list; the session copy below still carries the tabs"
fi

if [ "$DRY_RUN" = 1 ]; then
	say "--dry-run: stopping before touching $DST"
	exit 0
fi

# --- 5. archive whatever Zen has now ----------------------------------------

if [ -d "$DST" ] && [ -n "$(ls -A "$DST" 2>/dev/null)" ]; then
	ARCHIVE="$BACKUP_DIR/zen-profile-$STAMP.tar.zst"
	say "archiving the current Zen profile to $ARCHIVE"
	if ! tar -C "$DST" -I 'zstd -T0' -cf "$ARCHIVE" . 2>/dev/null; then
		rm -f "$ARCHIVE"
		ARCHIVE="${ARCHIVE%.zst}.gz"
		tar -C "$DST" -czf "$ARCHIVE" .
	fi
	say "archived ($(du -sh "$ARCHIVE" | cut -f1)) — restore with: tar -C \"$DST\" -xf \"$ARCHIVE\""
	find "$DST" -mindepth 1 -maxdepth 1 -exec rm -rf {} +
fi
mkdir -p "$DST"

# --- 6. copy the profile -----------------------------------------------------
# Skipped on purpose:
#   lock/.parentlock        runtime locks
#   compatibility.ini       pins the app+version that wrote the profile; letting
#                           Zen regenerate it is what triggers a clean upgrade
#   addonStartup.json.lz4   startup cache keyed to the old app, rebuilt on boot
#   startupCache/           bytecode cache for the old binary
#   crashes/ minidumps/ datareporting/ saved-telemetry-pings/  noise
#   times.json              profile creation stamp; Zen recreates its own
# Everything else comes over, including storage/ — that is where each
# extension keeps its own settings (uBlock's filter lists, Dark Reader's
# config), keyed by the moz-extension UUIDs that prefs.js carries along.

say "copying profile data"
rsync -a --info=progress2 \
	--exclude 'lock' \
	--exclude '.parentlock' \
	--exclude 'compatibility.ini' \
	--exclude 'addonStartup.json.lz4' \
	--exclude 'startupCache/' \
	--exclude 'crashes/' \
	--exclude 'minidumps/' \
	--exclude 'datareporting/' \
	--exclude 'saved-telemetry-pings/' \
	--exclude 'times.json' \
	"$SRC/" "$DST/"

# The startup/bytecode cache still describes the profile we just replaced.
rm -rf "${XDG_CACHE_HOME:-$HOME/.cache}/zen" "${XDG_CACHE_HOME:-$HOME/.cache}/zen-beta"

say "done"
cat <<EOF

Next:
  1. Launch Zen ($ZEN_BIN). First start is slow — it rebuilds the extension and
     startup caches for the new engine.
  2. Your LibreWolf session should restore. If Zen opens on a blank workspace,
     use History > Restore Previous Session, or import ${TABS_PREFIX}.html
     via Bookmarks > Manage Bookmarks > Import and Backup > Import HTML.
  3. Check about:addons — uBlock Origin, Dark Reader, Privacy Badger,
     CanvasBlocker, ClearURLs and Consent-O-Matic come across with their
     settings. Re-enable any that Zen quarantined.
  4. LibreWolf is untouched and still installed; re-run this script to re-sync
     until you are ready to drop it.
EOF
