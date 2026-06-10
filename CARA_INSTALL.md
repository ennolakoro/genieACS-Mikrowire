# Panduan Instalasi GenieACS Multi-Tenant dengan Kustomisasi UI & Menu

Proyek ini telah dikonfigurasi agar secara otomatis menerapkan kustomisasi tampilan (Dark Mode, logo) serta struktur menu kustom (**Overview, Devices, Faults, Admin/Provisions/Presets/Virtual Parameters**) yang diambil dari folder `genieacs-main`.

Setiap klien (tenant) baru yang ditambahkan akan otomatis mendapatkan tampilan dan konfigurasi database kustom tersebut.

---

## 🛠️ Prasyarat (Prerequisites)
Sebelum memulai instalasi di server VPS Linux Anda, pastikan:
1. **OS Server**: Ubuntu (disarankan 20.04 LTS atau 22.04 LTS).
2. **Docker & Docker Compose**: Sudah terinstal di server.
3. **HestiaCP**: Sudah terinstal di server (opsional, jika ingin mengintegrasikan domain dan SSL otomatis).

---

## 🚀 Langkah-Langkah Instalasi

### Langkah 1: Unggah File Proyek ke VPS
Unggah seluruh isi folder proyek `GenieACS_Hestia_Scripts` ini ke direktori `/opt/genieacs` di VPS Anda.

Struktur direktori di VPS harus terlihat seperti ini:
```text
/opt/genieacs/
├── Dockerfile
├── add_client.sh
├── suspend_client.sh
├── unsuspend_client.sh
├── backup_client.sh
├── setup_mongo.sh
├── db_template/          <-- Folder berisi dump database kustom
├── genieacs-src/         <-- Folder berisi source code GenieACS kustom (UI/CSS/Logo)
└── nginx_templates/      <-- Folder berisi template proxy HestiaCP
```

### Langkah 2: Berikan Izin Eksekusi Skrip (Execute Permission)
Hubungkan ke VPS Anda menggunakan SSH, lalu jalankan perintah berikut untuk memberikan izin eksekusi pada semua skrip `.sh`:
```bash
chmod +x /opt/genieacs/*.sh
```

### Langkah 3: Bangun Docker Image Kustom (UI/CSS/Logo)
Masuk ke direktori `/opt/genieacs` dan bangun image Docker kustom GenieACS yang memuat tema Dark Mode dan logo Anda:
```bash
cd /opt/genieacs
docker build -t genieacs:custom .
```
*Proses ini akan membuat Docker image bernama `genieacs:custom` yang akan digunakan oleh semua kontainer klien.*

### Langkah 4: Jalankan Setup MongoDB Bersama
Jalankan skrip setup MongoDB untuk membuat Docker network internal dan kontainer database MongoDB bersama yang hemat memori (RAM maks 400MB, cache WiredTiger 256MB):
```bash
./setup_mongo.sh
```

### Langkah 5: Tambahkan Klien Baru
Sekarang Anda dapat menambahkan klien/tenant pertama Anda. Jalankan perintah berikut:
```bash
./add_client.sh <nama_klien> <id_klien>
```
* **`<nama_klien>`**: Nama unik tanpa spasi (contoh: `mikrowire_1`).
* **`<id_klien>`**: Angka unik untuk alokasi port (contoh: `1` untuk klien pertama, `2` untuk klien kedua, dst.).

**Contoh eksekusi:**
```bash
./add_client.sh mikrowire_1 1
```

**Selama proses pembuatan klien:**
1. Skrip akan mengalokasikan port unik secara otomatis (misalnya port UI `3001`, port CWMP `7541` untuk ID `1`).
2. Skrip otomatis memulihkan berkas database kustom dari folder `db_template` ke database klien baru menggunakan `mongorestore`.
3. Anda akan ditanya: *"Apakah Anda ingin mengintegrasikan dengan HestiaCP? (y/n)"*
   * Jika memilih **`y`**, Anda akan diminta memasukkan username HestiaCP (default: `admin`), domain UI (default: `mikrowire_1.mikrowire.id`), dan domain CWMP (default: `cwmp-mikrowire_1.mikrowire.id`).
   * Skrip akan otomatis mengonfigurasi reverse proxy Nginx pada HestiaCP agar mengarah ke port kontainer Docker klien Anda.
4. Skrip otomatis memperbarui alamat ACS URL di konfigurasi database provisions klien baru agar menunjuk ke domain CWMP yang baru dibuat.

---

## 📁 Skrip Manajemen Klien Tambahan

### 1. Menangguhkan Klien (Suspend)
Jika klien menunggak atau tidak aktif, Anda bisa mematikan kontainernya untuk membebaskan kapasitas RAM VPS tanpa menghapus data mereka:
```bash
./suspend_client.sh <nama_klien>
```

### 2. Mengaktifkan Kembali Klien (Unsuspend)
Untuk menghidupkan kembali kontainer klien yang ditangguhkan:
```bash
./unsuspend_client.sh <nama_klien>
```

### 3. Backup Database Klien
Untuk mencadangkan database klien tertentu secara berkala:
```bash
./backup_client.sh <nama_klien>
```
*File backup akan disimpan di direktori `/opt/genieacs/backups/` dalam format `<nama_klien>_YYYY-MM-DD_HHMMSS.archive.gz`.*
