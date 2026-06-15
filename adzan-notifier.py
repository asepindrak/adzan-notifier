#!/usr/bin/env python3
"""
Adzan Notifier Daemon
- Mengambil jadwal shalat bulanan dari API equran.id
- Cache jadwal 1 bulan di ~/.local/share/adzan-notifier/jadwal.json
- Setiap 30 detik cek waktu sekarang vs jadwal
- Saat waktunya tiba: kirim notifikasi Telegram + bunyikan adzan di Ubuntu
"""

import json
import os
import sys
import time
import subprocess
import urllib.request
import urllib.error
from datetime import datetime, timedelta
from pathlib import Path

# --- Paths ---
CONFIG_PATH = Path.home() / ".config/adzan-notifier/config.json"
CACHE_PATH = Path.home() / ".local/share/adzan-notifier/jadwal.json"
LOG_PATH = Path.home() / ".local/share/adzan-notifier/logs/daemon.log"
STATE_PATH = Path.home() / ".local/share/adzan-notifier/last_notified.json"

# --- Logging ---
def log(msg: str):
    ts = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    line = f"[{ts}] {msg}\n"
    LOG_PATH.parent.mkdir(parents=True, exist_ok=True)
    with LOG_PATH.open("a") as f:
        f.write(line)
    print(line, end="", flush=True)


def load_config() -> dict:
    if not CONFIG_PATH.exists():
        log(f"ERROR: config not found at {CONFIG_PATH}")
        sys.exit(1)
    cfg = json.loads(CONFIG_PATH.read_text())

    # Fail loudly if placeholders not replaced
    tg = cfg.get("telegram", {})
    token = tg.get("bot_token", "")
    chat_id = tg.get("chat_id", "")

    placeholder_pattern = {"ISI_", "xxxx", "XXXX", "<TOKEN>", "<CHAT_ID>", "1234567890:"}
    for pp in placeholder_pattern:
        if pp in token:
            sys.exit(f"❌ ERROR: bot_token masih placeholder ({pp}). Edit ~/.config/adzan-notifier/config.json")
        if pp in chat_id:
            sys.exit(f"❌ ERROR: chat_id masih placeholder ({pp}). Edit ~/.config/adzan-notifier/config.json")

    return cfg


def fetch_jadwal(provinsi: str, kabkota: str, bulan: int, tahun: int) -> dict | None:
    """Hit POST /api/v2/shalat dari equran.id"""
    url = "https://equran.id/api/v2/shalat"
    body = json.dumps({
        "provinsi": provinsi,
        "kabkota": kabkota,
        "bulan": bulan,
        "tahun": tahun,
    }).encode()
    headers = {
        "Content-Type": "application/json",
        "User-Agent": "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36",
        "Origin": "https://equran.id",
        "Referer": "https://equran.id/apidev/shalat",
    }
    req = urllib.request.Request(
        url, data=body, headers=headers, method="POST"
    )
    try:
        with urllib.request.urlopen(req, timeout=15) as r:
            data = json.loads(r.read())
            if data.get("code") == 200:
                return data.get("data")
            log(f"API returned non-200: {data}")
            return None
    except (urllib.error.URLError, urllib.error.HTTPError, TimeoutError) as e:
        log(f"Network error fetching jadwal: {e}")
        return None


