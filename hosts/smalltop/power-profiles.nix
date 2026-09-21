# Power profiles over DBus on samsung_galaxybook's ACPI platform_profile; laptop-only (PPD takes cpufreq policy), never with TLP.
{ ... }:

{
  powerManagement.enable = true;
  services.power-profiles-daemon.enable = true;
  services.upower.enable = true;

  # Intel thermal daemon (RAPL/DPTF); keeps sustained clocks under thermal load.
  services.thermald.enable = true;

  # Lid closed on AC keeps running (remote work); on battery it still suspends.
  services.logind.settings.Login.HandleLidSwitchExternalPower = "ignore";
}
