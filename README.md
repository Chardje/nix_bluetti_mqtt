# Bluetti MQTT — NixOS Module

This fork adds a NixOS flake module to [semitop7/bluetti_mqtt](https://github.com/semitop7/bluetti_mqtt),
which itself is a fork of [warhammerkid/bluetti_mqtt](https://github.com/warhammerkid/bluetti_mqtt).

The original forks replace `asyncio-mqtt` with `aiomqtt` and update required libraries to latest versions.
This fork adds a NixOS-native way to run the bridge — without Docker or the Home Assistant Add-on Store.

![Supports aarch64 Architecture](https://img.shields.io/badge/aarch64-yes-green.svg)
![Supports amd64 Architecture](https://img.shields.io/badge/amd64-yes-green.svg)
![Last Updated](https://img.shields.io/github/last-commit/Chardje/bluetti_mqtt?label=Last%20Updated)

---

## What is this?

A NixOS module that runs `bluetti_mqtt` as a systemd service — an MQTT bridge between
your Bluetti power station and Home Assistant.
---

## Installation

Add this flake to your NixOS configuration:

**`flake.nix`**:
```nix
inputs = {
  bluetti-mqtt.url = "github:Chardje/bluetti_mqtt";
};

outputs = { self, nixpkgs, bluetti-mqtt }: {
  nixosConfigurations.yourhostname = nixpkgs.lib.nixosSystem {
    modules = [
      ./configuration.nix
      bluetti-mqtt.nixosModules.default
    ];
  };
};
```

**`configuration.nix`**:
```nix
services.bluetti-mqtt = {
  enable = true;
  btMac = "AA:BB:CC:DD:EE:FF";  # your device MAC address
  mqttHost = "127.0.0.1";
  pollSec = 30;
};
```

---

## Finding your device MAC address

```bash
sudo nix run github:Chardje/nix_bluetti_mqtt -- --scan --debug
```

Copy the MAC address, disable `scan` and set `btMac`.

---

## Configuration options

| Option | Type | Default | Description |
|---|---|---|---|
| `enable` | bool | `false` | Enable the service |
| `btMac` | string | `null` | MAC address(es), space-separated |
| `scan` | bool | `false` | Scan for nearby devices |
| `mqttHost` | string | `""` | MQTT broker host |
| `mqttPort` | string | `""` | MQTT broker port |
| `mqttUsername` | string | `null` | MQTT username |
| `mqttPassword` | string | `null` | MQTT password |
| `mode` | enum | `mqtt` | `mqtt` / `discovery` / `logger` |
| `pollSec` | int | `30` | Polling interval in seconds |
| `haConfig` | enum | `normal` | `normal` / `none` / `advanced` |
| `debug` | bool | `false` | Enable debug logging |

---

## Credits

- Original package: [warhammerkid/bluetti_mqtt](https://github.com/warhammerkid/bluetti_mqtt)
- HA add-on fork: [semitop7/bluetti_mqtt](https://github.com/semitop7/bluetti_mqtt)
- NixOS module: [Chardje/bluetti_mqtt](https://github.com/Chardje/bluetti_mqtt)s