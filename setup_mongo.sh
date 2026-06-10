#!/bin/bash
# setup_mongo.sh
# Inisialisasi network dan shared MongoDB untuk GenieACS Multi-Tenant

BASE_DIR="/opt/genieacs"
MONGO_DIR="$BASE_DIR/mongo"

echo "=== Memulai Setup Shared MongoDB GenieACS ==="

# 1. Create Docker Network
if ! docker network ls | grep -q genieacs-net; then
    docker network create genieacs-net
    echo "[+] Network 'genieacs-net' berhasil dibuat."
else
    echo "[!] Network 'genieacs-net' sudah ada."
fi

# 2. Create Base Directories
mkdir -p "$MONGO_DIR"
mkdir -p "$BASE_DIR/clients"
mkdir -p "$BASE_DIR/scripts"
mkdir -p "$BASE_DIR/backups"
mkdir -p "$BASE_DIR/db_template"

# 3. Create Docker Compose for Shared MongoDB
cat <<EOF > "$BASE_DIR/docker-compose-mongo.yml"
version: '3.8'
services:
  mongodb:
    image: mongo:4.4
    container_name: genieacs_shared_mongo
    command: mongod --wiredTigerCacheSizeGB 0.25
    restart: always
    volumes:
      - $MONGO_DIR:/data/db
      - $BASE_DIR/backups:/backups
      - $BASE_DIR/db_template:/db_template:ro
    networks:
      - genieacs-net
    deploy:
      resources:
        limits:
          memory: 400M

networks:
  genieacs-net:
    external: true
EOF

# 4. Start Shared MongoDB
cd "$BASE_DIR"
docker compose -f docker-compose-mongo.yml up -d

echo "[+] Shared MongoDB berhasil dijalankan!"
echo "=== Setup Selesai ==="
