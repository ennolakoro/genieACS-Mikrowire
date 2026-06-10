#!/bin/bash
# add_client.sh <nama_klien> <id_klien>
# Contoh: ./add_client.sh mikrowire_1 1

if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <nama_klien> <id_klien>"
    echo "Contoh: $0 mikrowire_1 1"
    echo "ID Klien harus unik (berupa angka, contoh: 1, 2, 3)"
    exit 1
fi

CLIENT_NAME=$1
CLIENT_ID=$2
BASE_DIR="/opt/genieacs"
CLIENT_DIR="$BASE_DIR/clients/$CLIENT_NAME"

# Validasi jika klien sudah ada
if [ -d "$CLIENT_DIR" ]; then
    echo "[!] Klien dengan nama $CLIENT_NAME sudah ada!"
    exit 1
fi

# Perhitungan Port Berdasarkan ID (Mencegah konflik port)
PORT_UI=$((3000 + CLIENT_ID))
PORT_CWMP=$((7540 + CLIENT_ID))
PORT_NBI=$((7550 + CLIENT_ID))
PORT_FS=$((7560 + CLIENT_ID))

DB_NAME="genieacs_${CLIENT_NAME}"

# 1. Buat direktori klien dan subfolder logs
mkdir -p "$CLIENT_DIR"
mkdir -p "$CLIENT_DIR/logs"

# Tanya username & password CWMP (Optional / dengan nilai default)
echo ""
echo "---[ Konfigurasi Keamanan CWMP/ACS URL ]---"
read -p "Username untuk ACS CWMP (Modem -> ACS) [CPE]: " INPUT_CWMP_USER
CWMP_USER=${INPUT_CWMP_USER:-CPE}

read -p "Password untuk ACS CWMP (Modem -> ACS) [CPE]: " INPUT_CWMP_PASS
CWMP_PASS=${INPUT_CWMP_PASS:-CPE}

# 2. Generate env file
cat <<EOF > "$CLIENT_DIR/genieacs.env"
GENIEACS_MONGODB_CONNECTION_URL=mongodb://genieacs_shared_mongo:27017/${DB_NAME}
GENIEACS_UI_JWT_SECRET=secret_${CLIENT_NAME}_$(date +%s)
GENIEACS_CWMP_ACCESS_LOG_FILE=/var/log/genieacs/genieacs-cwmp-access.yaml
GENIEACS_NBI_ACCESS_LOG_FILE=/var/log/genieacs/genieacs-nbi-access.yaml
GENIEACS_FS_ACCESS_LOG_FILE=/var/log/genieacs/genieacs-fs-access.yaml
GENIEACS_UI_ACCESS_LOG_FILE=/var/log/genieacs/genieacs-ui-access.yaml
GENIEACS_DEBUG_FILE=/var/log/genieacs/genieacs-debug.yaml
GENIEACS_CWMP_USER=${CWMP_USER}
GENIEACS_CWMP_PASSWORD=${CWMP_PASS}
EOF

# 3. Generate docker-compose.yml (Menggunakan image custom genieacs:custom)
cat <<EOF > "$CLIENT_DIR/docker-compose.yml"
version: '3.8'
services:
  genieacs-ui:
    image: genieacs:custom
    container_name: ${CLIENT_NAME}_ui
    command: ["genieacs-ui"]
    restart: always
    env_file: genieacs.env
    ports:
      - "127.0.0.1:${PORT_UI}:3000"
    volumes:
      - ./logs:/var/log/genieacs
    networks:
      - genieacs-net
    depends_on:
      - genieacs-fs
      - genieacs-nbi
      - genieacs-cwmp
    deploy:
      resources:
        limits:
          memory: 150M

  genieacs-cwmp:
    image: genieacs:custom
    container_name: ${CLIENT_NAME}_cwmp
    command: ["genieacs-cwmp"]
    restart: always
    env_file: genieacs.env
    ports:
      - "${PORT_CWMP}:7547"
    volumes:
      - ./logs:/var/log/genieacs
    networks:
      - genieacs-net
    deploy:
      resources:
        limits:
          memory: 100M

  genieacs-nbi:
    image: genieacs:custom
    container_name: ${CLIENT_NAME}_nbi
    command: ["genieacs-nbi"]
    restart: always
    env_file: genieacs.env
    ports:
      - "127.0.0.1:${PORT_NBI}:7557"
    volumes:
      - ./logs:/var/log/genieacs
    networks:
      - genieacs-net
    deploy:
      resources:
        limits:
          memory: 100M

  genieacs-fs:
    image: genieacs:custom
    container_name: ${CLIENT_NAME}_fs
    command: ["genieacs-fs"]
    restart: always
    env_file: genieacs.env
    ports:
      - "127.0.0.1:${PORT_FS}:7567"
    volumes:
      - ./logs:/var/log/genieacs
    networks:
      - genieacs-net
    deploy:
      resources:
        limits:
          memory: 50M

