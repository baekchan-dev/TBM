#!/bin/bash
#-------------------------------------------------------------------------------
#   TBM (The Bitcoin Machine) — Umbrel 1.x Compatible Fork
#   One-line installer:
#     curl -sSL https://raw.githubusercontent.com/baekchan-dev/TBM/master/install.sh | bash
#-------------------------------------------------------------------------------

REPO_URL="https://github.com/baekchan-dev/TBM.git"
INSTALL_DIR="$HOME/TBM"
BACKUP_DIR="$HOME/TBM-backup-$(date +%Y%m%d%H%M%S)"

echo ""
echo "======================================================================"
echo " TBM (The Bitcoin Machine) — Umbrel 1.x Compatible Fork"
echo " Installer"
echo "======================================================================"
echo ""

# ──────────────────────────────────────────────────────────────────────────────
# Step 1: Stop and remove legacy services
# ──────────────────────────────────────────────────────────────────────────────
echo "[1/5] Checking for legacy TBM services..."
echo ""

LEGACY_SERVICES=(UmbrelST7735LCD raspiBlitzST7735LCD myNodeST7735LCD RoninDojoST7735LCD tbm tbm-umbrel)

for SVC in "${LEGACY_SERVICES[@]}"; do
    if systemctl list-units --full --all 2>/dev/null | grep -q "${SVC}.service"; then
        echo "  Found: ${SVC} — stopping and removing..."
        sudo systemctl stop    "${SVC}.service" 2>/dev/null || true
        sudo systemctl disable "${SVC}.service" 2>/dev/null || true
        sudo rm -f "/lib/systemd/system/${SVC}.service"
        sudo systemctl daemon-reload
        echo "  ✔ ${SVC} removed."
    fi
done

echo ""
echo "  ✔ Legacy service check complete."
echo ""

# ──────────────────────────────────────────────────────────────────────────────
# Step 2: Back up existing TBM directory (if present)
# ──────────────────────────────────────────────────────────────────────────────
echo "[2/5] Checking for existing TBM installation..."
echo ""

if [ -d "$INSTALL_DIR" ]; then
    echo "  Found existing directory: ${INSTALL_DIR}"
    echo "  Backing up to: ${BACKUP_DIR}"
    mv "$INSTALL_DIR" "$BACKUP_DIR"
    echo "  ✔ Backup complete. Your old files are safe at: ${BACKUP_DIR}"
else
    echo "  No existing installation found. Proceeding with fresh install."
fi

echo ""

# ──────────────────────────────────────────────────────────────────────────────
# Step 3: Clone repository
# ──────────────────────────────────────────────────────────────────────────────
echo "[3/5] Downloading TBM..."
echo ""

git clone "$REPO_URL" "$INSTALL_DIR"
echo ""
echo "  ✔ Downloaded to: ${INSTALL_DIR}"
echo ""

# ──────────────────────────────────────────────────────────────────────────────
# Step 4: Install Python dependencies
# ──────────────────────────────────────────────────────────────────────────────
echo "[4/5] Installing dependencies..."
echo ""

sudo apt-get update -qq
sudo apt-get install -y -qq build-essential python3-dev python3-smbus python3-pip python3-pil python3-numpy
sudo apt-get install -y -qq python3-spidev 2>/dev/null || true
sudo apt-get install -y -qq gpiod libgpiod-dev 2>/dev/null || true

PIP_FLAGS="--break-system-packages --quiet"
python3 -m pip install $PIP_FLAGS RPi.GPIO       2>/dev/null || python3 -m pip install --user --quiet RPi.GPIO
python3 -m pip install $PIP_FLAGS psutil          2>/dev/null || python3 -m pip install --user --quiet psutil
python3 -m pip install $PIP_FLAGS requests        2>/dev/null || python3 -m pip install --user --quiet requests
python3 -m pip install $PIP_FLAGS "requests[socks]" 2>/dev/null || python3 -m pip install --user --quiet "requests[socks]"
python3 -m pip install $PIP_FLAGS pysocks         2>/dev/null || python3 -m pip install --user --quiet pysocks
python3 -m pip install $PIP_FLAGS "Pillow>=10.0.0" 2>/dev/null || python3 -m pip install --user --quiet "Pillow>=10.0.0"
python3 -m pip install $PIP_FLAGS gpiod           2>/dev/null || python3 -m pip install --user --quiet gpiod
python3 -m pip install $PIP_FLAGS spidev          2>/dev/null || python3 -m pip install --user --quiet spidev
python3 -m pip install $PIP_FLAGS numpy           2>/dev/null || python3 -m pip install --user --quiet numpy
python3 -m pip install $PIP_FLAGS pytz            2>/dev/null || python3 -m pip install --user --quiet pytz
python3 -m pip install $PIP_FLAGS --upgrade certifi 2>/dev/null || true

echo ""
echo "  ✔ Dependencies installed."
echo ""

# ──────────────────────────────────────────────────────────────────────────────
# Step 5: Enable SPI interface
# ──────────────────────────────────────────────────────────────────────────────
echo "[5/5] Enabling SPI interface..."
echo ""

# Check if SPI is already active (Umbrel OS often has SPI enabled by default)
if ls /dev/spidev* > /dev/null 2>&1; then
    echo "  ✔ SPI is already enabled (/dev/spidev* found). Skipping."
else
    # Locate config.txt
    if [ -f /boot/firmware/config.txt ]; then
        CONFIG_PATH="/boot/firmware/config.txt"
    elif [ -f /boot/config.txt ]; then
        CONFIG_PATH="/boot/config.txt"
    else
        CONFIG_PATH=""
    fi

    if [ -n "$CONFIG_PATH" ]; then
        # Try to enable SPI; handle read-only filesystem gracefully
        if sudo sed -i 's/dtparam=spi=off/dtparam=spi=on/g' "$CONFIG_PATH" 2>/dev/null && \
           sudo sed -i 's/#dtparam=spi=on/dtparam=spi=on/g' "$CONFIG_PATH" 2>/dev/null; then
            if ! grep -q "dtparam=spi=on" "$CONFIG_PATH"; then
                echo "dtparam=spi=on" | sudo tee -a "$CONFIG_PATH" > /dev/null 2>&1 || true
            fi
            echo "  ✔ SPI enabled in ${CONFIG_PATH}"
        else
            echo "  NOTE: Could not modify ${CONFIG_PATH} (read-only filesystem)."
            echo "        This is normal on Umbrel OS — SPI is typically already enabled."
            echo "        If your LCD does not work after rebooting, please enable SPI manually."
        fi
    else
        echo "  NOTE: config.txt not found. If your LCD does not work, enable SPI manually."
    fi
fi

echo ""

# ──────────────────────────────────────────────────────────────────────────────
# Done
# ──────────────────────────────────────────────────────────────────────────────
echo "======================================================================"
echo " Installation complete!"
echo "======================================================================"
echo ""
echo "  Next steps:"
echo ""
echo "  1. Reboot your device:"
echo "       sudo reboot"
echo ""
echo "  2. After rebooting, reconnect via SSH and run the setup wizard:"
echo "       bash ~/TBM/app/configure.sh"
echo ""
echo "  The setup wizard will configure your timezone, screens, currency,"
echo "  and screen duration, then start the LCD service automatically."
echo ""
if [ -d "$BACKUP_DIR" ]; then
    echo "  Note: Your previous TBM installation was backed up to:"
    echo "        ${BACKUP_DIR}"
    echo "        You can safely delete it once everything is working."
    echo ""
fi
echo "======================================================================"
