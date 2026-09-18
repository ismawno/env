#!/bin/sh
# CachyOS half of the smalltop hibernation interlock:  sudo sh install.sh [--no-initramfs]
set -eu
here=$(cd "$(dirname "$0")" && pwd)
[ "$(id -u)" = 0 ] || { echo "run as root" >&2; exit 1; }
grep -q '^ID=cachyos' /etc/os-release || { echo "this is not CachyOS -- refusing" >&2; exit 1; }

cd "$here/rootfs"
find . -type f | while read -r f; do
    f=${f#./}
    case "$f" in
        etc/initcpio/install/nixguard|etc/initcpio/hooks/nixguard|usr/local/bin/nixguard-check|usr/lib/systemd/system-sleep/10-nixguard) mode=0755 ;;
        *) mode=0644 ;;
    esac
    install -D -m "$mode" "$f" "/$f"
done

systemctl enable nixguard-clear-grubenv.service
[ "${1:-}" = "--no-initramfs" ] || mkinitcpio -P
echo "nixguard installed."
