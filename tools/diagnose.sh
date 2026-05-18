#!/bin/bash
#-------------------------------------------------------------------------------
#   TBM Diagnostic Script v1.0
#   Run this when LCD shows white screen to identify the root cause.
#
#   Usage:
#     bash ~/TBM/tools/diagnose.sh
#
#   What it checks:
#     1. SPI interface status
#     2. GPIO chip availability
#     3. Python dependencies
#     4. Docker container names (Bitcoin / LND)
#     5. Bitcoin RPC connectivity
#     6. TBM service status & logs
#     7. LCD hardware test
#-------------------------------------------------------------------------------

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

pass_count=0
fail_count=0
warn_count=0

pass() { echo -e "  ${GREEN}✔ PASS${NC}: $1"; ((pass_count++)); }
fail() { echo -e "  ${RED}✘ FAIL${NC}: $1"; ((fail_count++)); }
warn() { echo -e "  ${YELLOW}⚠ WARN${NC}: $1"; ((warn_count++)); }
info() { echo -e "  ${BLUE}ℹ INFO${NC}: $1"; }

echo ""
echo "======================================================================"
echo " TBM Diagnostic Script"
echo " $(date)"
echo "======================================================================"
echo ""

# ────────────────────────────────────────────────────────────────────
# 1. SPI Interface
# ────────────────────────────────────────────────────────────────────
echo "--- [1/7] SPI Interface ---"
if ls /dev/spidev* >/dev/null 2>&1; then
    pass "SPI devices found: $(ls /dev/spidev* 2>/dev/null | tr '\n' ' ')"
else
    fail "No /dev/spidev* found. SPI is not enabled."
    echo "       Fix: Enable SPI via raspi-config or add dtparam=spi=on to /boot/firmware/config.txt"
fi

# Check SPI config in boot partition
for cfg in /boot/firmware/config.txt /boot/config.txt; do
    if [ -f "$cfg" ]; then
        if grep -q "dtparam=spi=on" "$cfg" 2>/dev/null; then
            pass "SPI enabled in $cfg"
        else
            warn "SPI not explicitly enabled in $cfg (may still work if enabled elsewhere)"
        fi
        break
    fi
done
echo ""

# ────────────────────────────────────────────────────────────────────
# 2. GPIO Chip
# ────────────────────────────────────────────────────────────────────
echo "--- [2/7] GPIO Chips ---"
gpio_found=false
for chip in /dev/gpiochip*; do
    if [ -e "$chip" ]; then
        info "Found: $chip"
        gpio_found=true
    fi
done
if $gpio_found; then
    pass "GPIO chips available"
else
    fail "No /dev/gpiochip* found. GPIO is not available."
fi

# Check gpiod Python package
if python3 -c "import gpiod; print(gpiod.__version__)" 2>/dev/null; then
    GPIOD_VER=$(python3 -c "import gpiod; print(gpiod.__version__)" 2>/dev/null)
    pass "gpiod Python package: v${GPIOD_VER}"
else
    fail "gpiod Python package not found"
    echo "       Fix: pip install gpiod --break-system-packages"
fi

# Check spidev Python package
if python3 -c "import spidev" 2>/dev/null; then
    pass "spidev Python package installed"
else
    fail "spidev Python package not found"
    echo "       Fix: pip install spidev --break-system-packages"
fi
echo ""

# ────────────────────────────────────────────────────────────────────
# 3. Python Dependencies
# ────────────────────────────────────────────────────────────────────
echo "--- [3/7] Python Dependencies ---"
DEPS=("PIL" "numpy" "requests" "configparser" "pytz")
for dep in "${DEPS[@]}"; do
    if python3 -c "import ${dep}" 2>/dev/null; then
        pass "Python: ${dep}"
    else
        fail "Python: ${dep} not found"
    fi
done

# Check Python version
PY_VER=$(python3 --version 2>&1)
info "Python: ${PY_VER}"
echo ""

