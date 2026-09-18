# Declarative disk layout for `smalltop` (Samsung Galaxy Book 3 Pro, NP960XFG).
#
# ---------------------------------------------------------------------------
# WARNING: running disko against this file DESTROYS everything on the disk.
# ---------------------------------------------------------------------------
#
# Physical layout
#
#   /dev/disk/by-id/nvme-KINGSTON_SNV2S1000G_50026B7382E2A171   (931.5 GiB)
#   |
#   +-- p1  "ESP"    2 GiB   EF00   vfat                      -> /boot
#   |
#   +-- p2  "luks"   rest    8309   LUKS2 container "cryptroot"
#           |
#           +-- LVM volume group "smalltop"
#               |
#               +-- lv "swap"          20 GiB   swap   <- NixOS hibernation target
#               +-- lv "cachyos-swap"  20 GiB   raw    <- reserved, see CACHYOS.md
#               +-- lv "root"          rest     btrfs
#                   |
#                   +-- subvol @        -> /
#                   +-- subvol @home    -> /home
#                   +-- subvol @nix     -> /nix
#                   +-- subvol @nomad   -> /nomad
#
# Why LVM inside the single LUKS container instead of several LUKS partitions:
#
#   * ONE passphrase prompt at boot, guaranteed. Hibernation needs a real swap
#     block device (not a btrfs swapfile, see below), and that device must be
#     encrypted. Giving swap its own LUKS partition would mean a second prompt
#     unless we cache the passphrase (systemd keyring, not guaranteed) or ship a
#     keyfile inside the initrd. The initrd lives on the *unencrypted* ESP, and
#     swap holds a verbatim image of RAM after hibernation, so a keyfile there
#     would defeat the whole point of the encryption. LVM sidesteps all of it.
#
#   * CachyOS (installed later, see hosts/smalltop/CACHYOS.md) gets its OWN swap
#     LV that is already inside the same LUKS container, so it is encrypted
#     "for free" with no extra unlock. NixOS must NEVER resume from it and vice
#     versa -- booting one distro while the other is hibernated corrupts the
#     image. Two separate LVs is the mechanical guarantee of that.
#
#   * Both distros share the free space of the "root" LV's btrfs pool. CachyOS
#     adds its own top-level subvolume (e.g. @cachyos) there; nothing is
#     pre-allocated, nothing has to be shrunk.
#
# NOTE ON THE NAME "@nomad": this is maddev's chosen name for the data subvolume
# that travels between NixOS and CachyOS. It has NOTHING to do with hosts/nomad/
# in this flake, which is an unrelated machine belonging to ismawno. Do not
# rename either by find-and-replace.
{ ... }:

let
  # Stable by-id path, verified present on the target. Never use /dev/nvme0n1
  # here: kernel enumeration order is not a contract.
  diskDevice = "/dev/disk/by-id/nvme-KINGSTON_SNV2S1000G_50026B7382E2A171";

  # Kingston NV2 (SM2267XT) is DRAM-less, so we care about bytes written.
  #   compress=zstd:1  cheap on a i7-1360P, cuts real writes substantially.
  #                    Level 1 rather than the default 3: the marginal ratio
  #                    gain is small and we would rather not stall writeback.
  #   noatime          removes a metadata write per read.
  #   discard=async    batched TRIM; needs allowDiscards on the LUKS layer.
  # Deliberately NOT set: autodefrag (rewrites extents = write amplification)
  # and discard=sync (stalls). ssd/space_cache=v2 are autodetected.
  btrfsMountOptions = [
    "compress=zstd:1"
    "noatime"
    "discard=async"
  ];
in
{
  disko.devices = {
    disk.main = {
      type = "disk";
      device = diskDevice;
      content = {
        type = "gpt";
        partitions = {
          # 2 GiB, not the old 1 GiB. GRUB + several NixOS generations' kernels
          # and initrds, plus CachyOS's own loader directory later, all live
          # here. Running an ESP out of space mid-rebuild is miserable.
          ESP = {
            priority = 1;
            name = "ESP";
            label = "smalltop-esp";
            size = "2G";
            type = "EF00";
            content = {
              type = "filesystem";
              format = "vfat";
              mountpoint = "/boot";
              mountOptions = [ "umask=0077" ];
            };
          };

          luks = {
            priority = 2;
            name = "luks";
            label = "smalltop-luks";
            size = "100%";
            type = "8309"; # Linux LUKS
            content = {
              type = "luks";
              name = "cryptroot"; # -> /dev/mapper/cryptroot
              # askPassword defaults to true here (no keyFile/passwordFile set),
              # so disko prompts interactively at format time. The passphrase is
              # never written to the repo or to disk.
              settings = {
                # Lets btrfs's discard=async actually reach the NVMe. Standard
                # SSD trade-off: reveals which blocks are unused.
                allowDiscards = true;
                # Skips dm-crypt's per-request workqueues. Meaningful win on
                # NVMe; documented as slightly weakening protection against a
                # physically present attacker who can watch I/O timing.
                bypassWorkqueues = true;
              };
              extraFormatArgs = [
                "--type luks2"
                "--pbkdf argon2id"
              ];
              content = {
                type = "lvm_pv";
                vg = "smalltop";
              };
            };
          };
        };
      };
    };

    lvm_vg.smalltop = {
      type = "lvm_vg";
      lvs = {
        # 20 GiB for 16 GiB of RAM. The hibernation image is at most RAM-sized
        # (and is compressed), so this leaves several GiB of genuine swap
        # headroom on top. The old install used 18 GiB.
        swap = {
          size = "20G";
          content = {
            type = "swap";
            # disko resolves this to /dev/smalltop/swap and emits
            # boot.resumeDevice pointing at the *decrypted* device. That is
            # exactly what hibernation needs, and it is why we are not using a
            # btrfs swapfile: disko computes no resume_offset for swapfiles,
            # so that route needs a hand-maintained magic number that silently
            # breaks whenever the file is recreated.
            resumeDevice = true;
            # Discard the whole area once at swapon. Continuous per-page
            # discard ("pages"/"both") is extra churn for a DRAM-less drive.
            discardPolicy = "once";
            priority = 100;
          };
        };

        # Reserved for CachyOS. No `content`, so disko creates the logical
        # volume and leaves it completely untouched -- no header, no signature,
        # and crucially no swapDevices/resumeDevice entry in the NixOS config.
        # It is already inside the LUKS container, so when CachyOS runs mkswap
        # on it that swap is encrypted without a second unlock.
        #
        # If CachyOS never happens: `lvremove smalltop/cachyos-swap` then
        # `lvextend -l +100%FREE smalltop/root && btrfs filesystem resize max /`
        # reclaims the space online.
        cachyos-swap = {
          size = "20G";
        };

        root = {
          size = "100%FREE";
          content = {
            type = "btrfs";
            extraArgs = [
              "-f"
              "-L"
              "smalltop"
            ];
            subvolumes = {
              "@" = {
                mountpoint = "/";
                mountOptions = btrfsMountOptions;
              };
              "@home" = {
                mountpoint = "/home";
                mountOptions = btrfsMountOptions;
              };
              # /nix is in nixpkgs' pathsNeededForBoot, so it is mounted in
              # stage 1 automatically; no explicit neededForBoot required.
              "@nix" = {
                mountpoint = "/nix";
                mountOptions = btrfsMountOptions;
              };
              # Shared data subvolume. See the note at the top of this file --
              # unrelated to hosts/nomad/.
              "@nomad" = {
                mountpoint = "/nomad";
                mountOptions = btrfsMountOptions;
              };
            };
          };
        };
      };
    };
  };
}
