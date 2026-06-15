# Setup Bot Telegram

## 1. Buat Bot Baru

1. Buka Telegram, cari **@BotFather**
2. Kirim `/newbot`
3. Ikuti instruksi:
   - **Name**: `Adzan Notifier` (atau nama lain)
   - **Username**: `AdzanNotifierBot` (harus diakhiri `Bot`, unique)
4. BotFather akan kasih **token** seperti:
   ```
   1234567890:AAH_xxxxxxxxxxxxxxxxxxxxxxxxxxx
   ```
5. **Simpan token ini** — akan dipakai di `config.json`

## 2. Dapatkan Chat ID

### Untuk Personal Chat

1. Buka bot Anda di Telegram (search username-nya)
2. Kirim pesan `/start` atau pesan apa saja
3. Jalankan di terminal:
   ```bash
   ./scripts/get-chat-id.sh <BOT_TOKEN>
   ```
4. Output:
   ```
   Chat ID: 8742775002
   User: Adens (@sangpemangsa)
   ```

### Untuk Group Chat

1. Tambahkan bot ke group
2. Kirim `/start@NamaBotAnda` di group
3. Jalankan `get-chat-id.sh`
4. Group chat ID biasanya **negatif** seperti `-1001234567890`

## 3. Test Kirim Pesan

```bash
curl -X POST "https://api.telegram.org/bot<TOKEN>/sendMessage" \
  -H "Content-Type: application/json" \
  -d '{
    "chat_id": "8742775002",
    "text": "Test dari adzan-notifier",
    "parse_mode": "HTML"
  }'
```

## 4. Isi di Config

```json
{
  "telegram": {
    "bot_token": "1234567890:AAH_xxxxxxxxxxxxxxxxxxxxxxxxxxx",
    "chat_id": "8742775002"
  }
}
```

## 5. (Opsional) Bot Commands

Agar bot lebih interaktif, set commands di @BotFather:

1. Chat dengan @BotFather → `/setcommands` → pilih bot Anda
2. Kirim:
   ```
   start - Mulai notifikasi
   stop - Berhenti notifikasi
   jadwal - Lihat jadwal hari ini
   help - Bantuan
   ```
3. (Optional) Edit script untuk handle commands via webhook/polling

## Troubleshooting

| Problem | Solusi |
|---|---|
| "Unauthorized" | Token salah, cek di @BotFather |
| "chat not found" | Bot belum pernah di-start oleh user |
| "bot was blocked" | User harus unblock bot dulu |
| Pesan tidak masuk | Cek chat_id benar (positif=personal, negatif=group) |
| Bot tidak bisa join group | Disable privacy mode di @BotFather → /setprivacy → Disable |
