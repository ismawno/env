# Power profiles over DBus, on the ACPI platform_profile samsung_galaxybook gives.
# Laptop-only: PPD takes cpufreq policy, wrong for bigsys. Never enable with TLP.
{ ... }:

{
  powerManagement.enable = true;
  services.power-profiles-daemon.enable = true;

  # Intel thermal daemon (RAPL/DPTF); keeps sustained clocks under thermal load.
  services.thermald.enable = true;

  # Battery/AC state for PPD and the desktop.
  services.upower.enable = true;
}
