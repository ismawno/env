# smalltop audio preferences. Base stack and options: ../modules/audio.nix
{ pkgs, ... }:

let
  parkLevels = pkgs.writeShellScript "sofhdadsp-park-levels" ''
    park() { ${pkgs.alsa-utils}/bin/amixer -c sofhdadsp -q sset "$@"; }
    park Master 0dB unmute
    park Capture 0dB cap
    park Dmic0 0dB cap
  '';
in
{
  imports = [ ../modules/audio.nix ];

  mad.audio.support32Bit = true;

  # The ALC298 clicks on every hardware volume step, so the whole card is attenuated in software instead.
  services.pipewire.wireplumber.extraConfig."53-speaker-soft-mixer"."monitor.alsa.rules" = [
    {
      matches = [ { "device.name" = "alsa_card.pci-0000_00_1f.3-platform-skl_hda_dsp_generic"; } ];
      actions.update-props."api.alsa.soft-mixer" = true;
    }
  ];

  # PipeWire then never sets the hardware levels, and the kernel starts them muted at minimum: 0 dB at every probe.
  services.udev.extraRules = ''
    ACTION=="add", SUBSYSTEM=="sound", KERNEL=="controlC*", ATTRS{id}=="sofhdadsp", RUN+="${parkLevels}"
  '';
}
