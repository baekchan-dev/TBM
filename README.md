# TBM — The Bitcoin Machine (Umbrel 1.x Compatible Fork)

> **This is an unofficial community fork** of [doidotech/TBM](https://github.com/doidotech/TBM).
> Since Umbrel OS 1.0 was released in 2024, many TBM owners reported that their LCD display went completely white and the original scripts stopped working. The original maintainer was no longer active, leaving users with no fix. This fork resolves the issue.

---

![TBM LCD Screen](https://raw.githubusercontent.com/baekchan-dev/TBM/master/Images/Main.jpg)

---

## Installation

Connect to your Umbrel node via SSH, then run these two commands:

```bash
curl -sSL https://raw.githubusercontent.com/baekchan-dev/TBM/master/install.sh | bash
```

The installer will automatically:
- Stop and remove the old `UmbrelST7735LCD` service (if running)
- Back up your existing `~/TBM` directory (if present)
- Download this fork
- Install all required dependencies
- Enable the SPI interface

Then **reboot**:

```bash
sudo reboot
```

After rebooting, reconnect via SSH and run the setup wizard:

```bash
bash ~/TBM/app/configure.sh
```

The wizard guides you through timezone, screen selection, currency, and screen duration — then starts the service automatically. **Your LCD should now be working.**

---

## Features

*   **7 Information Screens:**
    1.  **Bitcoin Price** — Real-time price and sats/currency value.
    2.  **Next Block Info** — Estimated fees for the next block.
    3.  **Block Height** — Current Bitcoin block height.
    4.  **Date & Time** — System date and time.
    5.  **Network Info** — Umbrel IP address and network status.
    6.  **Lightning Channels** — Active/inactive channel count.
    7.  **Disk Usage** — Umbrel storage usage.
*   **46 supported fiat currencies** (AED, ARS, AUD, BRL, CAD, CHF, CNY, EUR, GBP, HKD, JPY, KRW, USD, and more)
*   **Smart timezone detection** — auto-detected from system; manual override available
*   **Auto-start & restart** — runs as a `tbm-umbrel` systemd service

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
cd ~/TBM && git stash && git pull && git stash drop
sudo systemctl restart tbm-umbrel
```

---

## Uninstallation

```bash
bash ~/TBM/uninstall.sh
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
This fork includes a bundled ST7735 driver tuned for the TBM 1.8" panel. If issues persist, it is likely a hardware connection problem — check your wiring.

**`config.ini` conflicts on `git pull`**
Use `git stash` before pulling (see Updating section above).

---

## Repository Structure

```
TBM/
├── install.sh          # One-line installer (run this first)
├── uninstall.sh        # Uninstallation script
├── app/
│   ├── tbm.py              # Main LCD display script
│   ├── configure.sh        # Service setup wizard
│   ├── config.ini          # User settings (auto-updated by wizard)
│   ├── CurrencyData.py     # Supported currency list
│   ├── connections.py      # Bitcoin/LND connection helpers
│   ├── st7735_tbm.py       # Bundled ST7735 LCD driver
│   ├── calibrate.py        # LCD calibration utility
│   ├── images/             # Screen background images
│   └── poppins/            # Poppins font files
├── Images/             # Repository images (for README)
├── LICENSE
└── README.md
```

---

## Credits

*   Original Project: [doidotech/TBM](https://github.com/doidotech/TBM) by DOIDO Technologies
*   This fork was created to address issues reported in the [Umbrel Community Forum](https://community.umbrel.com/t/the-bitcoin-machine-blank-lcd-since-umbrel-os-1/15720).

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.
