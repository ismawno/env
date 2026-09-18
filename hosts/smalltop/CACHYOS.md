# Installing CachyOS alongside NixOS on smalltop

Notes written **before** CachyOS was installed, while the layout decisions were
fresh. Nothing here has been executed. Read all of it before touching the disk.

The short version: CachyOS goes into a **new btrfs subvolume on the existing
filesystem**. Nothing is repartitioned, nothing is resized, no LUKS container is
created. The only pre-allocated resource CachyOS consumes is a logical volume
that already exists and is empty.

---

## 1. What is already on the disk

Created by `hosts/smalltop/disko.nix`:

```
/dev/disk/by-id/nvme-KINGSTON_SNV2S1000G_50026B7382E2A171   931.5 GiB
├─ p1  PARTLABEL smalltop-esp    2 GiB   EF00  vfat         -> /boot on NixOS
└─ p2  PARTLABEL smalltop-luks   rest    8309  LUKS2 container
      └─ (opened as) cryptroot
         └─ LVM volume group "smalltop"
            ├─ /dev/smalltop/swap           20 GiB  swap   ** NIXOS ONLY **
            ├─ /dev/smalltop/cachyos-swap   20 GiB  EMPTY  <- yours
            └─ /dev/smalltop/root           rest    btrfs, label "smalltop"
                  subvol @       -> /       (NixOS root)
                  subvol @home   -> /home   (NixOS home)
                  subvol @nix    -> /nix    (NixOS store)
                  subvol @nomad  -> /nomad  (shared data)
```

Two things about this that determine everything below:

**The volume group has ZERO free space.** The `root` LV was created with
`100%FREE`, so it consumed everything the `swap` and `cachyos-swap` LVs did not.
You cannot `lvcreate` anything new without shrinking something first, and you
should not want to: CachyOS gets a **subvolume**, not a logical volume. Its
files share the btrfs free-space pool with NixOS, which is the entire point —
neither OS has a fixed size and whichever one needs the space gets it.

**`/dev/smalltop/cachyos-swap` already exists and is deliberately empty.** disko
created the LV and wrote nothing to it. It is inside the LUKS container, so
anything you put there is encrypted with no second unlock and no extra
passphrase prompt.

> `@nomad` is the name of the shared data subvolume. It has **nothing** to do
> with `hosts/nomad/` elsewhere in this flake, which is an unrelated machine
> belonging to a different user. Do not let a find-and-replace conflate them.

---

## 2. The rule you must not break: separate swap

**NixOS and CachyOS must never share a swap device.**

Hibernation writes a verbatim image of RAM into swap and leaves the filesystem
in a state that only that image can resolve. If you boot the other distro while
one is hibernated, the other distro's `swapon` will happily scribble over that
image. Best case you lose the session. Worst case you resume into a kernel whose
idea of the filesystem is hours stale and it writes that back.

The layout above makes this structurally impossible rather than merely
discouraged:

- NixOS resumes from `/dev/smalltop/swap`. This is set by disko
  (`resumeDevice = true` on that LV) and evaluates to
  `boot.resumeDevice = "/dev/smalltop/swap"` — verified by `nix eval`, not
  assumed.
- `/dev/smalltop/cachyos-swap` appears **nowhere** in the NixOS configuration.
  Not in `swapDevices`, not in `boot.resumeDevice`, not in `fileSystems`. NixOS
  cannot use it because NixOS does not know it exists.
- CachyOS must use `cachyos-swap` and **must never** name `smalltop/swap` in its
  `/etc/fstab` or its `resume=` kernel parameter.

Check both sides after installing CachyOS:

```sh
# On NixOS
cat /proc/swaps                      # must show ONLY /dev/dm-* backing smalltop-swap
cat /proc/cmdline | tr ' ' '\n' | grep resume

# On CachyOS
cat /proc/swaps
cat /proc/cmdline | tr ' ' '\n' | grep resume
```

If the same device shows up on both, stop and fix it before hibernating
anything.

---

## 3. Unlock chain — how CachyOS reaches the disk

There is **one** LUKS container. Both systems open the same one with the same
passphrase. From a CachyOS live ISO:

```sh
# 1. Open the container. Name it whatever you like here; the installed system's
#    crypttab name is what matters long-term.
cryptsetup open /dev/disk/by-partlabel/smalltop-luks cryptroot

# 2. Bring up the volume group. LVM does not auto-activate reliably on a live ISO.
vgchange -ay smalltop
ls -l /dev/smalltop/          # expect: swap, cachyos-swap, root

# 3. Mount the btrfs TOP LEVEL (subvolid=5), not a subvolume. This is the only
#    view from which you can create and inspect sibling subvolumes.
mkdir -p /mnt/btrfs-top
mount -o subvolid=5 /dev/smalltop/root /mnt/btrfs-top
ls /mnt/btrfs-top             # expect: @  @home  @nix  @nomad
```