networks:
  genieacs-net:
    external: true
EOF

# 4. Jalankan container klien
echo "[+] Menjalankan container GenieACS untuk klien $CLIENT_NAME..."
cd "$CLIENT_DIR"
docker compose up -d

# 5. Restore DB Template jika ada
if docker exec genieacs_shared_mongo ls /db_template > /dev/null 2>&1; then
    echo "[+] Menemukan folder db_template. Melakukan mongorestore..."
    docker exec -i genieacs_shared_mongo mongorestore --db "$DB_NAME" --drop /db_template/
else
    echo "[!] Folder db_template kosong atau tidak termount. Lewati restorasi."
fi

# 6. Integrasi HestiaCP (Optional/Interactive)
INTEGRATE_HESTIA="n"
echo ""
read -p "Apakah Anda ingin mengintegrasikan dengan HestiaCP? (y/n) [n]: " CHOOSE_HESTIA
INTEGRATE_HESTIA=${CHOOSE_HESTIA:-n}

DOMAIN_UI="${CLIENT_NAME}.mikrowire.id"
DOMAIN_CWMP="cwmp-${CLIENT_NAME}.mikrowire.id"
HESTIA_USER="admin"

if [ "$INTEGRATE_HESTIA" = "y" ] || [ "$INTEGRATE_HESTIA" = "Y" ]; then
    read -p "Username HestiaCP [admin]: " INPUT_USER
    HESTIA_USER=${INPUT_USER:-admin}

    read -p "Domain Utama UI [$DOMAIN_UI]: " INPUT_DOMAIN_UI
    DOMAIN_UI=${INPUT_DOMAIN_UI:-$DOMAIN_UI}

    read -p "Domain CWMP [$DOMAIN_CWMP]: " INPUT_DOMAIN_CWMP
    DOMAIN_CWMP=${INPUT_DOMAIN_CWMP:-$DOMAIN_CWMP}

    if [ -f "/usr/local/hestia/bin/v-add-web-domain" ]; then
        echo "[+] Mengonfigurasi HestiaCP..."
        
        # Salin Nginx template ke HestiaCP jika belum ada
        if [ ! -f "/usr/local/hestia/data/templates/web/nginx/genieacs.tpl" ]; then
            echo "    - Menyalin Nginx templates ke HestiaCP..."
            mkdir -p "$BASE_DIR/scripts/nginx_templates"
            cp "$BASE_DIR/scripts/nginx_templates/genieacs.tpl" "/usr/local/hestia/data/templates/web/nginx/" 2>/dev/null || cp "$BASE_DIR/nginx_templates/genieacs.tpl" "/usr/local/hestia/data/templates/web/nginx/" 2>/dev/null
            cp "$BASE_DIR/scripts/nginx_templates/genieacs.stpl" "/usr/local/hestia/data/templates/web/nginx/" 2>/dev/null || cp "$BASE_DIR/nginx_templates/genieacs.stpl" "/usr/local/hestia/data/templates/web/nginx/" 2>/dev/null
        fi

        # Tambah domain utama di HestiaCP
        /usr/local/hestia/bin/v-add-web-domain "$HESTIA_USER" "$DOMAIN_UI"
        
        # Ubah template web domain HestiaCP ke genieacs
        /usr/local/hestia/bin/v-change-web-domain-tpl "$HESTIA_USER" "$DOMAIN_UI" "genieacs"
        
        # Tambah alias domain CWMP
        /usr/local/hestia/bin/v-add-web-domain-alias "$HESTIA_USER" "$DOMAIN_UI" "$DOMAIN_CWMP"

        # Tulis proxy include files
        CONF_DIR="/home/$HESTIA_USER/conf/web/$DOMAIN_UI"
        mkdir -p "$CONF_DIR"
        
        # Proxy HTTP
        cat <<EOF > "$CONF_DIR/nginx.genieacs_proxy.conf"
