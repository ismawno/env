# Hibernation interlock: stops one distro mounting the shared btrfs read-write
# while the other holds an unresumed image. INERT until mad.interlock.enable.
{ config, lib, pkgs, ... }:

let
  vg = "smalltop";
  otherSwap = "/dev/${vg}/cachyos-swap";
  # LVM doubles the hyphen; systemd escapes '-' as \x2d. Both transformations apply.
  otherSwapUnit = "dev-mapper-${vg}-cachyos\\x2d\\x2dswap.device";

  grubenv = "/boot/grub/grubenv";
  editenv = "${pkgs.grub2_efi}/bin/grub-editenv";

  espUuid = "E0B5-66AA";
  luksUuid = "614ffd30-49b3-440d-962b-cc126ef81ace";

  # UUIDs, never /dev/mapper paths (LVM doubles the hyphen); mkswap -U keeps this one stable.
  cachySwapUuid = "34d80d30-ccf4-466a-99cb-d1f44e68dc6d";
  btrfsUuid = "f56c0f23-9405-47ff-b777-8feb3974ff98";

  # Strict: anything but SWAPSPACE2 refuses. False only while cachyos-swap is unformatted.
  strictGate = true;

  cachyDir = "";   # CachyOS kernel + initramfs live at the ESP root
  cachyCmdline =
    "cryptdevice=UUID=${luksUuid}:smalltop_crypt root=UUID=${btrfsUuid} "
    + "rootflags=subvol=@cachyos rw resume=UUID=${cachySwapUuid} quiet splash";

  cachyBody = ''
    insmod part_gpt
    insmod fat
    search --no-floppy --fs-uuid --set=root ${espUuid}
    linux ${cachyDir}/vmlinuz-linux-cachyos ${cachyCmdline}
    initrd ${cachyDir}/initramfs-linux-cachyos.img'';

  # Shown alone while a distro is hibernated; functions are not inherited, hence full bodies.
  fullMenuEntry = ''
    menuentry "Full Menu" --class submenu {
      set interlock_full_menu=1
      export interlock_full_menu
      configfile ''${prefix}/grub.cfg
    }'';
  cachyosHibernatedMenu = pkgs.writeText "cachyos-hibernated.cfg" ''
    set default=0
    set timeout=1
    menuentry "CachyOS (resume from hibernation)" --class cachyos --class gnu-linux --class os {
    ${cachyBody}
    }
    ${fullMenuEntry}
  '';
  # NixOS kernel paths change per generation, so re-enter grub.cfg and auto-boot its default.
  nixosHibernatedMenu = pkgs.writeText "nixos-hibernated.cfg" ''
    set default=0
    set timeout=1
    menuentry "NixOS (resume from hibernation)" --class nixos {
      set interlock_autoboot=1
      export interlock_autoboot
      configfile ''${prefix}/grub.cfg
    }
    ${fullMenuEntry}
  '';

  sysdInitrd = config.boot.initrd.systemd.enable;

  clearFlag = ''
    if ${editenv} ${grubenv} list | grep -q '^nixos_hib='; then
      ${editenv} ${grubenv} unset nixos_hib && sync -f /boot/grub \
        || echo "interlock: could not clear nixos_hib in ${grubenv}" >&2
    fi
  '';

  # LV activation is asynchronous. 60s is well past a human-paced passphrase entry.
  waitForOther = ''
    interlockDev=${otherSwap}
    interlockTry=60
    while [ $interlockTry -gt 0 ]; do
      if [ -e "$interlockDev" ]; then break; fi
      udevadm settle --timeout=2
      sleep 1
      interlockTry=$((interlockTry - 1))
    done
  '';

  readMagic = ''dd if="$interlockDev" bs=1 skip=4086 count=10 2>/dev/null | tr -d "\0"'';

  refusalText = ''
    echo ""
    echo "=============================================================="
    echo " HIBERNATION INTERLOCK"
    echo " ${otherSwap} holds a hibernation image."
    echo " Mounting the shared btrfs or the shared ESP read-write would"
    echo " corrupt it. Boot CachyOS, resume, shut it down cleanly -- or"
    echo " abandon the image (see the note, Layer 4)."
    echo "=============================================================="
    echo ""
  '';

  gateScript = ''
    ${waitForOther}
    if [ ! -e "$interlockDev" ]; then
      echo "interlock: $interlockDev ABSENT after 60s -- PASSING WITHOUT CHECK"
      ${lib.optionalString strictGate ''exit 1''}
      exit 0
    fi
    interlockMagic=$(${readMagic})
    case "$interlockMagic" in
      SWAPSPACE2) exit 0 ;;
      S1SUSPEND)  ${refusalText} exit 1 ;;
      *)
        echo "interlock: $interlockDev magic is '$interlockMagic', not SWAPSPACE2 -- PASSING WITHOUT CHECK"
        ${lib.optionalString strictGate ''exit 1''}
        exit 0
        ;;
    esac
  '';
