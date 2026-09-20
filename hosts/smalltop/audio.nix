# smalltop audio preferences. Base stack and options: ../modules/audio.nix
{ ... }:

{
  imports = [ ../modules/audio.nix ];

  mad.audio = {
    support32Bit = true;

  };

  # ALC298 4-amp quirk for 144d:c886 is upstream since 6.12.

  # Hibernate resume leaves the speakers silent with every register still correct;
  # only unbind+bind re-runs codec init. Verified across a real cycle 2026-09-16.
  powerManagement.resumeCommands = ''
    dev=0000:00:1f.3
    drv=/sys/bus/pci/drivers/sof-audio-pci-intel-tgl
    if [ -e "$drv/$dev" ]; then
      echo "$dev" > "$drv/unbind" && sleep 1 && echo "$dev" > "$drv/bind"
    fi
  '';
}
