# TBM — The Bitcoin Machine (Umbrel 1.x Compatible Fork)

> **This is an unofficial community fork** of [doidotech/TBM](https://github.com/doidotech/TBM), updated to work with **Umbrel OS 1.x** and **Pillow 10+**.
> The original project is no longer maintained and causes a **white screen of death (WSOD)** on all current Umbrel versions. This fork fixes that.

---

![TBM LCD Screen](https://raw.githubusercontent.com/baekchan-dev/TBM/master/Images/Main.jpg)

---

## Who Is This For?

The Bitcoin Machine was sold in 2022 and is no longer in production. If you are reading this, you almost certainly already have TBM installed from the original `doidotech/TBM` repository, and it stopped working after an Umbrel update.

**This fork is designed for exactly that situation.** The installation script automatically detects and removes the old service before setting up the new one. You do not need to manually uninstall anything first.

---

## Features

*   **Fixes the White Screen:** Resolves the WSOD caused by breaking changes in Umbrel 1.x and Pillow 10+.
*   **Automatic Migration:** `install.sh` detects and removes the legacy `UmbrelST7735LCD` service automatically.
*   **7 Information Screens:**
    1.  **Bitcoin Price** — Real-time price and sats/currency value with thousands separator.
    2.  **Next Block Info** — Estimated fees for the next block.
    3.  **Block Height** — Current Bitcoin block height.
    4.  **Date & Time** — System date and time.
    5.  **Network Info** — Umbrel IP address and network status.
    6.  **Lightning Channels** — Active/inactive channel count.
    7.  **Disk Usage** — Umbrel storage usage.
*   **Interactive Setup Wizard** — Guides you through timezone, screen selection, currency (46 supported), and screen duration.
*   **Smart Timezone Detection** — Auto-detects timezone from the system; manual override available.
*   **Auto-Start & Restart** — Runs as a `tbm-umbrel` systemd service, starting on boot and restarting after reconfiguration.

---

## Installation

All commands should be run on your Umbrel device after connecting via SSH.

### Step 1: Connect via SSH

```bash
ssh umbrel@umbrel.local
```

Enter your Umbrel dashboard password when prompted.

### Step 2: Clone This Repository

If you have an old TBM directory, rename it first to keep it as a backup:

```bash
mv ~/TBM ~/TBM-old   # optional: keep old files as backup
```

Then clone this fork:

```bash
git clone https://github.com/baekchan-dev/TBM.git
cd ~/TBM/app
```

### Step 3: Run the Installation Script

This script will:
- **Automatically stop and remove the old `UmbrelST7735LCD` service** (if present)
- Install all required Python libraries
- Enable the SPI interface

```bash
bash install.sh
```

### Step 4: Reboot

```bash
sudo reboot
```

### Step 5: Configure & Start the LCD Service

After rebooting, reconnect via SSH and run the setup wizard:

```bash
cd ~/TBM/app
bash configure.sh
```

The wizard will guide you through timezone confirmation, screen selection, currency, and screen duration. When finished, the service starts automatically.

**That's it — your LCD should now be working again.**

---

## Managing the Service

| Action | Command |
|--------|---------|
| Check logs | `sudo journalctl -u tbm-umbrel -f` |
| Restart service | `sudo systemctl restart tbm-umbrel` |
| Stop service | `sudo systemctl stop tbm-umbrel` |
| Re-run setup wizard | `bash ~/TBM/app/configure.sh` |

---

## Updating

```bash
cd ~/TBM
git stash
git pull
git stash drop
sudo systemctl restart tbm-umbrel
```

---

## Uninstallation

```bash
cd ~/TBM
bash uninstall.sh
```

---

## Wiring Diagram (ST7735 1.8" LCD → Raspberry Pi)

| LCD Pin | Raspberry Pi Pin | GPIO | Description |
|---------|-----------------|------|-------------|
| VCC | Pin 1 | 3.3V | Power |
| GND | Pin 6 | GND | Ground |
| SCL/CLK | Pin 23 | GPIO 11 | SPI Clock |
| SDA/MOSI | Pin 19 | GPIO 10 | SPI Data |
| RES/RST | Pin 22 | GPIO 25 | Reset |
| DC | Pin 18 | GPIO 24 | Data/Command |
| CS | Pin 24 | GPIO 8 | Chip Select |
| BL/LED | Pin 17 | 3.3V | Backlight |

---

## Troubleshooting

**White screen after installation**
Check your GPIO wiring. Verify the service is running: `sudo systemctl status tbm-umbrel`.

**Wrong timezone shown**
Run `bash ~/TBM/app/configure.sh` again. Answer `n` when asked if the auto-detected timezone is correct, then enter your timezone manually (e.g., `America/New_York`).

**Garbled or striped display**
This fork includes a bundled ST7735 driver (`st7735_tbm.py`) tuned for the TBM 1.8" panel. If issues persist, it may be a hardware connection problem.

**`config.ini` conflicts on `git pull`**
Use `git stash` before pulling (see Updating section above).

---

## Repository Structure

```
TBM/
├── app/
│   ├── tbm.py              # Main LCD display script
│   ├── setup_wizard.py     # Interactive settings wizard
│   ├── configure.sh        # Service setup script
│   ├── install.sh          # Dependency installation script
│   ├── config.ini          # User settings (auto-updated by wizard)
│   ├── CurrencyData.py     # Supported currency list (46 fiat currencies)
│   ├── connections.py      # Bitcoin/LND connection helpers
│   ├── st7735_tbm.py       # Bundled ST7735 LCD driver
│   ├── calibrate.py        # LCD calibration utility
│   ├── images/             # Screen background images
│   └── poppins/            # Poppins font files
├── Images/                 # Repository images (for README)
├── uninstall.sh            # Uninstallation script
├── LICENSE
└── README.md
```

---

## Credits

*   Original Project: [doidotech/TBM](https://github.com/doidotech/TBM) by DOIDO Technologies
*   This fork was created to address issues reported in the [Umbrel Community Forum](https://community.umbrel.com/t/the-bitcoin-machine-blank-lcd-since-umbrel-os-1/15720).

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.
