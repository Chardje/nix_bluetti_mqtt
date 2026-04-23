# NixOS module for Bluetti MQTT bridge
# Mirrors the configuration options from the original HA add-on config.yaml
#
# Original Python package by semitop7
# https://github.com/semitop7/bluetti_mqtt
# NixOS module and flake added by Chardje
# https://github.com/Chardje/bluetti_mqtt
{
  config,
  lib,
  pkgs,
  bluetti-pkg,
  ...
}: 

with lib;

let
  cfg = config.services.bluetti-mqtt;

  # Isolated Python environment with only required packages
  # Package source comes from flake.nix (this repo's own code)
  bluetti-python = pkgs.python3.withPackages (ps: [ bluetti-pkg ]);

  # MAC address validation regex matching the original add-on schema:
  # bt_mac: match(^([0-9A-Fa-f]{2}[:]){5}[0-9A-Fa-f]{2}( ([0-9A-Fa-f]{2}[:]){5}[0-9A-Fa-f]{2})*$)
  # Supports multiple space-separated MAC addresses
  macPattern = "^([0-9A-Fa-f]{2}[:]){5}[0-9A-Fa-f]{2}" + "( ([0-9A-Fa-f]{2}[:]){5}[0-9A-Fa-f]{2})*$";

  # Build CLI arguments from module options
  # Only include optional args when they are set (mirrors str? / password? schema types)
  args = concatStringsSep " " (
    optionals (cfg.mqttHost != "") [ "--broker ${cfg.mqttHost}" ]
    ++ optionals (cfg.mqttPort != "") [ "--port ${cfg.mqttPort}" ]
    ++ optionals (cfg.mqttUsername != null) [ "--username ${cfg.mqttUsername}" ]
    ++ optionals (cfg.mqttPassword != null) [ "--password ${cfg.mqttPassword}" ]
    ++ [ "--mode ${cfg.mode}" ]
    ++ [ "--poll-interval ${toString cfg.pollSec}" ]
    ++ [ "--ha-config ${cfg.haConfig}" ]
    ++ optionals cfg.scan [ "--scan" ]
    ++ optionals cfg.debug [ "--debug" ]
    # Only pass MAC when not scanning and btMac is set
    ++ optionals (!cfg.scan && cfg.btMac != null) [ cfg.btMac ]
  );

  # Output directory for discovery/logger modes (mirrors map: share:rw in config.yaml)
  shareDir = "/var/lib/bluetti2mqtt";

in
{
  options.services.bluetti-mqtt = {

    enable = mkEnableOption "Bluetti MQTT bridge";

    # Optional MQTT settings — leave empty to use a local Mosquitto broker
    # Mirrors: mqtt_host: str?, mqtt_port: str?, mqtt_username: str?, mqtt_password: password?

    mqttHost = mkOption {
      type = types.str;
      default = "";
      description = ''
        MQTT broker hostname or IP address.
        Leave empty when using a local Mosquitto broker on the same host.
      '';
    };

    mqttPort = mkOption {
      # Kept as string to match original schema type (str? not int)
      type = types.str;
      default = "";
      description = ''
        MQTT broker port.
        Leave empty to use the default port (1883).
      '';
    };

    mqttUsername = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "MQTT username. Leave null if authentication is not required.";
    };

    mqttPassword = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "MQTT password. Leave null if authentication is not required.";
    };

    # Required options — mirror the required fields in config.yaml

    mode = mkOption {
      type = types.enum [
        "mqtt"
        "discovery"
        "logger"
      ];
      default = "mqtt";
      description = ''
        Operation mode:
          mqtt      - Monitor and control Bluetti device(s) via MQTT (normal use).
          discovery - Reverse engineering mode, writes log files to ${shareDir}.
          logger    - Reverse engineering mode, writes log files to ${shareDir}.
        Note: discovery and logger modes do NOT publish to the MQTT broker.
      '';
    };

    pollSec = mkOption {
      type = types.int;
      default = 30;
      description = "Polling interval in seconds.";
    };

    haConfig = mkOption {
      type = types.enum [
        "normal"
        "none"
        "advanced"
      ];
      default = "normal";
      description = ''
        Home Assistant MQTT discovery configuration level:
          normal   - Most sensors and commands (recommended).
          none     - MQTT discovery disabled.
          advanced - More sensors and commands than normal (experimental).
        Note: switching from normal/advanced to none requires clearing
        retained messages from the broker to remove stale sensors.
      '';
    };

    btMac = mkOption {
      type = types.nullOr (types.strMatching macPattern);
      default = null;
      example = "AA:BB:CC:DD:EE:FF BB:CC:DD:EE:FF:00";
      description = ''
        MAC address(es) of the Bluetti device(s).
        Multiple addresses should be separated by a single space.
        Run with scan = true first to discover nearby devices.
      '';
    };

    scan = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Scan for nearby Bluetooth devices and print their MAC addresses to the journal.
        Enable temporarily to discover your device address, then disable and set btMac.
        Check output with: journalctl -u bluetti-mqtt -f
      '';
    };

    debug = mkOption {
      type = types.bool;
      default = false;
      description = "Enable debug logging. Check output with: journalctl -u bluetti-mqtt -f";
    };
  };

  config = mkIf cfg.enable {

    assertions = [
      {
        # Ensure the user has set a real MAC address when not in scan mode
        assertion = cfg.scan || cfg.btMac != null;
        message = ''
          services.bluetti-mqtt: set a real btMac address or enable scan mode first.
          Run: journalctl -u bluetti-mqtt -f  to see discovered devices.
        '';
      }
    ];

    # Create output directory for discovery/logger log files
    # Mirrors: map: share:rw in the original add-on config.yaml
    systemd.tmpfiles.rules = [
      "d ${shareDir} 0755 root root -"
    ];

    systemd.services.bluetti-mqtt = {
      description = "Bluetti to MQTT bridge";

      # Start after network, dbus (required for Bluetooth) and MQTT broker are ready
      after = [
        "network.target"
        "mosquitto.service"
        "dbus.service"
      ];
      wants = [ "mosquitto.service" ];
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        ExecStart = "${bluetti-python}/bin/bluetti-mqtt ${args}";
        Restart = "on-failure";
        RestartSec = "10s";

        # Required for Bluetooth access — mirrors host_dbus: true in config.yaml
        SupplementaryGroups = [ "bluetooth" ];

        # Working directory for discovery/logger output files
        WorkingDirectory = shareDir;
      };
    };
  };
}
