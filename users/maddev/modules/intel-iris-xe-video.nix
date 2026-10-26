{ pkgs, ... }:

{
  # i915 is what binds 8086:a7a0 on 6.18; xe is present but does not claim it.
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
    extraPackages = with pkgs; [
      intel-media-driver # VA-API for Gen9+ (iHD)
      vpl-gpu-rt # oneVPL runtime, hardware encode
      libvdpau-va-gl
    ];
  };
  environment.sessionVariables.LIBVA_DRIVER_NAME = "iHD";
}