At this point `/mnt/btrfs-top/@` is NixOS's root. **Do not modify it.** Do not
`mkfs` anything. Do not touch `/dev/smalltop/swap` or `/dev/smalltop/root` as
whole devices.

For the installed CachyOS, the equivalent lives in `/etc/crypttab` and is
handled by the `encrypt`/`sd-encrypt` + `lvm2` mkinitcpio hooks. Both are
standard in CachyOS; no custom hook is needed.

---

## 4. Creating CachyOS's subvolumes

```sh
btrfs subvolume create /mnt/btrfs-top/@cachyos
btrfs subvolume create /mnt/btrfs-top/@cachyos-home    # optional; see below
```

`@cachyos-home` is a judgement call. Sharing `@home` between two distros means
sharing dotfiles between two different versions of every application, which
tends to end in corrupted profiles — Zen/Firefox and anything using GTK/dconf
are the usual casualties. **Give CachyOS its own home** and share deliberate
data through `@nomad` instead.

Mount for installation:

```sh
mount -o subvol=@cachyos,compress=zstd:1,noatime,discard=async \
      /dev/smalltop/root /mnt

mkdir -p /mnt/{home,boot,nomad}

mount -o subvol=@cachyos-home,compress=zstd:1,noatime,discard=async \
      /dev/smalltop/root /mnt/home

mount -o subvol=@nomad,compress=zstd:1,noatime,discard=async \
      /dev/smalltop/root /mnt/nomad

mount /dev/disk/by-partlabel/smalltop-esp /mnt/boot
```

Use the **same mount options** NixOS uses. `compress=zstd:1` in particular:
btrfs compression is per-extent, so mixing settings is not corrupting, but the
Kingston NV2 is DRAM-less and you want every writer compressing.

Swap:

```sh
mkswap -L cachyos-swap /dev/smalltop/cachyos-swap
swapon /dev/smalltop/cachyos-swap
```

That is the whole "give CachyOS its own swap" step. No `cryptsetup`, no
partitioning — the LV is already inside the encrypted container.

For hibernation on CachyOS, its kernel command line needs
`resume=/dev/smalltop/cachyos-swap` (or the equivalent `/dev/mapper/` path).
**Never** `/dev/smalltop/swap`.

---

## 5. Mounting `@nomad`

`@nomad` holds the data that is supposed to be visible from both systems. On
NixOS it is mounted at `/nomad`, with per-user subdirectories
(`/nomad/maddev/...`) bind-mounted into `$HOME`.

### `@nomad` is DATA ONLY — userspace is deliberately not shared

This is the governing decision for the whole dual-boot, so read it before you
"improve" anything below.

**Each distro keeps its own userspace.** Own browser profile, own Steam install,
own application state, own dotfiles. `@nomad` carries plain data and nothing
else: `~/Downloads`, `~/Documents`, `~/Knowledge` (the Obsidian vaults), and
some repos yet to be named.

The rationale is worth keeping because it is not obvious: if the gaming
experience is better on CachyOS, there is no reason to want the Steam library
visible from NixOS — and sharing application state is the thing that
manufactures every version-skew hazard in the first place. Not sharing it
dissolves that entire class of problem rather than managing it.

So: **no shared Steam library, no shared `~/.config/zen`, no shared
`~/.local/share/Steam`.** `~/.config/zen` was briefly approved for sharing and
that approval was withdrawn — it is application state, not data. Do not
reinstate any of these because they look like an easy win.

The test for anything new is: *is this data, or is this an application's state?*

Use the **same mountpoint** on CachyOS — `/nomad`. If the paths differ, every
symlink and every application config that references an absolute path breaks
when you switch OS.

`/etc/fstab` on CachyOS:

```
/dev/smalltop/root  /nomad  btrfs  subvol=@nomad,compress=zstd:1,noatime,discard=async  0 0
```

Then reproduce the bind mounts. On NixOS they are generated from the
`nomadBinds` table at the top of `hosts/smalltop/configuration.nix`; the CachyOS
equivalents go in `/etc/fstab`:

```
/nomad/maddev/Downloads  /home/<user>/Downloads   none  bind,nofail  0 0
/nomad/maddev/Documents  /home/<user>/Documents   none  bind,nofail  0 0
/nomad/maddev/Knowledge  /home/<user>/Knowledge   none  bind,nofail  0 0
```

