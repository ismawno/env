# Charge limit 80 while the OS runs and 100 while it is off; a hibernate is a full power-off here, so redo what the firmware forgets.
{ pkgs, ... }:

let
  limit = "/sys/class/power_supply/BAT1/charge_control_end_threshold";
  sound = "0000:00:1f.3";
  soundDriver = "/sys/bus/pci/drivers/sof-audio-pci-intel-tgl";
  sleepTargets = [
    "hibernate.target"
    "hybrid-sleep.target"
    "suspend-then-hibernate.target"
  ];

  # An unreadable limit means the firmware lost power: samsung_galaxybook and the speaker amps need a fresh probe, the clock a re-sync.
  afterHibernate = pkgs.writeShellScript "after-hibernate" ''
    if [ "''${1:-}" = force ] || ! cat ${limit} >/dev/null 2>&1; then
      ${pkgs.kmod}/bin/modprobe -r samsung_galaxybook; ${pkgs.kmod}/bin/modprobe samsung_galaxybook
      [ -e ${soundDriver}/${sound} ] && echo ${sound} > ${soundDriver}/unbind
      sleep 1
      systemctl --no-block restart systemd-timesyncd
    fi
    [ -e ${soundDriver}/${sound} ] || echo ${sound} > ${soundDriver}/bind
    rc=1
    for i in 1 2 3 4 5; do echo 80 > ${limit} 2>/dev/null && rc=0 && break; sleep 1; done
    for i in 1 2 3 4 5 6 7 8 9 10; do grep -q sof-hda-dsp /proc/asound/cards && exit $rc; sleep 1; done
    exit 1
  '';
in
{
  systemd.services.battery-cap = {
    description = "Battery charge limit: 80 while running, 100 when powered off";
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${pkgs.bash}/bin/sh -c 'echo 80 > ${limit}'";
      ExecStop = "${pkgs.bash}/bin/sh -c 'echo 100 > ${limit}'";
    };
  };

  systemd.services.before-hibernate = {
    description = "Let the battery charge to full while hibernated";
    wantedBy = [ "hibernate.target" ];
    before = [ "systemd-hibernate.service" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "-${pkgs.bash}/bin/sh -c 'echo 100 > ${limit}'";
    };
  };

  # Ordered after the sleep targets, so it runs once the resume is over and the user session is thawed.
  systemd.services.after-hibernate = {
    description = "Redo firmware handshake, speaker amps, charge limit and clock after hibernation";
    wantedBy = sleepTargets;
    after = sleepTargets;
    serviceConfig = {
      Type = "oneshot";
      ExecStart = afterHibernate;
      TimeoutStartSec = 60;
    };
  };

  services.upower = {
    percentageLow = 15;
    percentageCritical = 5;
    percentageAction = 3;
    criticalPowerAction = "Hibernate";
  };
}
