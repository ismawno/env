# smalltop audio preferences. Base stack and options: ../modules/audio.nix
{ ... }:

{
  imports = [ ../modules/audio.nix ];

  mad.audio = {
    support32Bit = true;

  };

  # ALC298 4-amp quirk for 144d:c886 is upstream since 6.12.

}
