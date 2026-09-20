# bigsys audio preferences. Base stack and options: ../modules/audio.nix
{ ... }:

{
  imports = [ ../modules/audio.nix ];

  mad.audio = {
    support32Bit = true;

    # The GTX 1080's HDMI out is the speakers here, but it ranks 696 against the
    # onboard S/PDIF's 736 and would lose the default on every restart.
    sinkPriorities = {
      "alsa_output.pci-0000_17_00.1.hdmi-stereo" = 1500;
    };
  };
}
