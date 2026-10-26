{
  programs.coolercontrol.enable = true;

  # Super I/O fan headers and per-core temperatures for coolercontrol.
  boot.kernelModules = [
    "nct6775"
    "coretemp"
  ];
}