def ensure_jadwal_cached(cfg: dict) -> dict | None:
    """Ambil jadwal bulan ini; cache ke disk. Refresh kalau beda bulan atau hari pertama."""
    now = datetime.now()
    bulan, tahun = now.month, now.year

    CACHE_PATH.parent.mkdir(parents=True, exist_ok=True)
    cached = None
    if CACHE_PATH.exists():
        try:
            cached = json.loads(CACHE_PATH.read_text())
        except json.JSONDecodeError:
            cached = None

    need_refresh = True
    if cached:
        if (cached.get("bulan") == bulan
            and cached.get("tahun") == tahun
            and cached.get("provinsi") == cfg["provinsi"]
            and cached.get("kabkota") == cfg["kabkota"]):
            need_refresh = False

    if need_refresh:
        log(f"Fetching jadwal {bulan}/{tahun} untuk {cfg['kabkota']}, {cfg['provinsi']} ...")
        data = fetch_jadwal(cfg["provinsi"], cfg["kabkota"], bulan, tahun)
        if data is None:
            log("Gagal fetch jadwal. Pakai cache lama kalau ada.")
            return cached
        cached = data
        CACHE_PATH.write_text(json.dumps(data, ensure_ascii=False, indent=2))
        log(f"Jadwal tersimpan: {len(data.get('jadwal', []))} hari")

    return cached


def load_last_notified() -> dict:
    if STATE_PATH.exists():
        try:
            return json.loads(STATE_PATH.read_text())
        except json.JSONDecodeError:
            return {}
    return {}


def save_last_notified(state: dict):
    STATE_PATH.parent.mkdir(parents=True, exist_ok=True)
    STATE_PATH.write_text(json.dumps(state, ensure_ascii=False, indent=2))


def send_telegram(cfg: dict, text: str):
    bot_token = cfg["telegram"]["bot_token"]
    chat_id = cfg["telegram"]["chat_id"]
    if not bot_token or "ISI_BOT_TOKEN" in bot_token:
        log(f"Telegram belum dikonfig (skip). Pesan: {text}")
        return
    if not chat_id or "ISI_CHAT_ID" in chat_id:
        log(f"Telegram chat_id belum dikonfig (skip). Pesan: {text}")
        return

    url = f"https://api.telegram.org/bot{bot_token}/sendMessage"
    body = json.dumps({
        "chat_id": chat_id,
        "text": text,
        "parse_mode": "HTML",
    }).encode()
    req = urllib.request.Request(
        url, data=body, headers={"Content-Type": "application/json"}, method="POST"
    )
    try:
        with urllib.request.urlopen(req, timeout=10) as r:
            r.read()
        log(f"Telegram terkirim: {text[:60]}...")
    except (urllib.error.URLError, urllib.error.HTTPError, TimeoutError) as e:
        log(f"Gagal kirim Telegram: {e}")


def play_adhan(cfg: dict):
    """Bunyikan audio adzan di Ubuntu. Support MP3, OGG, WAV."""
    if not cfg.get("adhan", {}).get("enabled", True):
        return
    audio = cfg.get("adhan", {}).get("audio_file", "")
    if not audio or not Path(audio).exists():
        log(f"Audio file tidak ditemukan: {audio}")
        return

    ext = Path(audio).suffix.lower()

    # MP3: pakai ffmpeg → aplay (aplay tidak bisa MP3 native)
    if ext == ".mp3":
        if subprocess.run(["which", "ffmpeg"], capture_output=True).returncode != 0:
            log("MP3 detected tapi ffmpeg tidak ada. Install: sudo apt install ffmpeg")
            return
        try:
            # Decode MP3 → WAV stream dengan volume filter ke aplay
            vol = cfg.get("adhan", {}).get("volume", 80)
            # ffmpeg volume: 1.0 = 100%, 0.3 = 30%
            vol_ratio = max(0.0, min(1.0, vol / 100.0))
            p1 = subprocess.Popen(
                ["ffmpeg", "-hide_banner", "-loglevel", "error",
                 "-i", audio, "-filter:a", f"volume={vol_ratio}",
                 "-f", "wav", "-"],
                stdout=subprocess.PIPE, stderr=subprocess.DEVNULL,
            )
            p2 = subprocess.Popen(
                ["aplay", "-D", "default", "-q", "-"],
                stdin=p1.stdout, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
            )
            p1.stdout.close()
            p2.wait()
            p1.wait()
            log(f"Adzan diputar (MP3 via ffmpeg, vol {vol}%): {audio}")
            return
        except FileNotFoundError as e:
            log(f"Gagal play MP3: {e}")
            return

    # OGG/WAV/FLAC: langsung aplay (volume via alsamixer kalau perlu)
    vol = cfg.get("adhan", {}).get("volume", 80)
    for player in (["aplay", "-D", "default", "-q"], ["paplay"], ["aplay"]):
        try:
            args = player + [audio]
            # paplay support --volume (0-65535)
            if player[0] == "paplay" and vol:
                args.insert(1, f"--volume={int(vol * 655.35)}")
            subprocess.Popen(
                args,
                stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
            )
            log(f"Adzan diputar ({player[0]}, vol {vol}%): {audio}")
            return
        except FileNotFoundError:
            continue
    log("Tidak ada audio player yang tersedia (install pulseaudio-utils atau alsa-utils).")


