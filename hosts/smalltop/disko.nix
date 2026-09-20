# Disk layout for smalltop. RUNNING DISKO AGAINST THIS DESTROYS THE DISK.
# ESP 2G; LUKS2 -> vg smalltop -> swap 20G, cachyos-swap 20G, root btrfs.
{ ... }:

let
  # Stable by-id path. Never /dev/nvme0n1 -- enumeration order is not a contract.
  diskDevice = "/dev/disk/by-id/nvme-KINGSTON_SNV2S1000G_50026B7382E2A171";

  # Stable by-id path; enumeration order is not a contract.
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
          # 2 GiB: GRUB, several NixOS generations and the CachyOS kernel all live here.
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
              # No keyFile: disko prompts at format time, so the passphrase never reaches the repo.
              settings = {
                # Lets btrfs's discard=async reach the NVMe; reveals unused blocks.
                allowDiscards = true;
                # bypassWorkqueues: faster on NVMe, slightly weaker against a physically present attacker.
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
        # 20 GiB for 16 GiB of RAM: hibernation image plus swap headroom.
        nixos-swap = {
          size = "20G";
          content = {
            type = "swap";
            # A real LV, not a btrfs swapfile: disko computes no resume_offset for those.
            resumeDevice = true;
            # Discard once at swapon; per-page discard is churn on a DRAM-less drive.
            discardPolicy = "once";
            priority = 100;
          };
        };

        # Reserved for CachyOS: no content, so disko leaves the LV unsignatured.
        cachyos-swap = {
          size = "20G";
        };

        root = {
          # Not 100%: ~8 GiB stays free in the VG as lvextend headroom for the shared btrfs pool.
          size = "99%FREE";
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
              # /nix is in pathsNeededForBoot, so stage 1 mounts it automatically.
              "@nix" = {
                mountpoint = "/nix";
                mountOptions = btrfsMountOptions;
              };
              # Shared data subvolume; unrelated to hosts/nomad/.
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
