# Base audio stack plus the knobs a host may differ on. Hosts import this from
# their own hosts/<name>/audio.nix and set only mad.audio.* there.
{ config, lib, ... }:

let
  cfg = config.mad.audio;
in
{
  options.mad.audio = {
    support32Bit = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "32-bit ALSA support. Needed for Steam and older games.";
    };

    autoSwitchDefault = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Let sink priority pick the default output, so a headset takes over on
        connect and hands back on disconnect. Any `pactl set-default-sink`
        otherwise pins one permanently and defeats it -- the cost is that a
        manual pick no longer survives a restart.
      '';
    };

    sinkPriorities = lib.mkOption {
      type = lib.types.attrsOf lib.types.int;
      default = { };
      example = {
        "alsa_output.pci-0000_17_00.1.hdmi-stereo" = 1500;
      };
      description = ''
        Per-sink priority overrides, keyed by node.name (`pactl list short
        sinks`). Use when the output a host should default to does not already
        outrank its siblings. Higher wins.
      '';
    };
  };

  config = {
    security.rtkit.enable = true;
    services.pulseaudio.enable = false;

    services.pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = cfg.support32Bit;
      pulse.enable = true;
      wireplumber.enable = true;

      wireplumber.extraConfig = lib.mkMerge [
        (lib.mkIf (!cfg.autoSwitchDefault) {
          "51-pinned-default"."wireplumber.settings"."node.restore-default-targets" = true;
        })
        (lib.mkIf cfg.autoSwitchDefault {
          "51-no-pinned-default"."wireplumber.settings"."node.restore-default-targets" = false;
        })
        (lib.mkIf (cfg.sinkPriorities != { }) {
          "52-sink-priorities"."monitor.alsa.rules" = lib.mapAttrsToList (node: prio: {
            matches = [ { "node.name" = node; } ];
            actions.update-props = {
              "priority.session" = prio;
              "priority.driver" = prio;
            };
          }) cfg.sinkPriorities;
        })
      ];
    };
  };
}
