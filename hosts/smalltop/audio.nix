# smalltop audio preferences. Base stack and options: ../modules/audio.nix
{ ... }:

{
  imports = [ ../modules/audio.nix ];

  mad.audio.support32Bit = true;
}
