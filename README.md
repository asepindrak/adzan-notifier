# 🕌 Adzan Notifier

Daemon ringan untuk Linux (Ubuntu/GNOME) yang mengingatkan waktu shalat dengan **notifikasi desktop + Telegram + bunyi adzan**. Data jadwal diambil gratis dari API [equran.id](https://equran.id/apidev/shalat).

![Status](https://img.shields.io/badge/status-active-brightgreen)
![Platform](https://img.shields.io/badge/platform-Ubuntu%20%7C%20GNOME-blue)
![License](https://img.shields.io/badge/license-MIT-green)

---

## ✨ Fitur

- 🕐 **5 waktu shalat** (Subuh, Dzuhur, Ashar, Maghrib, Isya) + opsional Imsak
- 🔔 **Notifikasi desktop** Ubuntu (`notify-send`)
- 📱 **Telegram bot** — notifikasi ke HP via bot Telegram
- 🔊 **Bunyi adzan** — play file MP3/OGG/WAV dengan volume control
- 💾 **Cache offline** — jadwal 1 bulan disimpan, daemon tidak re-fetch tiap menit
- 🔄 **Auto-start** — systemd user service, langsung jalan saat login
- 🗓️ **517 kota** di Indonesia, otomatis di-fetch dari API

---

## 📦 Isi Repo

```
adzan-notifier/
├── README.md                  # ← Anda di sini
├── LICENSE
├── adzan-notifier.py          # Daemon utama
├── adzan-notifier.service     # Systemd user service
├── config.example.json        # Template config
├── install.sh                 # Installer satu-perintah
├── docs/
│   ├── API.md                 # Detail API equran.id
│   ├── TELEGRAM.md            # Cara setup bot Telegram
│   ├── AUDIO.md               # Format & sumber audio adzan
│   └── TROUBLESHOOTING.md
├── scripts/
│   ├── test-notification.sh   # Test kirim notif manual
│   └── get-chat-id.sh         # Helper dapetin chat_id Telegram
└── assets/
    └── adzan-sample.mp3       # (opsional) contoh adzan
```

---

## 🚀 Quick Start (60 detik)

```bash
# 1. Clone
git clone https://github.com/asepindrak/adzan-notifier.git
cd adzan-notifier

# 2. Install dependencies
sudo apt install ffmpeg alsa-utils libnotify-bin pulseaudio-utils -y
pip install --user requests urllib3    # optional, sudah ada urllib stdlib

# 3. Copy config & edit
cp config.example.json ~/.config/adzan-notifier/config.json
nano ~/.config/adzan-notifier/config.json
# Isi: provinsi, kabkota, telegram.bot_token, telegram.chat_id

# 4. Install service
./install.sh

# 5. Verify
systemctl --user status adzan-notifier
tail -f ~/.local/share/adzan-notifier/logs/daemon.log
```

---

## ⚙️ Konfigurasi

File: `~/.config/adzan-notifier/config.json`

```json
{
  "provinsi": "Jawa Barat",
  "kabkota": "Kab. Garut",
  "telegram": {
    "bot_token": "1234567890:xxx",
    "chat_id": "xxx"
  },
  "adhan": {
    "enabled": true,
    "audio_file": "/home/adens/.local/share/sounds/adzan.mp3",
    "volume": 30
  },
  "pre_adzan_minutes": 0,
  "notify_5_prayers": true,
  "imsyak_reminder": false
}
```

| Field | Keterangan |
|---|---|
| `provinsi` | Nama provinsi (lihat [docs/API.md](docs/API.md)) |
| `kabkota` | Nama kabupaten/kota (case-sensitive, tanpa "Kecamatan") |
| `telegram.bot_token` | Token dari [@BotFather](https://t.me/BotFather) |
| `telegram.chat_id` | Chat ID Telegram Anda (positif = personal, negatif = group) |
| `adhan.audio_file` | Path absolut ke file audio adzan (MP3/OGG/WAV) |
| `adhan.volume` | 0–100 (default 80) |
| `pre_adzan_minutes` | Notif H-minutes sebelum waktu (default 0 = pas waktu) |
| `notify_5_prayers` | true/false (Subuh, Dzuhur, Ashar, Maghrib, Isya) |
| `imsyak_reminder` | true/false (Imsak = 10 menit sebelum Subuh) |

### Cara dapetin `chat_id` Telegram

```bash
# 1. Chat dengan @BotFather → /newbot → simpan token
# 2. Buka bot baru Anda di Telegram, kirim /start
# 3. Jalankan:
./scripts/get-chat-id.sh <BOT_TOKEN>
# Output: chat_id Anda
```

Panduan lengkap: [docs/TELEGRAM.md](docs/TELEGRAM.md)

---

## 🎵 Format Audio yang Didukung

| Format | Backend | Catatan |
|---|---|---|
| **MP3** | `ffmpeg` → `aplay` | Default; perlu `ffmpeg` terinstall |
| **OGG** | `aplay` | Recommended; native Linux |
| **WAV** | `aplay` | Lossless, ukuran besar |
| **FLAC** | `aplay` | Lossless + compressed |

Sumber adzan gratis: lihat [docs/AUDIO.md](docs/AUDIO.md)

---

## 🛠️ Perintah Harian

```bash
# Status
systemctl --user status adzan-notifier

# Lihat log real-time
tail -f ~/.local/share/adzan-notifier/logs/daemon.log

# Restart setelah edit config
systemctl --user restart adzan-notifier

# Stop
systemctl --user stop adzan-notifier

# Disable auto-start
systemctl --user disable adzan-notifier

# Test notifikasi manual (tanpa tunggu waktu shalat)
./scripts/test-notification.sh
```

---

## 🔍 Troubleshooting

| Problem | Solusi |
|---|---|
| Service tidak jalan | `systemctl --user status adzan-notifier` — lihat error |
| Telegram tidak terkirim | Cek token & chat_id, pastikan bot sudah di-start |
| Tidak ada bunyi | Cek `aplay -l` (list device), set default sink |
| API 403 Forbidden | Script sudah include User-Agent + Referer headers |
| "Kabupaten/Kota tidak ditemukan" | Cek [docs/API.md](docs/API.md) — nama harus persis |

Lihat [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) untuk detail.

---

## 🏗️ Arsitektur

```
┌─────────────────┐
│ equran.id API   │  ← Jadwal shalat bulanan
└────────┬────────┘
         │ HTTP POST (1x/bulan atau ganti bulan)
         ▼
┌─────────────────────────────┐
│ adzan-notifier.py (daemon)  │ ← Loop 30 detik
│  - load jadwal dari cache   │
│  - cek waktu sekarang       │
│  - kalau cocok → trigger    │
└────┬──────────┬──────────┬──┘
     │          │          │
     ▼          ▼          ▼
 Telegram   Ubuntu      Audio
   Bot      notif-send   (aplay/ffmpeg)
```

**Loop interval:** 30 detik (akurasi ±30 detik)
**Network usage:** ~1 API call/bulan (~5KB)
**CPU usage:** <0.1% (mostly sleeping)
**Memory:** ~10 MB

---

## 🧪 Test

```bash
# Test API + Telegram + Audio + Notif sekaligus
./scripts/test-notification.sh

# Output:
# ✅ notify-send dipanggil
# ✅ Telegram terkirim
# ✅ Audio diputar
```

---

## 📜 Lisensi

MIT — lihat [LICENSE](LICENSE)

---

## 🙏 Kredit

- **Data jadwal**: [EQuran.id](https://equran.id) — REST API gratis
- **Implementasi**: Adens (@sangpemangsa)
- **Systemd service pattern**: Arch Wiki

---

## 📚 Referensi

- [Dokumentasi API equran.id](https://equran.id/apidev/shalat)
- [BotFather (Telegram)](https://t.me/BotFather)
- [systemd User Services](https://wiki.archlinux.org/title/Systemd/User)
