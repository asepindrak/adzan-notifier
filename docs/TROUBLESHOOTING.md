# Troubleshooting

## Service Tidak Jalan

```bash
# Cek status
systemctl --user status adzan-notifier

# Lihat 20 baris terakhir log
journalctl --user -u adzan-notifier -n 20 --no-pager

# Log aplikasi (lebih detail)
tail -f ~/.local/share/adzan-notifier/logs/daemon.log
```

## Telegram Tidak Kirim Pesan

### Token Salah
```bash
# Test token
curl -s "https://api.telegram.org/bot<TOKEN>/getMe" | python3 -m json.tool
# Jika error: "Not Found" → token salah
```

### Chat ID Salah
```bash
# Test kirim pesan
curl -s -X POST "https://api.telegram.org/bot<TOKEN>/sendMessage" \
  -H "Content-Type: application/json" \
  -d '{"chat_id":"<CHAT_ID>","text":"test","parse_mode":"HTML"}'
# Jika error: "chat not found" → chat_id salah atau bot belum di-start
```

### Bot Belum Di-start
1. Buka bot di Telegram
2. Klik `/start` atau kirim pesan
3. Baru daemon bisa kirim ke bot ini

### Privacy Mode Group
Jika bot tidak bisa baca pesan di group:
1. Chat @BotFather → `/setprivacy` → pilih bot → `Disable`

## Tidak Ada Bunyi Adzan

### Cek Output Device
```bash
aplay -l
# Harus ada di list:
# card 0: HDMI → TV/Monitor
# card 1: USB Audio → speaker/earphone USB
# card 2: HDA Intel PCH → speaker laptop
```

### Test Play Langsung
```bash
# Test device tertentu (ganti X,Y sesuai aplay -l)
aplay -D hw:X,Y ~/.local/share/sounds/adzan.mp3

# Atau test device default
aplay ~/.local/share/sounds/adzan.ogg
```

### PulseAudio vs ALSA
```bash
# Cek default sink
pactl info | grep "Default Sink"

# List semua sink
pactl list sinks

# Ganti default
pactl set-default-sink alsa_output.pci-0000_01_00.1.analog-stereo
```

### Paplay Tidak Ada
```bash
sudo apt install pulseaudio-utils
```

## API Error 403 / 404

### 403 Forbidden
Script sudah include User-Agent + Referer headers. Jika masih error:
- Mungkin ada rate limiting dari Cloudflare
- Tunggu 5-10 menit, retry otomatis

### 404 — Kab/Kota Tidak Ditemukan
```bash
# Cek nama yang benar
python3 -c "
import json, urllib.request
body = json.dumps({'provinsi': 'Jawa Barat'}).encode()
req = urllib.request.Request(
    'https://equran.id/api/v2/shalat/kabkota', data=body,
    headers={'Content-Type':'application/json','User-Agent':'Mozilla/5.0',
             'Origin':'https://equran.id','Referer':'https://equran.id/apidev/shalat'},
    method='POST'
)
data = json.loads(urllib.request.urlopen(req).read())
for k in data['data']:
    print(k)
"
# Pastikan nama di config.json SAMA PERSIS (case-sensitive)
```

**Contoh yang BUKAN nama yang valid:**
- ❌ `garut` (kecil semua)
- ❌ `Kota Garut` (seharusnya `Kab. Garut` untuk kabupaten)
- ❌ `Garut Kota` (tidak ada level kecamatan)
- ✅ `Kab. Garut` (persis seperti di list)

## Jadwal Tidak Ter-update Otomatis

Daemon hanya fetch jadwal **saat bulan berganti** atau **pertama kali dijalankan**. Untuk force refresh:

```bash
# Hapus cache
rm ~/.local/share/adzan-notifier/jadwal.json

# Restart daemon
systemctl --user restart adzan-notifier

# Log akan menunjukkan jadwal ter-fetch ulang
tail -f ~/.local/share/adzan-notifier/logs/daemon.log
```

## Service Tidak Auto-start Setelah Reboot

```bash
# Cek apakah user service manager aktif
loginctl user-status

# Jika belum enable
systemctl --user enable adzan-notifier
systemctl --user start adzan-notifier

# Cek log jika gagal
journalctl --user -u adzan-notifier -p err
```

## Memory / CPU Usage Tinggi

Normalnya daemon menggunakan ~10MB RAM dan <0.1% CPU. Jika tinggi:
1. Cek log: `tail ~/.local/share/adzan-notifier/logs/daemon.log`
2. Cek apakah ada loop error (API selalu gagal)
3. Restart: `systemctl --user restart adzan-notifier`
4. Jika terus bermasalah, tambahkan retry delay:
   ```python
   # Di main(): ganti time.sleep(30) jadi time.sleep(60)
   ```
