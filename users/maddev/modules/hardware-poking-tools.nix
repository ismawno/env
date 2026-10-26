{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    # Hardware poking, all read-only by default.
    pciutils
    usbutils
    nvme-cli
    btrfs-progs
    cryptsetup
    lvm2
    alsa-utils # aplay -l, amixer, speaker-test
    v4l-utils # v4l2-ctl --list-devices
    iw # iw reg get, to confirm the ES regdomain took
    powertop
    tpm2-tools
  ];
}
