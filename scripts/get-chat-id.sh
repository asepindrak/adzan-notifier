#!/bin/bash
# get-chat-id.sh — Dapatkan chat_id Telegram dari bot token
# Usage: ./scripts/get-chat-id.sh <BOT_TOKEN>

set -euo pipefail

if [ $# -lt 1 ]; then
    echo "Usage: $0 <BOT_TOKEN>"
    echo ""
    echo "Cara:"
    echo "  1. Chat @BotFather → /newbot → simpan token"
    echo "  2. Buka bot baru di Telegram → kirim /start"
    echo "  3. Jalankan: $0 <BOT_TOKEN>"
    exit 1
fi

TOKEN="$1"

echo "Mengecek update dari bot..."
echo ""

RESP=$(curl -sf "https://api.telegram.org/bot${TOKEN}/getUpdates" 2>/dev/null)

if [ $? -ne 0 ] || [ -z "$RESP" ]; then
    echo "❌ Gagal connect. Cek token dan koneksi internet."
    exit 1
fi

# Cek apakah ada update
COUNT=$(echo "$RESP" | python3 -c "import json,sys; d=json.load(sys.stdin); print(len(d.get('result', [])))" 2>/dev/null)

if [ "$COUNT" = "0" ] || [ -z "$COUNT" ]; then
    echo "⚠️  Belum ada pesan masuk ke bot."
    echo ""
    echo "Cara:"
    echo "  1. Buka Telegram"
    echo "  2. Cari bot Anda (username dari @BotFather)"
    echo "  3. Kirim /start atau pesan apa saja"
    echo "  4. Jalankan ulang script ini"
    echo ""
    echo "Raw response:"
    echo "$RESP"
    exit 0
fi

echo "✅ Ditemukan $COUNT update"
echo ""

# Parse semua chat unik
echo "$RESP" | python3 -c "
import json, sys
data = json.load(sys.stdin)
seen = set()
for update in data.get('result', []):
    msg = update.get('message') or update.get('edited_message')
    if not msg:
        continue
    chat = msg.get('chat', {})
    chat_id = chat.get('id')
    if chat_id in seen:
        continue
    seen.add(chat_id)
    name = chat.get('first_name', '') + (chat.get('last_name', '') and ' ' + chat['last_name'] or '')
    username = '@' + chat['username'] if chat.get('username') else ''
    ctype = chat.get('type', 'unknown')
    print(f'  Chat ID: {chat_id}  |  {ctype:8s}  |  {name} {username}')
"

echo ""
echo "Copy chat_id yang sesuai ke config.json → telegram.chat_id"
