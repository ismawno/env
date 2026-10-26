{ config, lib, ... }:

{
  services.xserver.videoDrivers = [ "nvidia" ];
  hardware.nvidia = {
    modesetting.enable = true;
    # GTX 1080 (Pascal) was dropped by the 590+ drivers; 580 is its last supported branch. Pascal has no GSP, so its firmware is dead weight.
    package = config.boot.kernelPackages.nvidiaPackages.legacy_580;
    open = false;
    gsp.enable = false;
    powerManagement.enable = true;
  };
  # nvidia stays out of the initrd: there it refuses the quiesce a resume from hibernation needs.
  boot.kernelModules = [
    "nvidia"
    "nvidia_modeset"
    "nvidia_drm"
  ];
  boot.kernelParams = [
    "nvidia_drm.modeset=1"
    "nvidia_drm.fbdev=1"
  ];
  hardware.graphics.enable = lib.mkForce true;

  environment.sessionVariables = {
    LIBVA_DRIVER_NAME = "nvidia";
    GBM_BACKEND = "nvidia-drm";
    __GLX_VENDOR_LIBRARY_NAME = "nvidia";
    # The RDD file broker denies nvidia_drv_video.so /proc/version; Gecko 153 has no narrower pref.
    MOZ_DISABLE_RDD_SANDBOX = "1";
  };
}
