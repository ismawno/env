# RAM-only rescue entry on the ESP; the USB route would pass the firmware prompt where F4 reimages the disk.
{ lib, pkgs, ... }:

let
  luksUuid = "614ffd30-49b3-440d-962b-cc126ef81ace";
  espUuid = "E0B5-66AA";
  vg = "smalltop";

  # Only this machines iwlwifi blobs: all of linux-firmware would not fit the shared ESP.
  wifiFirmware = pkgs.runCommand "smalltop-rescue-wifi-firmware" { } ''
    cd ${pkgs.linux-firmware}/lib/firmware
    find -L . -type f \( -name 'iwlwifi-so-a0-gf-a0-89.ucode*' -o -name 'iwlwifi-so-a0-gf-a0.pnvm*' \) \
      | while read -r f; do install -D -m 444 "$f" "$out/lib/firmware/$f"; done
    test -n "$(find $out -type f)"
  '';

  # Byte 4086 of a swap device: SWAPSPACE2 when idle, S1SUSPEND when it holds an image.
  magic = "dd if=\"$1\" bs=1 skip=4086 count=10 2>/dev/null | tr -d '\\0'";

  rescueOpen = pkgs.writeShellScriptBin "rescue-open" ''
    set -eu
    [ -e /dev/mapper/smalltop_crypt ] || cryptsetup open /dev/disk/by-uuid/${luksUuid} smalltop_crypt
    vgchange -ay ${vg} >/dev/null
    exec rescue-status
  '';

  rescueStatus = pkgs.writeShellScriptBin "rescue-status" ''
    m() { ${magic}; }
    for d in nixos-swap cachyos-swap; do
      dev=/dev/${vg}/$d
      if [ -b "$dev" ]; then
        case "$(m "$dev")" in
          SWAPSPACE2) echo "$d: idle" ;;
          S1SUSPEND)  echo "$d: HOLDS A HIBERNATION IMAGE" ;;
          *)          echo "$d: unknown header" ;;
        esac
      else
        echo "$d: not visible (run rescue-open)"
      fi
    done
    vgs -o vg_name,vg_size,vg_free ${vg} 2>/dev/null || true
  '';

  rescueMount = pkgs.writeShellScriptBin "rescue-mount" ''
    set -eu
    m() { ${magic}; }
    what=''${1:?usage: rescue-mount <@|@home|@nix|@nomad|@cachyos|...|top|esp> [rw]}
    mode=''${2:-ro}
    held=no
    for d in nixos-swap cachyos-swap; do
      [ "$(m /dev/${vg}/$d)" = SWAPSPACE2 ] || held=yes
    done
    if [ "$held" = yes ] && [ "$mode" = rw ]; then
      echo "REFUSING rw: a swap LV is not idle (see rescue-status). A hibernated kernel" >&2
      echo "still holds this filesystem in RAM; writing under it corrupts it on resume." >&2
      echo "Resume that OS and shut it down, or rescue-abandon its image first." >&2
      exit 1
    fi
    name=$(echo "$what" | tr -d '@'); [ -n "$name" ] || name=nixos-root
    mkdir -p "/mnt/$name"
    case "$what" in
      esp) mount -o "$mode" /dev/disk/by-uuid/${espUuid} "/mnt/$name" ;;
      top) mount -o "$mode$([ "$mode" = ro ] && echo ,rescue=nologreplay),subvolid=5" /dev/${vg}/root "/mnt/$name" ;;
      *)   mount -o "$mode$([ "$mode" = ro ] && echo ,rescue=nologreplay),subvol=$what" /dev/${vg}/root "/mnt/$name" ;;
    esac
    echo "mounted $what ($mode) at /mnt/$name"
  '';

  # Discards a hibernation image but keeps UUID and label, so resume=UUID= and fstab stay valid.
  rescueAbandon = pkgs.writeShellScriptBin "rescue-abandon" ''
    set -eu
    case "''${1:-}" in nixos|cachyos) ;; *) echo "usage: rescue-abandon <nixos|cachyos>" >&2; exit 1 ;; esac
    dev=/dev/${vg}/$1-swap
    uuid=$(blkid -s UUID -o value "$dev")
    echo "This DESTROYS the hibernated $1 session in $dev. Type YES to continue:"
    read -r a; [ "$a" = YES ] || exit 1
    mkswap -U "$uuid" -L "$1-swap" "$dev"
    echo "Also clear the menu flag:  rescue-mount esp rw && grub-editenv /mnt/esp/grub/grubenv unset $1_hib"
  '';

  rescue = pkgs.nixos (
    { modulesPath, ... }:
    {
      imports = [
        (modulesPath + "/installer/netboot/netboot.nix")
        (modulesPath + "/profiles/minimal.nix")
      ];

      networking.hostName = "smalltop-rescue";
      system.stateVersion = "26.05";

      boot.kernelPackages = pkgs.linuxPackages_6_18; # same kernel the keyboard is known to work on
      boot.kernelParams = [
        "nohibernate"
        "noresume"
      ];
      boot.initrd.availableKernelModules = [
        "xhci_pci"
        "nvme"
        "usb_storage"
        "usbhid"
        "sd_mod"
      ];
      boot.supportedFilesystems = [
        "btrfs"
        "vfat"
      ];

      hardware.enableRedistributableFirmware = false;
      hardware.firmware = [ wifiFirmware ];
      networking.networkmanager.enable = true; # no ethernet on this machine: nmtui

      console = {
        earlySetup = true;
        font = "ter-v32b"; # 215 DPI panel
        packages = [ pkgs.terminus_font ];
      };

      # Straight to a root shell: the image holds no secrets and the disk stays locked.
      services.getty.autologinUser = "root";
      users.users.root.initialHashedPassword = "";
      users.motd = ''

        smalltop rescue -- runs from RAM, cannot hibernate, has mounted nothing.

          rescue-open               unlock LUKS, activate the VG, show both swap states
          rescue-status             which distro (if any) holds a hibernation image
          rescue-mount <what> [rw]  @ @home @nix @nomad @cachyos ... top esp  -> /mnt/<what>
                                    rw is refused while any image is outstanding
          rescue-abandon <distro>   throw away a hibernation image (keeps the swap UUID)
          lvextend -L +4G smalltop/root && btrfs filesystem resize max /mnt/<what>
                                    hand the VG headroom to a full btrfs
          nixos-enter --root /mnt/nixos-root      (after mounting @ rw, @nix at nix, esp at boot)

      '';

      environment.systemPackages = [
        rescueOpen
        rescueStatus
        rescueMount
        rescueAbandon
      ]
      ++ (with pkgs; [
        cryptsetup
        lvm2
        btrfs-progs
        dosfstools
        e2fsprogs
        grub2_efi # grub-editenv
        gptfdisk
        nixos-install-tools # nixos-enter
        vim
        rsync
      ]);
    }
  );

  build = rescue.config.system.build;
  kernelFile = rescue.config.system.boot.loader.kernelFile;
  cmdline = "init=${build.toplevel}/init ${toString rescue.config.boot.kernelParams}";

  # Marker beside the files, so an unchanged image is not rewritten to the ESP on every rebuild.
  stamp = "${build.netbootRamdisk}";
in
{
  boot.loader.grub.extraPrepareConfig = ''
    if [ "$(cat /boot/rescue/source 2>/dev/null)" != "${stamp}" ]; then
      mkdir -p /boot/rescue
      cp ${build.kernel}/${kernelFile} /boot/rescue/kernel.new
      cp ${build.netbootRamdisk}/initrd /boot/rescue/initrd.new
      mv /boot/rescue/kernel.new /boot/rescue/kernel
      mv /boot/rescue/initrd.new /boot/rescue/initrd
      echo "${stamp}" > /boot/rescue/source
    fi
  '';

  boot.loader.grub.extraEntries = lib.mkAfter ''
    menuentry "Rescue (RAM-only NixOS: cannot hibernate, mounts nothing)" --class nixos --id rescue {
      insmod part_gpt
      insmod fat
      search --no-floppy --fs-uuid --set=root ${espUuid}
      linux /rescue/kernel ${cmdline}
      initrd /rescue/initrd
    }
  '';
}
