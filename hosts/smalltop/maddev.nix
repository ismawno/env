# The flake loads hosts/<host>/<user>.nix by name; the body lives in users/maddev/modules.
{
  imports = [ ../../users/maddev/modules/smalltop-home.nix ];
}