in
{
  options.mad.interlock.enable = lib.mkEnableOption ''
    the hibernation interlock. Leave OFF until CachyOS is installed and
    cachyos-swap is formatted -- before that it guards nothing and can only
    misfire'';
  config = lib.mkIf config.mad.interlock.enable {
  assertions = [
    {
      assertion = config.powerManagement.enable;
      message = "hibernation-interlock: powerManagement.enable must stay true; resumeCommands clears the layer 1 flag.";
    }
  ];

  # Without this the initrd root shadow entry is "*" and a layer 2 refusal leaves a prompt nobody can log into.
  boot.initrd.systemd.emergencyAccess = true;

  # LAYER 3 + LAYER 1 (set): required by the hibernate services, so exit 1 aborts them.
  systemd.services.hibernation-interlock = {
    description = "Hibernation interlock gate (layers 3 and 1)";
    before = [
      "sleep-actions.service"
      "sleep.target"
      "systemd-hibernate.service"
      "systemd-hybrid-sleep.service"
      "systemd-suspend-then-hibernate.service"
    ];
    requiredBy = [
      "systemd-hibernate.service"
      "systemd-hybrid-sleep.service"
      "systemd-suspend-then-hibernate.service"
    ];
    serviceConfig.Type = "oneshot";
    script = ''
      interlockDev=${otherSwap}
      if [ -e "$interlockDev" ]; then
        if [ "$(${readMagic})" = S1SUSPEND ]; then
          echo "interlock: $interlockDev holds a hibernation image; refusing to hibernate." >&2
          exit 1
        fi
      fi
      # Layer 1 is UX only: a failed grubenv write must not abort an otherwise safe sleep.
      ${editenv} ${grubenv} set nixos_hib=yes && sync -f /boot/grub \
        || echo "interlock: could not set nixos_hib in ${grubenv}" >&2
    '';
  };

  # mkBefore: sleep-actions' preStop runs under set -e and the clear must not be skippable.
  powerManagement.resumeCommands = lib.mkBefore clearFlag;

  # LAYER 1 (clear) on cold boot and on clean shutdown.
  systemd.services.hibernation-interlock-clear = {
    description = "Clear the NixOS hibernation flag in grubenv";
    wantedBy = [ "multi-user.target" ];
    after = [ "local-fs.target" ];
    restartIfChanged = false;
    serviceConfig = { Type = "oneshot"; RemainAfterExit = true; };
    script = clearFlag;
    preStop = clearFlag;
  };

  # LAYER 2, systemd stage 1 (the 26.05 default). Failing it fails sysroot.mount's job.
  boot.initrd.systemd.services = lib.optionalAttrs sysdInitrd {
    hibernation-interlock = {
      description = "Hibernation interlock gate (layer 2)";
      # cryptsetup.target is the sanctioned hook; the 60s poll is the real synchronisation.
      after = [ "cryptsetup.target" otherSwapUnit ];
      before = [ "sysroot.mount" ];
      requiredBy = [ "sysroot.mount" ];
      unitConfig.DefaultDependencies = false;
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        StandardOutput = "journal+console";
        StandardError = "journal+console";
      };
      script = gateScript;
    };
  };

  # LAYER 2, scripted stage 1. Runs after `lvm vgchange -ay`, long before any root mount.
  boot.initrd.postDeviceCommands = lib.mkIf (!sysdInitrd) (lib.mkAfter ''
    (
    ${gateScript}
    ) || {
      fail
      # fail()'s "*" branch RETURNS and would let stage 1 mount root. Never fall through.
      echo "interlock: rebooting in 10s"
      sleep 10
      reboot -f
    }
  '');

  # ---- LAYER 1 (GRUB) and the CachyOS entries ----

  environment.systemPackages = [ pkgs.grub2_efi ];   # grub-editenv; the module contributes
                                                     # none of its own when device = "nodev"

  boot.loader.grub = {
    enable = true;
    efiSupport = true;
    efiInstallAsRemovable = true;
    device = "nodev";
    copyKernels = true;
    useOSProber = false;          # structurally cannot find CachyOS here -- see §1
    configurationLimit = 10;      # NixOS gens + the CachyOS pair must fit in 2 GiB
    extraEntriesBeforeNixOS = false;

    # insmods are documentation: GRUB's normal mode autoloads all of these from command.lst.
    extraConfig = ''
      insmod part_gpt
      insmod fat
      insmod search_fs_uuid
      insmod loadenv
      insmod test
      insmod sleep

      # Explicit about which variables are whitelisted; absent or empty means allow.
      if [ -s ''${prefix}/grubenv ]; then
        load_env -f ''${prefix}/grubenv nixos_hib cachyos_hib
      fi

      # A hibernated distro gets a two-entry menu (resume / Full Menu); ESC also falls through.
      if [ "''${cachyos_hib}" = "yes" ]; then
        set default=cachyos
      fi
      if [ "''${interlock_autoboot}" = "1" ]; then
        set timeout=0
      elif [ "''${interlock_full_menu}" != "1" ]; then
        if [ "''${cachyos_hib}" = "yes" ]; then
          configfile ''${prefix}/cachyos-hibernated.cfg
        elif [ "''${nixos_hib}" = "yes" ]; then
          configfile ''${prefix}/nixos-hibernated.cfg
        fi
      fi
    '';

    # Not offered while NixOS is hibernated; any NixOS boot clears a stale flag.
    extraEntries = ''
      if [ "''${nixos_hib}" != "yes" ]; then
      menuentry "CachyOS" --class cachyos --class gnu-linux --class os --id cachyos {
        ${cachyBody}
      }
      fi
    '';

    # Not extraFiles: that is copied on every rebuild; this only when it changed.
    extraPrepareConfig = ''
      for f in ${cachyosHibernatedMenu}:cachyos-hibernated.cfg ${nixosHibernatedMenu}:nixos-hibernated.cfg; do
        cmp -s "''${f%%:*}" "/boot/grub/''${f##*:}" || cp "''${f%%:*}" "/boot/grub/''${f##*:}"
      done
    '';

    # Advisory, never a block: install-grub.pl injects this into every entry, so a loop here deadlocks an unattended boot.
    extraPerEntryConfig = ''if [ "''${cachyos_hib}" = "yes" ]; then echo ""; echo "  WARNING: CachyOS holds an unresumed hibernation image."; echo "  The initrd gate will refuse this boot. Press ESC to return to the menu."; sleep --interruptible 10; fi'';
  };
  };
}