# ────────────────────────────────────────────────────────────────────
# 4. Docker Container Names
# ────────────────────────────────────────────────────────────────────
echo "--- [4/7] Docker Containers ---"
if command -v docker &>/dev/null; then
    pass "Docker is installed"
else
    fail "Docker not found in PATH"
    echo "       Add /usr/local/bin to PATH or check Docker installation"
fi

# Find Bitcoin container
echo "  Looking for Bitcoin containers..."
BTC_FOUND=false
docker ps --format '{{.Names}}' 2>/dev/null | while read name; do
    if echo "$name" | grep -qiE 'bitcoin|bitcoind'; then
        echo "    Found: $name"
        BTC_FOUND=true
    fi
done
# Also check with a different method
BTC_CONTAINERS=$(docker ps --format '{{.Names}}' 2>/dev/null | grep -iE 'bitcoin|bitcoind' || true)
if [ -n "$BTC_CONTAINERS" ]; then
    pass "Bitcoin container(s) running: $(echo $BTC_CONTAINERS | tr '\n' ' ')"
else
    warn "No Bitcoin container found running. Is the Bitcoin app installed and started?"
    echo "       The LCD will work but show '--' for Bitcoin data."
fi

# Find LND container
echo "  Looking for Lightning containers..."
LND_CONTAINERS=$(docker ps --format '{{.Names}}' 2>/dev/null | grep -iE 'lightning|lnd' || true)
if [ -n "$LND_CONTAINERS" ]; then
    pass "Lightning container(s) running: $(echo $LND_CONTAINERS | tr '\n' ' ')"
else
    info "No Lightning container found (optional — Screen 6 will be empty)"
fi
echo ""

# ────────────────────────────────────────────────────────────────────
# 5. Bitcoin RPC Connectivity
# ────────────────────────────────────────────────────────────────────
echo "--- [5/7] Bitcoin RPC ---"
RPC_HOST="127.0.0.1"
RPC_PORT="8332"
RPC_USER="umbrel"
PASSWORDS=("moneyprintergobrrr" "umbrel" "")

RPC_OK=false
for pass in "${PASSWORDS[@]}"; do
    if [ -z "$pass" ]; then
        continue
    fi
    RESPONSE=$(curl -s --max-time 5 \
        --user "${RPC_USER}:${pass}" \
        --data-binary '{"jsonrpc":"1.0","id":"test","method":"getblockchaininfo","params":[]}' \
        -H 'content-type: application/json;' \
        "http://${RPC_HOST}:${RPC_PORT}/" 2>/dev/null || true)
    if echo "$RESPONSE" | grep -q '"result"'; then
        CHAIN=$(echo "$RESPONSE" | python3 -c "import json,sys; print(json.load(sys.stdin)['result']['chain'])" 2>/dev/null || echo "unknown")
        BLOCKS=$(echo "$RESPONSE" | python3 -c "import json,sys; print(json.load(sys.stdin)['result']['blocks'])" 2>/dev/null || echo "?")
        pass "Bitcoin RPC connected — chain: ${CHAIN}, blocks: ${BLOCKS}"
        RPC_OK=true
        break
    fi
done

if ! $RPC_OK; then
    fail "Bitcoin RPC connection failed (tried passwords: ${PASSWORDS[*]})"
    echo "       Fix: Check Bitcoin app is running and verify RPC credentials"
    echo "       You can set custom credentials in ~/TBM/app/config.ini [BITCOIN] section"
fi
echo ""

# ────────────────────────────────────────────────────────────────────
# 6. TBM Service Status
# ────────────────────────────────────────────────────────────────────
echo "--- [6/7] TBM Service ---"
if systemctl is-active --quiet tbm-umbrel 2>/dev/null; then
    pass "tbm-umbrel service is running"
