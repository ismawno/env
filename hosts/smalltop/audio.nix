# smalltop audio preferences. Base stack and options: ../modules/audio.nix
{ ... }:

{
  imports = [ ../modules/audio.nix ];

  mad.audio.support32Bit = true;

  # The ALC298 clicks on every hardware volume step, so the speakers are attenuated in software instead.
  services.pipewire.wireplumber.extraConfig."53-speaker-soft-mixer"."monitor.alsa.rules" = [
    {
      matches = [
        { "node.name" = "alsa_output.pci-0000_00_1f.3-platform-skl_hda_dsp_generic.HiFi__Speaker__sink"; }
      ];
      actions.update-props."api.alsa.soft-mixer" = true;
    }
  ];
}