location / {
    proxy_set_header Host \$host;
    proxy_set_header X-Real-IP \$remote_addr;
    proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto \$scheme;
    
    proxy_http_version 1.1;
    proxy_set_header Upgrade \$http_upgrade;
    proxy_set_header Connection "upgrade";

    if (\$host = "$DOMAIN_UI") {
        proxy_pass http://127.0.0.1:${PORT_UI};
    }
    if (\$host = "$DOMAIN_CWMP") {
        proxy_pass http://127.0.0.1:${PORT_CWMP};
    }
}
EOF

        # Proxy HTTPS (SSL)
        cp "$CONF_DIR/nginx.genieacs_proxy.conf" "$CONF_DIR/nginx.genieacs_proxy.conf_ssl"

        # Rebuild domain config dan restart Nginx
        /usr/local/hestia/bin/v-rebuild-web-domain "$HESTIA_USER" "$DOMAIN_UI"
        echo "[+] Konfigurasi HestiaCP & Reverse Proxy selesai!"
    else
        echo "[!] Binary HestiaCP tidak ditemukan. Lewati konfigurasi otomatis HestiaCP."
    fi
else
    # Ganti binding 127.0.0.1 ke public (0.0.0.0) di docker-compose.yml jika tidak menggunakan HestiaCP
    echo "[+] Menonaktifkan integrasi HestiaCP. Membuka port UI secara publik..."
    # Menggunakan sed untuk mengubah 127.0.0.1:port ke port
    sed -i "s/127.0.0.1:\${PORT_UI}/\${PORT_UI}/g" "$CLIENT_DIR/docker-compose.yml"
    
    # Restart container agar perubahan port diterapkan
    echo "[+] Restarting containers to apply port exposure..."
    (cd "$CLIENT_DIR" && docker compose up -d --force-recreate >/dev/null 2>&1)
fi

# 7. Sesuaikan ACS URL di provisions database klien
SERVER_IP=$(curl -s https://ipinfo.io/ip || echo "localhost")
if [ "$INTEGRATE_HESTIA" = "y" ] || [ "$INTEGRATE_HESTIA" = "Y" ]; then
    ACS_URL="http://${DOMAIN_CWMP}"
    UI_URL="http://${DOMAIN_UI}"
else
    ACS_URL="http://${SERVER_IP}:${PORT_CWMP}"
    UI_URL="http://${SERVER_IP}:${PORT_UI}"
fi

echo "[+] Menyesuaikan ACS URL di provisions database ke: $ACS_URL"
docker exec -i genieacs_shared_mongo mongo "$DB_NAME" --eval "
  db.provisions.find().forEach(function(doc) {
    if (doc.code) {
      var oldCode = doc.code;
      // Ganti URL default / placeholder apa saja ke URL klien baru
      doc.code = doc.code.replace(/http:\/\/acs\.mikrowire\.id/g, '${ACS_URL}');
      doc.code = doc.code.replace(/https:\/\/acs\.mikrowire\.id/g, '${ACS_URL}');
      doc.code = doc.code.replace(/http:\/\/localhost:7547/g, '${ACS_URL}');
      if (oldCode !== doc.code) {
        db.provisions.replaceOne({_id: doc._id}, doc);
        print('    - Berhasil memperbarui provision ID: ' + doc._id);
      }
    }
  });
"

echo ""
echo "================================================================"
echo " Berhasil: Klien '$CLIENT_NAME' (ID: $CLIENT_ID) telah dibuat!"
echo "================================================================"
echo " - Database MongoDB  : $DB_NAME (Shared)"
echo " - Direktori Klien   : $CLIENT_DIR"
echo " - Log Klien         : $CLIENT_DIR/logs"
echo ""
echo " ---[ Konfigurasi Port & URL ]---"
echo " UI URL / Port       : ${UI_URL} / Port: ${PORT_UI}"
echo " CWMP URL / Port     : ${ACS_URL} / Port: ${PORT_CWMP}"
echo " ACS Username        : ${CWMP_USER}"
echo " ACS Password        : ${CWMP_PASS}"
echo " NBI Port (Local)    : $PORT_NBI"
echo " FS Port (Local)     : $PORT_FS"
echo "======================================================================"
