# API EQuran.id — Jadwal Shalat

API yang digunakan: `https://equran.id/api/v2/shalat`

## Endpoints

### 1. List Provinsi
```http
GET https://equran.id/api/v2/shalat/provinsi
```
**Response:**
```json
{
  "code": 200,
  "data": ["Aceh", "Bali", ..., "Sumatera Utara"]
}
```

### 2. List Kabupaten/Kota
```http
POST https://equran.id/api/v2/shalat/kabkota
Content-Type: application/json

{"provinsi": "Jawa Barat"}
```
**Response:**
```json
{
  "code": 200,
  "data": ["Kab. Bandung", "Kab. Garut", "Kota Bandung", ...]
}
```

### 3. Jadwal Bulanan
```http
POST https://equran.id/api/v2/shalat
Content-Type: application/json

{
  "provinsi": "Jawa Barat",
  "kabkota": "Kab. Garut",
  "bulan": 6,
  "tahun": 2026
}
```
**Response (sample):**
```json
{
  "code": 200,
  "data": {
    "provinsi": "Jawa Barat",
    "kabkota": "Kab. Garut",
    "bulan": 6,
    "tahun": 2026,
    "jadwal": [
      {
        "tanggal": 1,
        "tanggal_lengkap": "2026-06-01",
        "hari": "Senin",
        "imsak": "04:25",
        "subuh": "04:35",
        "terbit": "05:50",
        "dhuha": "06:20",
        "dzuhur": "11:52",
        "ashar": "15:13",
        "maghrib": "17:48",
        "isya": "18:58"
      }
    ]
  }
}
```

## Headers yang Diperlukan

```python
{
    "Content-Type": "application/json",
    "User-Agent": "Mozilla/5.0 ...",
    "Origin": "https://equran.id",
    "Referer": "https://equran.id/apidev/shalat"
}
```

Tanpa headers ini, request bisa 403 Forbidden (Cloudflare protection).

## Limitasi

- ✅ Granularitas: **kabupaten/kota** (bukan kecamatan/desa)
- ✅ 34 provinsi, 517 kota
- ✅ Data 1 tahun penuh
- ❌ Tidak ada API untuk mendapatkan jadwal spesifik kecamatan
- ⚠️ API tidak terdokumentasi secara resmi (scrape dari halaman docs), bisa berubah sewaktu-waktu

## Daftar Provinsi (per 2026)

```
Aceh, Bali, Banten, Bengkulu, D.I. Yogyakarta, DKI Jakarta, Gorontalo,
Jambi, Jawa Barat, Jawa Tengah, Jawa Timur, Kalimantan Barat, Kalimantan Selatan,
Kalimantan Tengah, Kalimantan Timur, Kalimantan Utara, Kepulauan Bangka Belitung,
Kepulauan Riau, Lampung, Maluku, Maluku Utara, Nusa Tenggara Barat,
Nusa Tenggara Timur, Papua, Papua Barat, Riau, Sulawesi Barat, Sulawesi Selatan,
Sulawesi Tengah, Sulawesi Tenggara, Sulawesi Utara, Sumatera Barat,
Sumatera Selatan, Sumatera Utara
```

## Cari Nama Kota yang Valid

```bash
# Script untuk lihat kab/kota di suatu provinsi
python3 -c "
import json, urllib.request
body = json.dumps({'provinsi': 'DKI Jakarta'}).encode()
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
```
