#!/bin/bash
# delete_client.sh <nama_klien>
# Contoh: ./delete_client.sh mikrowire_1

if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <nama_klien>"
    echo "Contoh: $0 mikrowire_1"
    exit 1
fi

CLIENT_NAME=$1
BASE_DIR="/opt/genieacs"
CLIENT_DIR="$BASE_DIR/clients/$CLIENT_NAME"
DB_NAME="genieacs_${CLIENT_NAME}"

# Validasi jika klien ada
if [ ! -d "$CLIENT_DIR" ]; then
    echo "[!] Klien dengan nama $CLIENT_NAME tidak ditemukan di $CLIENT_DIR!"
    exit 1
fi

echo "================================================================"
echo " Peringatan: Anda akan menghapus klien '$CLIENT_NAME'!"
echo " Tindakan ini akan menghapus secara permanen:"
echo " - Semua container Docker untuk klien ini"
echo " - Database MongoDB: $DB_NAME"
echo " - Folder konfigurasi dan log: $CLIENT_DIR"
echo "================================================================"
read -p "Apakah Anda yakin ingin melanjutkan? (y/N): " CONFIRM
CONFIRM=${CONFIRM:-n}

if [ "$CONFIRM" != "y" ] && [ "$CONFIRM" != "Y" ]; then
    echo "[-] Proses pembatalan penghapusan klien."
    exit 0
fi

# 1. Hentikan dan hapus container Docker beserta volumenya
echo "[+] Menghentikan dan menghapus container Docker untuk $CLIENT_NAME..."
cd "$CLIENT_DIR" || exit 1
if [ -f "docker-compose.yml" ]; then
    docker compose down -v
else
    echo "[!] File docker-compose.yml tidak ditemukan, mencoba stop container manual..."
    docker stop ${CLIENT_NAME}_ui ${CLIENT_NAME}_cwmp ${CLIENT_NAME}_nbi ${CLIENT_NAME}_fs 2>/dev/null
    docker rm ${CLIENT_NAME}_ui ${CLIENT_NAME}_cwmp ${CLIENT_NAME}_nbi ${CLIENT_NAME}_fs 2>/dev/null
fi

# 2. Hapus database MongoDB
echo "[+] Menghapus database MongoDB: $DB_NAME..."
docker exec -i genieacs_shared_mongo mongo "$DB_NAME" --eval "db.dropDatabase()"

# 3. Bersihkan HestiaCP (Jika terintegrasi)
if [ -f "/usr/local/hestia/bin/v-delete-web-domain" ]; then
    echo ""
    read -p "Apakah klien ini terintegrasi dengan HestiaCP? (y/n) [n]: " CHOOSE_HESTIA
    CHOOSE_HESTIA=${CHOOSE_HESTIA:-n}
    if [ "$CHOOSE_HESTIA" = "y" ] || [ "$CHOOSE_HESTIA" = "Y" ]; then
        read -p "Username HestiaCP [admin]: " HESTIA_USER
        HESTIA_USER=${HESTIA_USER:-admin}
        
        DOMAIN_UI="${CLIENT_NAME}.mikrowire.id"
        read -p "Domain UI yang ingin dihapus [$DOMAIN_UI]: " DOMAIN_UI
        DOMAIN_UI=${DOMAIN_UI:-$DOMAIN_UI}

        echo "[+] Menghapus domain $DOMAIN_UI dari HestiaCP..."
        /usr/local/hestia/bin/v-delete-web-domain "$HESTIA_USER" "$DOMAIN_UI"
        echo "[+] Domain HestiaCP berhasil dihapus!"
    fi
fi

# 4. Hapus direktori klien
echo "[+] Menghapus direktori klien: $CLIENT_DIR..."
rm -rf "$CLIENT_DIR"

echo ""
echo "================================================================"
echo " Berhasil: Klien '$CLIENT_NAME' telah sepenuhnya dihapus!"
echo "================================================================"
