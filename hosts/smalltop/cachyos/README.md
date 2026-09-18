# smalltop: CachyOS half of the hibernation interlock

Applies to **this host only**. NixOS and CachyOS share one btrfs and one ESP on
smalltop; whichever one is hibernated must not have them mounted read-write by
the other. `../hibernation-interlock.nix` is the NixOS half, this directory is
the CachyOS half, and `rootfs/` mirrors the paths it installs to.

    sudo sh install.sh      # on CachyOS; rebuilds the initramfs

The authoritative signal is the other distro's swap header (byte 4086:
`SWAPSPACE2` idle, `S1SUSPEND` holds an image). The grubenv flags are menu UX.
NixOS owns GRUB: never run grub-install or grub-mkconfig from CachyOS.
