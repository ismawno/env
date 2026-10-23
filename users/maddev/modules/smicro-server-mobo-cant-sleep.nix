# Supermicro X11SRA: ACPI offers no S3 and the GTX 1080 never wakes from s2idle, so bigsys hibernates instead.
{
  # RAM-sized; systemd-sleep hands its offset to the initrd in the HibernateLocation EFI variable, so no resume= is set.
  swapDevices = [
    {
      device = "/var/lib/swapfile";
      size = 64 * 1024;
    }
  ];

  # The LUKS prompt can outlast the 2-minute wait the EFI resume route otherwise puts on the root device.
  boot.kernelParams = [ "resumeflags=x-systemd.device-timeout=0" ];

  # Also rules out hybrid-sleep and suspend-then-hibernate, which pass through s2idle.
  systemd.sleep.settings.Sleep.AllowSuspend = false;

  services.logind.settings.Login.HandleSuspendKey = "hibernate";
}
