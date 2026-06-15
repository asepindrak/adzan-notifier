#!/bin/bash
# install.sh — Install adzan-notifier pada sistem
# Usage: ./install.sh [--force]

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
USER_HOME="$HOME"
CONFIG_DIR="$USER_HOME/.config/adzan-notifier"
LOCAL_BIN="$USER_HOME/.local/bin"
CACHE_DIR="$USER_HOME/.local/share/adzan-notifier"
LOG_DIR="$CACHE_DIR/logs"
SERVICE_FILE="$CONFIG_DIR/adzan-notifier.service"

echo -e "${GREEN}🕌 Adzan Notifier Installer${NC}"
echo ""

# --- 1. Install dependencies ---
echo -e "${YELLOW}[1/5] Checking dependencies...${NC}"
MISSING=()
for cmd in python3 ffmpeg notify-send aplay; do
    if ! command -v "$cmd" &>/dev/null; then
        MISSING+=("$cmd")
    fi
done

if [ ${#MISSING[@]} -gt 0 ]; then
    echo -e "  ${RED}Missing: ${MISSING[*]}${NC}"
    echo -e "  Install with:"
    echo -e "  ${GREEN}sudo apt install python3 ffmpeg alsa-utils libnotify-bin${NC}"
    echo ""
    read -rp "  Continue anyway? (y/N) " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Cancelled."
        exit 1
    fi
else
    echo -e "  ✅ All dependencies found"
fi

# --- 2. Copy files ---
echo -e "${YELLOW}[2/5] Installing files...${NC}"

# Copy Python script
cp "$SCRIPT_DIR/adzan-notifier.py" "$LOCAL_BIN/adzan-notifier.py"
chmod +x "$LOCAL_BIN/adzan-notifier.py"
echo "  ✅ Script → $LOCAL_BIN/adzan-notifier.py"

# Copy systemd service
cp "$SCRIPT_DIR/adzan-notifier.service" "$SERVICE_FILE"
echo "  ✅ Service → $SERVICE_FILE"

# Create config if not exists
CONFIG_FILE="$CONFIG_DIR/config.json"
if [ ! -f "$CONFIG_FILE" ]; then
    cp "$SCRIPT_DIR/config.example.json" "$CONFIG_FILE"
    echo "  ✅ Config → $CONFIG_FILE (edit this!)"
else
    echo "  ⏭️  Config already exists, skipping"
fi

# Create cache & log dirs
mkdir -p "$CACHE_DIR/logs"
echo "  ✅ Cache dir → $CACHE_DIR"

# --- 3. Validate config ---
echo -e "${YELLOW}[3/6] Validating config...${NC}"
if [ -f "$CONFIG_FILE" ]; then
    PLACEHOLDERS=$(grep -E "ISI_|xxxx|XXXX|1234567890|<TOKEN>|<CHAT_ID>" "$CONFIG_FILE" 2>/dev/null || true)
    if [ -n "$PLACEHOLDERS" ]; then
        echo -e "  ${RED}❌ Config masih punya placeholder:${NC}"
        echo "$PLACEHOLDERS" | sed 's/^/    /'
        echo ""
        echo -e "  ${YELLOW}Edit dulu: nano $CONFIG_FILE${NC}"
        echo -e "  ${YELLOW}Isi: telegram.bot_token dan telegram.chat_id yang sebenarnya${NC}"
        echo ""
        read -rp "  Lanjutkan tanpa fix? (y/N) " -n 1 -r
        echo ""
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "Cancelled. Fix config dulu lalu jalankan ulang."
            exit 1
        fi
    else
        echo -e "  ✅ Config looks good"
    fi
fi

# --- 4. Enable & start service ---
echo -e "${YELLOW}[4/6] Enabling systemd user service...${NC}"
systemctl --user daemon-reload
systemctl --user enable adzan-notifier.service
echo "  ✅ Service enabled (auto-starts on login)"

# --- 5. Start service ---
echo -e "${YELLOW}[5/6] Starting service...${NC}"
systemctl --user start adzan-notifier.service
sleep 2

STATUS=$(systemctl --user is-active adzan-notifier.service 2>/dev/null || echo "inactive")
if [ "$STATUS" = "active" ]; then
    echo -e "  ✅ Service is RUNNING"
else
    echo -e "  ${RED}⚠️  Service failed to start.${NC}"
    echo -e "  Check logs: journalctl --user -u adzan-notifier -n 20"
fi

# --- 6. Summary ---
echo ""
echo -e "${GREEN}═══════════════════════════════════════${NC}"
echo -e "${GREEN}✅ Installation Complete!${NC}"
echo -e "${GREEN}═══════════════════════════════════════${NC}"
echo ""
echo -e "  📋 Config file:   ${CYAN}$CONFIG_FILE${NC}"
echo -e "  📝 Log file:      ${CYAN}$LOG_DIR/daemon.log${NC}"
echo -e "  🔧 Service:       ${CYAN}adzan-notifier.service${NC}"
echo ""
echo -e "  ${YELLOW}Next steps:${NC}"
echo -e "  1. Edit $CONFIG_FILE (set bot_token & chat_id)"
echo -e "  2. Place your adzan audio in $USER_HOME/.local/share/sounds/"
echo -e "  3. systemctl --user restart adzan-notifier"
echo -e "  4. tail -f $LOG_DIR/daemon.log"
echo ""
echo -e "  ${GREEN}Happy praying! 🕌${NC}"
