{
  # The AOC's native mode; this GTX 1080 firmware lists only 800x600, 1024x768 and 1280x1024 (videoinfo), so GRUB falls back to auto until it offers more.
  boot.loader.grub2-theme.screen = "4k";

  # nvidia is kept out of the initrd for hibernation, so Plymouth uses the firmware framebuffer as soon as it is above 1024x768.
  boot.kernelParams = [ "plymouth.use-simpledrm" ];
}
