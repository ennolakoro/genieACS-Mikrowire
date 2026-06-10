#!/bin/bash
# backup_client.sh <nama_klien>
# Contoh: ./backup_client.sh mikrowire_1

if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <nama_klien>"
    echo "Contoh: $0 mikrowire_1"
    exit 1
fi

CLIENT_NAME=$1
BASE_DIR="/opt/genieacs"
CLIENT_DIR="$BASE_DIR/clients/$CLIENT_NAME"
BACKUP_DIR="$BASE_DIR/backups"
DB_NAME="genieacs_${CLIENT_NAME}"

# Validasi jika klien ada
if [ ! -d "$CLIENT_DIR" ]; then
    echo "[!] Klien dengan nama $CLIENT_NAME tidak ditemukan di $CLIENT_DIR!"
    exit 1
fi

# Pastikan container MongoDB sedang berjalan
if ! docker ps | grep -q genieacs_shared_mongo; then
    echo "[!] Container 'genieacs_shared_mongo' tidak sedang berjalan. Hidupkan MongoDB terlebih dahulu!"
    exit 1
fi

DATE_STR=$(date +%F_%H%M%S)
BACKUP_FILE="${CLIENT_NAME}_${DATE_STR}.archive.gz"

echo "=== Memulai Backup Database untuk Klien: $CLIENT_NAME ==="
echo "[+] Menjalankan mongodump di container..."

# Menjalankan mongodump ke shared folder /backups
docker exec -i genieacs_shared_mongo mongodump \
    --db "$DB_NAME" \
    --archive="/backups/$BACKUP_FILE" \
    --gzip

if [ $? -eq 0 ]; then
    echo "[+] Backup berhasil dibuat!"
    echo "    - File: $BACKUP_DIR/$BACKUP_FILE"
    echo "    - Ukuran: $(du -sh "$BACKUP_DIR/$BACKUP_FILE" 2>/dev/null | cut -f1 || echo 'N/A')"
else
    echo "[!] Backup gagal!"
    exit 1
fi
