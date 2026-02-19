# FungiVue: NixOS Ultrasound Mushroom Growth Imaging System

![FungiVue Logo](docs/images/logo.png)

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![NixOS Unstable](https://img.shields.io/badge/NixOS-Unstable-blue.svg)](https://nixos.org)

## Overview

FungiVue is an open-source, NixOS-based system for non-invasive ultrasound imaging of mushroom (mycelium) growth. This repository contains declarative NixOS configurations for deploying on Single Board Computers (SBCs) including the Orange Pi Zero 2W and Raspberry Pi Zero 2W.

## Hardware Support

| Board | SoC | Architecture | Status |
|-------|-----|--------------|--------|
| **Orange Pi Zero 2W** | Allwinner H618 (4x Cortex-A53) | aarch64 | Tested |
| **Raspberry Pi Zero 2W** | Broadcom BCM2710A1 (4x Cortex-A53) | aarch64 | Supported |
| **x86 Development** | Any x86_64 | x86_64 | Development |

## Quick Start

### Prerequisites

- NixOS with flake support
- For SBC builds: AArch64 emulation (QEMU) on x86_64 host
- MicroSD card (16GB+)

### Build Instructions

```bash
# Clone and enter the repository
git clone https://github.com/ALH477/FungiVue.git
cd FungiVue

# Build for Orange Pi Zero 2W
nix build .#nixosConfigurations.opi-zero2w.config.system.build.sdImage

# Build for Raspberry Pi Zero 2W  
nix build .#nixosConfigurations.rpi-zero2w.config.system.build.sdImage

# Development build (x86_64)
sudo nixos-rebuild switch --flake .#fungivue-dev
```

### Flash to SD Card

```bash
# Replace /dev/sdX with your SD card device
sudo dd if=result/sd-image/nixos-image-*.img of=/dev/sdX bs=4M status=progress conv=fsync
```

## System Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    FungiVue System                       │
├─────────────────────────────────────────────────────────┤
│  Hardware Layer                                          │
│  ├── Arduino (Ultrasound HC-SR04, DHT22 sensors)        │
│  └── SBC (OPI Zero 2W / RPi Zero 2W)                    │
├─────────────────────────────────────────────────────────┤
│  Data Acquisition Layer                                 │
│  └── Python imaging_script.py                           │
│      ├── Serial communication (/dev/ttyUSB0)            │
│      ├── A-scan visualization (matplotlib)              │
│      └── JSON metadata output                           │
├─────────────────────────────────────────────────────────┤
│  Presentation Layer                                     │
│  ├── Vue.js Dashboard (SPA)                             │
│  └── NGINX Web Server                                    │
├─────────────────────────────────────────────────────────┤
│  Optional AI Layer                                      │
│  └── Ollama (local LLM inference)                        │
└─────────────────────────────────────────────────────────┘
```

## Features

- **Declarative NixOS Configuration**: Reproducible system setup via Nix flakes
- **Ultrasound Imaging**: A-scan visualization for mycelium growth monitoring
- **Vue.js Dashboard**: Responsive web interface for viewing scan results
- **Serial Communication**: Arduino sensor integration via USB
- **Docker Support**: Containerized components with socket activation
- **AI Integration**: Ollama for local LLM inference (ARM64 optimized)
- **USB Gadget Mode**: Network access via USB-C on OPI Zero 2W

## Directory Structure

```
FungiVue/
├── flake.nix                 # Main NixOS flake (multi-board support)
├── modules/                  # Reusable NixOS modules
│   ├── default.nix          # Main module entry
│   ├── fungivue.nix         # Core FungiVue configuration
│   ├── hardware.nix         # Arduino/serial connectivity
│   └── nginx.nix            # Web server configuration
├── src/
│   ├── python/              # Imaging scripts
│   │   └── imaging_script.py
│   └── vue/                 # Vue.js webapp
│       ├── src/
│       │   ├── main.js
│       │   └── App.vue
│       ├── package.json
│       ├── vite.config.js
│       └── index.html
├── FungiVue/                # Legacy FungiVue components
│   ├── etc/
│   │   ├── nginx.conf
│   │   └── nixos/
│   └── src/
└── opi-zero2w-nixos/       # Original OPI NixOS flake (legacy)
```

## Configuration Options

### NixOS Module Options

```nix
# Enable FungiVue
fungivue.enable = true;

# Configure paths
fungivue.scanDirectory = "/var/www/scans";
fungivue.arduinoPort = "/dev/ttyUSB0";

# Enable components
fungivue.hardware.enable = true;
fungivue.nginx.enable = true;
fungivue.nginx.enableAPI = true;

# Optional features
fungivue.hardware.enableDocker = true;
fungivue.hardware.enableAI = true;
```

### Running the Imaging Script

```bash
# Basic usage
sudo fungivue-imaging

# With custom settings
sudo fungivue-imaging -p /dev/ttyUSB0 -o /var/www/scans -i 60
```

Options:
- `-p, --port`: Serial port (default: /dev/ttyUSB0)
- `-o, --output`: Output directory (default: /var/www/scans)
- `-i, --interval`: Scan interval in seconds (default: 60)
- `-m, --model`: TensorFlow Lite model path (optional)

### Web Dashboard

Access the Vue.js dashboard at:
- Orange Pi: `http://opi-fungivue.local` or `http://10.0.0.1` (USB gadget)
- Raspberry Pi: `http://rpi-fungivue.local`

Scans are served from `/scans/` endpoint.

## Arduino Setup

### Wiring

| Sensor | Arduino Pin | Description |
|--------|-------------|-------------|
| HC-SR04 Trig | Pin 9 | Ultrasound trigger |
| HC-SR04 Echo | Pin 10 | Ultrasound echo |
| DHT22 Data | Pin 2 | Temp/humidity |
| VCC | 5V | Power |
| GND | GND | Ground |

### Upload Sketch

```bash
arduino-cli compile -p /dev/ttyUSB0 --fqbn arduino:avr:uno src/arduino/ultrasound_sketch.ino
arduino-cli upload -p /dev/ttyUSB0 --fqbn arduino:avr:uno src/arduino/ultrasound_sketch.ino
```

## Network Configuration

### Orange Pi Zero 2W (USB Gadget Mode)

The OPI Zero 2W is configured with USB gadget networking:
- **USB IP**: `10.0.0.1/24`
- **Host IP**: `10.0.0.2`
- **Discovery**: `opi-fungivue.local` (mDNS)

### Raspberry Pi Zero 2W

Standard network configuration via Ethernet or WiFi.

## Troubleshooting

### No Arduino Data

```bash
# Check device
dmesg | grep tty

# Verify permissions
ls -la /dev/ttyUSB0
sudo usermod -aG dialout $USER
```

### Webapp Not Loading

```bash
# Check NGINX status
sudo systemctl status nginx

# Verify file permissions
ls -la /var/www/fungi-vue/
ls -la /var/www/scans/
```

### Build Errors

```bash
# For AArch64 builds, ensure QEMU is installed
nix run nixpkgs#qemu-u-boot -- --version
```

## Development

### Local Development

```bash
# Enter development shell
nix develop

# Build Vue.js app
cd src/vue
npm install
npm run build
```

### Testing

```bash
# Evaluate NixOS configuration
nix eval .#nixosConfigurations.opi-zero2w.config.system.build.toplevel

# Check configuration
nix flake show
```

## License

MIT License - See [LICENSE](LICENSE) for details.

## Acknowledgments

- NixOS community
- Allwinner H618 mainline kernel support
- Suckless DWM
- Vue.js framework
