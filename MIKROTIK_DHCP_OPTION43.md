========================================================================
 TUTORIAL AUTO-PROVISIONING ACS URL VIA MIKROTIK (DHCP OPTION 43)
========================================================================
Topologi: MIKROTIK -> OLT -> CLIENT (ONU/ONT)

Agar modem/ONU client secara otomatis mendapatkan URL GenieACS (ACS URL) 
saat menerima IP Address dari DHCP server MikroTik tanpa perlu setting 
manual satu per satu, kita dapat memanfaatkan DHCP Option 43.

------------------------------------------------------------------------
A. CARA MENGHITUNG NILAI HEX DHCP OPTION 43
------------------------------------------------------------------------
Format nilai Option 43 untuk TR-069 adalah sebagai berikut:
0x[Sub-Option-Code][Length-in-Hex][ACS-URL-in-Hex]

1. Sub-Option-Code:
   Umumnya menggunakan kode `01` (Standard sub-option untuk ACS URL).
2. Length-in-Hex:
   Panjang karakter URL ACS Anda yang diubah ke bentuk Hex.
3. ACS-URL-in-Hex:
   Alamat URL CWMP klien Anda yang dikoversikan ke teks Hexadecimal.

CONTOH KASUS:
Klien Anda menggunakan port CWMP: 7541 (Client ID: 1)
Alamat IP VPS Anda: 23.226.130.104
ACS URL Klien: http://23.226.130.104:7541

* Jumlah karakter "http://23.226.130.104:7541" adalah 26 karakter.
  Angka 26 dalam bentuk Hex adalah: 1a
* String URL ke Hex:
  h=68, t=74, t=74, p=70, :=3a, /=2f, /=2f, 2=32, 3=33, .=2e, 2=32, 2=32, 
  6=36, .=2e, 1=31, 3=33, 0=30, .=2e, 1=31, 0=30, 4=34, :=3a, 7=37, 5=5, 
  4=34, 1=31
  Hasil Hex URL: 687474703a2f2f32332e3232362e3133302e3130343a37353431

Maka, Nilai Option 43 gabungannya adalah:
0x011a687474703a2f2f32332e3232362e3133302e3130343a37353431

------------------------------------------------------------------------
B. LANGKAH KONFIGURASI DI MIKROTIK
------------------------------------------------------------------------

Langkah 1: Membuat DHCP Option 43
Buka Terminal MikroTik Anda, lalu jalankan perintah berikut:

/ip dhcp-server option
add code=43 name=genieacs-url-klien1 value="0x011a687474703a2f2f32332e3232362e3133302e3130343a37353431"

*(Catatan: Sesuaikan value hex di atas jika IP VPS atau port CWMP klien berbeda)*

---

Langkah 2: Terapkan ke DHCP Server Network
Pasangkan DHCP Option yang baru dibuat ke network DHCP yang mengarah ke OLT/modem client.

Contoh jika IP segment jaringan client adalah 192.168.100.0/24:

/ip dhcp-server network
set [find address="192.168.100.0/24"] dhcp-option=genieacs-url-klien1

*(Ganti "192.168.100.0/24" dengan segmen IP jaringan client Anda).*

------------------------------------------------------------------------
C. METODE ALTERNATIF (PLAIN STRING HEX)
------------------------------------------------------------------------
Beberapa jenis/merk modem (misal beberapa tipe Huawei/ZTE) terkadang 
tidak mengenali format sub-option `01`. Mereka hanya membutuhkan URL 
mentah dalam bentuk Hex.

Jika metode di atas gagal, coba buat DHCP Option 43 tanpa kode `01` 
dan tanpa ukuran panjang di depannya (langsung URL Hex):

/ip dhcp-server option
add code=43 name=genieacs-plain-klien1 value="0x687474703a2f2f32332e3232362e3133302e3130343a37353431"

Lalu pasangkan ke DHCP Network seperti biasa:
/ip dhcp-server network
set [find address="192.168.100.0/24"] dhcp-option=genieacs-plain-klien1

------------------------------------------------------------------------
D. VERIFIKASI & PENGUJIAN
------------------------------------------------------------------------
1. Pastikan fitur TR-069 pada ONU/modem client telah aktif dan mode 
   koneksi WAN menggunakan DHCP (bukan static).
2. Hubungkan ONU ke OLT.
3. Setelah ONU mendapatkan IP address dari MikroTik, periksa log di
   GenieACS UI (port 3001) apakah device baru dengan Serial Number ONU
   tersebut muncul secara otomatis di menu Devices.
4. Anda juga bisa mengecek status DHCP Lease di MikroTik untuk memastikan
   ONU mengambil IP DHCP dengan benar.
========================================================================
