#!/bin/bash
# test-notification.sh — Test semua notifikasi (Telegram + Ubuntu + Audio)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG="$HOME/.config/adzan-notifier/config.json"

if [ ! -f "$CONFIG" ]; then
    echo "❌ Config tidak ada di $CONFIG"
    echo "   Copy config.example.json dulu lalu edit"
    exit 1
fi

echo "🕌 Testing adzan-notifier..."
echo ""

# --- Test 1: notify-send ---
echo "=== [1/3] Test Ubuntu Notification ==="
if command -v notify-send &>/dev/null; then
    notify-send -u critical -i appointment-soon \
        "🕌 Test Adzan Notifier" \
        "Ini test notifikasi Ubuntu. Lonceng akan berbunyi sebentar lagi..."
    echo "  ✅ Notifikasi terkirim (cek pojok kanan atas)"
else
    echo "  ❌ notify-send tidak ada. Install: sudo apt install libnotify-bin"
fi
echo ""

# --- Test 2: Telegram ---
echo "=== [2/3] Test Telegram ==="
python3 << 'PYEOF'
import json, sys, urllib.request
from pathlib import Path
try:
    cfg = json.loads(Path.home().joinpath(".config/adzan-notifier/config.json").read_text())
    token = cfg["telegram"]["bot_token"]
    chat_id = cfg["telegram"]["chat_id"]
    if "ISI_" in token or "ISI_" in chat_id:
        print("  ⚠️  Telegram belum dikonfig (skip)")
        sys.exit(0)
    body = json.dumps({
        "chat_id": chat_id,
        "text": "<b>🕌 Test Adzan Notifier</b>\n\n"
                "Telegram ✅\n"
                "Bot terkoneksi dengan benar.\n"
                "<i>Ini hanya test, bukan waktu shalat sungguhan.</i>",
        "parse_mode": "HTML"
    }).encode()
    req = urllib.request.Request(
        f"https://api.telegram.org/bot{token}/sendMessage",
        data=body, headers={"Content-Type": "application/json"}, method="POST"
    )
    with urllib.request.urlopen(req, timeout=10) as r:
        result = json.loads(r.read())
        if result.get("ok"):
            print(f"  ✅ Telegram terkirim (msg_id={result['result']['message_id']})")
        else:
            print(f"  ❌ Error: {result}")
except Exception as e:
    print(f"  ❌ Gagal: {e}")
PYEOF
echo ""

# --- Test 3: Audio ---
echo "=== [3/3] Test Audio Adzan (10 detik) ==="
python3 << 'PYEOF'
import json, sys, subprocess
from pathlib import Path
cfg = json.loads(Path.home().joinpath(".config/adzan-notifier/config.json").read_text())
audio = cfg.get("adhan", {}).get("audio_file", "")
if not audio or not Path(audio).exists():
    print(f"  ❌ Audio file tidak ada: {audio}")
    sys.exit(0)

vol = cfg.get("adhan", {}).get("volume", 80) / 100.0
ext = Path(audio).suffix.lower()

try:
    if ext == ".mp3":
        if subprocess.run(["which", "ffmpeg"], capture_output=True).returncode != 0:
            print("  ❌ ffmpeg tidak ada (perlu untuk MP3)")
            sys.exit(0)
        p1 = subprocess.Popen(
            ["ffmpeg", "-hide_banner", "-loglevel", "error",
             "-ss", "0", "-t", "10",  # 10 detik pertama
             "-i", audio, "-filter:a", f"volume={vol}",
             "-f", "wav", "-"],
            stdout=subprocess.PIPE, stderr=subprocess.DEVNULL
        )
        p2 = subprocess.Popen(
            ["aplay", "-D", "default", "-q", "-"],
            stdin=p1.stdout, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL
        )
        p1.stdout.close()
        p2.wait()
        print(f"  ✅ Audio diputar (10 detik pertama, vol {int(vol*100)}%)")
    else:
        p = subprocess.Popen(
            ["timeout", "10", "aplay", "-D", "default", "-q", audio],
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL
        )
        p.wait()
        print(f"  ✅ Audio diputar (10 detik, vol {int(vol*100)}%)")
except Exception as e:
    print(f"  ❌ Gagal: {e}")
PYEOF

echo ""
echo "=== SUMMARY ==="
echo "  Ubuntu notification → cek pojok kanan atas layar"
echo "  Telegram           → cek HP"
echo "  Audio              → dengarkan dari speaker"
echo ""
echo "Kalau ada yang tidak jalan, lihat: docs/TROUBLESHOOTING.md"
