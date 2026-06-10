#!/bin/bash
# suspend_client.sh <nama_klien>
# Contoh: ./suspend_client.sh mikrowire_1

if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <nama_klien>"
    echo "Contoh: $0 mikrowire_1"
    exit 1
fi

CLIENT_NAME=$1
BASE_DIR="/opt/genieacs"
CLIENT_DIR="$BASE_DIR/clients/$CLIENT_NAME"

# Validasi jika klien ada
if [ ! -d "$CLIENT_DIR" ]; then
    echo "[!] Klien dengan nama $CLIENT_NAME tidak ditemukan di $CLIENT_DIR!"
    exit 1
fi

echo "=== Menangguhkan Klien: $CLIENT_NAME ==="
cd "$CLIENT_DIR" || exit 1

if [ -f "docker-compose.yml" ]; then
    echo "[+] Menghentikan container GenieACS untuk $CLIENT_NAME..."
    docker compose stop
    echo "[+] Klien $CLIENT_NAME berhasil ditangguhkan (containers stopped)."
else
    echo "[!] File docker-compose.yml tidak ditemukan di $CLIENT_DIR!"
    exit 1
fi