def send_ubuntu_notification(title: str, body: str):
    """Native Ubuntu desktop notification."""
    try:
        subprocess.Popen(
            ["notify-send", "-u", "critical", "-i", "appointment-soon", title, body],
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
        )
    except FileNotFoundError:
        pass


def find_today(jadwal: list, day: int) -> dict | None:
    for row in jadwal:
        if row.get("tanggal") == day:
            return row
    return None


def check_and_notify(cfg: dict, jadwal: list):
    now = datetime.now()
    today = find_today(jadwal, now.day)
    if not today:
        return

    state = load_last_notified()
    date_key = now.strftime("%Y-%m-%d")
    state.setdefault(date_key, {})

    prayers = [
        ("imsak", "🌙 Imsak"),
        ("subuh", "🕌 Subuh (Fajar)"),
        ("terbit", "🌅 Terbit (Matahari)"),
        ("dhuha", "☀️ Dhuha"),
        ("dzuhur", "🕌 Dzuhur"),
        ("ashar", "🕌 Ashar"),
        ("maghrib", "🕌 Maghrib"),
        ("isya", "🕌 Isya"),
    ]

    current_hhmm = now.strftime("%H:%M")

    for key, label in prayers:
        waktu = today.get(key)
        if not waktu:
            continue
        # Skip imsak reminder kalau dinonaktifkan
        if key == "imsak" and not cfg.get("imsyak_reminder", False):
            continue
        # Skip notification untuk subuh, dzuhur, ashar, maghrib, isya kalau disable flag
        if key in ("subuh", "dzuhur", "ashar", "maghrib", "isya") and not cfg.get("notify_5_prayers", True):
            continue
        if current_hhmm == waktu and not state[date_key].get(key):
            msg = (
                f"<b>{label}</b>\n"
                f"🕐 {waktu} WIB\n"
                f"📍 {cfg['kabkota']}, {cfg['provinsi']}\n"
                f"📅 {today['hari']}, {today['tanggal_lengkap']}"
            )
            log(f"WAKTU {key.upper()} TIBA: {waktu}")
            send_telegram(cfg, msg)
            send_ubuntu_notification(f"Waktu {label}", f"Sekarang pukul {waktu}")
            # Bunyikan adzan hanya untuk 5 waktu wajib
            if key in ("subuh", "dzuhur", "ashar", "maghrib", "isya"):
                play_adhan(cfg)
            state[date_key][key] = True
            save_last_notified(state)


def main():
    log("=== adzan-notifier daemon start ===")
    cfg = load_config()
    log(f"Location: {cfg['kabkota']}, {cfg['provinsi']}")

    while True:
        try:
            data = ensure_jadwal_cached(cfg)
            if data:
                check_and_notify(cfg, data["jadwal"])
            else:
                log("Tidak ada jadwal tersedia, retry dalam 5 menit.")
        except Exception as e:
            log(f"Error di loop utama: {e}")
        # Cek setiap 30 detik supaya tidak meleset menitnya
        time.sleep(30)


if __name__ == "__main__":
    main()