elif systemctl is-enabled tbm-umbrel >/dev/null 2>&1; then
    warn "tbm-umbrel service exists but is not running"
    echo "       Check logs: sudo journalctl -u tbm-umbrel -n 50 --no-pager"
else
    fail "tbm-umbrel service not found"
    echo "       Fix: Run setup wizard: bash ~/TBM/app/configure.sh"
fi

# Show recent logs
if systemctl list-units --all 2>/dev/null | grep -q tbm-umbrel; then
    echo ""
    echo "  Recent service logs (last 20 lines):"
    echo "  ----------------------------------------"
    sudo journalctl -u tbm-umbrel -n 20 --no-pager 2>/dev/null | sed 's/^/    /' || echo "    (could not read logs)"
fi
echo ""

# ────────────────────────────────────────────────────────────────────
# 7. LCD Hardware Test
# ────────────────────────────────────────────────────────────────────
echo "--- [7/7] LCD Hardware Test ---"
# Check if the LCD pins are accessible
if [ -e /dev/spidev0.0 ]; then
    pass "SPI device /dev/spidev0.0 available"
else
    fail "SPI device /dev/spidev0.0 not found"
fi

# Check gpiochip access for pins 24, 25
for pin in 24 25; do
    CHIP=""
    for c in gpiochip0 gpiochip4 gpiochip1; do
        if [ -e "/dev/$c" ]; then
            if gpioinfo "$c" 2>/dev/null | grep -q "line.*${pin}:"; then
                CHIP="$c"
                break
            fi
        fi
    done
    if [ -n "$CHIP" ]; then
        pass "GPIO pin ${pin} found on /dev/${CHIP}"
    else
        warn "GPIO pin ${pin} not found (may still work with direct chip access)"
    fi
done

# Check TBM script exists
if [ -f ~/TBM/app/tbm.py ]; then
    pass "TBM script exists: ~/TBM/app/tbm.py"
else
    fail "TBM script not found at ~/TBM/app/tbm.py"
    echo "       Fix: Re-run installer: curl -sSL https://raw.githubusercontent.com/baekchan-dev/TBM/master/install.sh | bash"
fi

# Try a quick Python import test
echo ""
echo "  Testing Python imports..."
if python3 -c "
import sys
sys.path.insert(0, '$HOME/TBM/app')
try:
    from st7735_tbm import ST7735
    print('    st7735_tbm: OK')
except Exception as e:
    print(f'    st7735_tbm: FAIL — {e}')
try:
    from setup_wizard import run_wizard
    print('    setup_wizard: OK')
except Exception as e:
    print(f'    setup_wizard: FAIL — {e}')
try:
    from connections import test_tor, tor_request
    print('    connections: OK')
except Exception as e:
    print(f'    connections: FAIL — {e}')
" 2>/dev/null; then
    pass "Python module import test passed"
else
    fail "Python module import test failed"
fi

# ────────────────────────────────────────────────────────────────────
# Summary
# ────────────────────────────────────────────────────────────────────
echo ""
echo "======================================================================"
echo " DIAGNOSTIC SUMMARY"
echo "======================================================================"
echo -e "  ${GREEN}PASS: ${pass_count}${NC}  ${RED}FAIL: ${fail_count}${NC}  ${YELLOW}WARN: ${warn_count}${NC}"
echo ""

if [ "$fail_count" -gt 0 ]; then
    echo "  Issues found that need fixing (see FAIL items above)."
    echo ""
    echo "  Common fixes:"
    echo "  1. Enable SPI: sudo raspi-config → Interface Options → SPI → Yes"
    echo "  2. Install deps: cd ~/TBM && bash install.sh"
    echo "  3. Re-run setup: bash ~/TBM/app/configure.sh"
    echo "  4. Check logs:   sudo journalctl -u tbm-umbrel -f"
    echo "  5. Restart:      sudo systemctl restart tbm-umbrel"
fi

echo ""
echo "======================================================================"