One btrfs note that applies to any large game or media directory you put on
this filesystem, now or later: **Steam (and anything else using `fallocate()`)
defeats btrfs compression.** Preallocated extents are written uncompressed
regardless of the `compress=zstd:1` mount option, and only a manual
`btrfs filesystem defragment -r -czstd` pass will compress them afterwards —
which breaks reflinks, so never do it on a subvolume you snapshot. Measured
savings even after defragmenting are around 10% on a modern AAA title. Do not
expect compression to buy you anything on game data. It still earns its keep on
everything else, so the mount options stay as they are.

**UID/GID must match.** A bind mount does not translate ownership. If maddev is
uid 1000 on NixOS, make the CachyOS user uid 1000 too, or every file will show
up owned by a stranger. Check with `id -u` on both.

Syncthing deserves a specific warning: the two installs will have **different
syncthing device IDs** unless you deliberately share the state directory. Do not
share it. Two running instances answering to one device ID will fight. Either
run syncthing on NixOS only, or introduce the CachyOS instance to the mesh as
its own device. Since both write to the same files on `@nomad`, running both at
once is asking for conflict files — pick one.

---

## 6. Making GRUB find CachyOS

NixOS owns the bootloader. `hosts/smalltop/configuration.nix` sets
`boot.loader.grub.useOSProber = true`, and the shared `configuration.nix` sets
`efiSupport = true; device = "nodev"`, so GRUB installs into the ESP and never
writes to a raw block device.

After installing CachyOS, from NixOS:

```sh
sudo nixos-rebuild boot --flake /home/maddev/env#smalltop
```

That regenerates the GRUB config and runs os-prober.

### os-prober has real limitations here — expect to do this by hand

os-prober finds other systems by mounting candidate filesystems and looking for
`/etc/os-release` and a kernel. Against this layout it has to cope with:

- a btrfs filesystem whose OSes live in **non-default subvolumes** — os-prober
  mounts the default subvolume, which is NixOS's, so it may simply not see
  `@cachyos` at all;
- an **LVM LV inside a LUKS container**, which it will only see if the container
  is already open and the VG active when `grub-mkconfig` runs (it is, when you
  run the rebuild from a booted NixOS, so this part is usually fine).

The subvolume problem is the likely one. Before assuming it worked, check:

```sh
sudo os-prober
grep -i cachy /boot/grub/grub.cfg
```

If CachyOS is absent, add an explicit entry instead of fighting os-prober. In
`hosts/smalltop/configuration.nix`:

```nix
boot.loader.grub.extraEntries = ''
  menuentry "CachyOS" {
    insmod part_gpt
    insmod fat
    search --no-floppy --fs-uuid --set=root <ESP-UUID>
    chainloader /EFI/cachyos/grubx64.efi
  }
'';
```

Get `<ESP-UUID>` from `blkid /dev/disk/by-partlabel/smalltop-esp` (the `UUID=`,
which for vfat is the short `XXXX-XXXX` form). Chainloading CachyOS's own EFI
binary is more robust than trying to boot its kernel directly, because it
survives CachyOS kernel updates without a NixOS rebuild.

Both systems share one ESP. CachyOS installs to `/EFI/cachyos/`, NixOS to
`/EFI/NixOS-boot/` (or similar) — they do not collide. The 2 GiB ESP was sized
with exactly this in mind.

**Do not let the CachyOS installer take over the bootloader** if you want NixOS
to stay in charge. If it does anyway, boot NixOS (via the firmware boot menu,
F10/F12 at POST) and run `nixos-rebuild boot` to reinstate it.

---

## 7. Checklist before you start

- [ ] NixOS is fully installed, boots, and hibernates/resumes correctly.
- [ ] You have the LUKS passphrase written down. There is no keyfile and no
      recovery key — by design, since the initrd lives on the unencrypted ESP.
- [ ] `lvs smalltop` shows `cachyos-swap` present and unused.
- [ ] You have a backup of anything in `@nomad` that exists in only one place.
      Syncthing folders are already replicated elsewhere; the Zen profile is
      the item that is genuinely single-copy.
- [ ] You accept that CachyOS's installer may need to be driven in manual
      partitioning mode. Calamares does not understand "install into an
      existing btrfs subvolume"; you will likely mount everything by hand as in
      section 4 and point the installer at `/mnt`.

## 8. Things that will break it

- Running `mkfs` on `/dev/smalltop/root`. That is NixOS.
- Using `/dev/smalltop/swap` from CachyOS. See section 2.
- Letting the CachyOS installer "erase disk" or auto-partition.
- `lvremove`/`lvresize` on `swap` or `root`.
- Mounting `@nomad` at a different path on the two systems.
- Different UIDs for the same human on the two systems.
- Hibernating one OS and then booting the other. Even with separate swap, btrfs
  will be mounted read-write by the second OS while the first has a stale
  in-memory view of it. **Shut down properly before switching.** Separate swap
  protects the hibernation image; it does not make concurrent stale views safe.
