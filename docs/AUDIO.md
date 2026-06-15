# Setup Audio Adzan

## Format yang Didukung

| Format | Backend | Ukuran Typical | Kualitas |
|---|---|---|---|
| **MP3** | ffmpeg + aplay | 2-10 MB | Bagus (192kbps+) |
| **OGG Vorbis** | aplay | 2-8 MB | Bagus |
| **WAV** | aplay | 30-50 MB | Lossless |
| **FLAC** | aplay | 15-25 MB | Lossless + compressed |

**Rekomendasi:** MP3 192kbps (ukuran kecil, kualitas bagus) atau OGG.

## Cara Mendapatkan File Adzan

### 1. Rekam Sendiri
```bash
# Rekam dari mic (atau langsung dari YouTube via yt-dlp)
yt-dlp -x --audio-format mp3 "URL_ADZAN_DI_YOUTUBE"
```

### 2. Download dari Sumber Islami
- [EQuran.id](https://equran.id) — qari terkenal
- [MP3Quran.net](https://mp3quran.net)
- Archive.org — search "adhan mp3"
- Telegram channels: @mp3adzan, @adhanmp3

### 3. Copy dari HP / USB
```bash
cp /media/usb/adzan.mp3 ~/.local/share/sounds/adzan.mp3
```

## Letakkan di Lokasi Standar

```bash
mkdir -p ~/.local/share/sounds
cp /path/ke/adzan.mp3 ~/.local/share/sounds/adzan.mp3
```

Atau mana saja — yang penting diset path-nya di `config.json`:
```json
"adhan": {
  "audio_file": "/path/ke/adzan.mp3"
}
```

## Test Audio

```bash
# Test mp3
ffmpeg -hide_banner -i ~/.local/share/sounds/adzan.mp3 -f wav - | aplay -

# Test ogg/wav
aplay ~/.local/share/sounds/adzan.ogg
```

## Cek Speaker Default

```bash
# Lihat semua output device
aplay -l

# Cek default sink (PulseAudio)
pactl info | grep "Default Sink"

# Ganti default sink (kalau bunyi keluar di HDMI padahal mau di speaker)
pactl set-default-sink alsa_output.pci-0000_XX_XX.X.analog-stereo
```

## Custom Volume

Di `config.json`:
```json
"adhan": { "volume": 30 }
```

Range 0-100. Default 80.

## Tips

- **Durasi 3-5 menit** = adzan lengkap (dengan echo & tarhim)
- **Durasi 30-60 detik** = adzan pendek
- **Sample rate 44.1kHz atau 48kHz** = standard audio
- **Mono lebih baik** untuk speaker kecil, **stereo** untuk speaker besar
