#!/bin/bash
# Script untuk mengambil dan menguji proxy (disesuaikan untuk GitHub Actions)

# URL API untuk cek proxy
api_check="https://api.vipren.biz.id/?ip={IP_ADDRESS}:{PORT}"

# File output
HIDUP_file="HIDUP.txt"  # Ganti nama file
MATI_file="MATI.txt"     # Ganti nama file
temp_file="temp_proxies.txt"

# Inisialisasi hitungan
HIDUP_count=0  # Ganti hidup_count dengan HIDUP_count
MATI_count=0   # Ganti mati_count dengan MATI_count
HIDUP_id_count=0  # Ganti hidup_id_count dengan HIDUP_id_count
HIDUP_sg_count=0  # Ganti hidup_sg_count dengan HIDUP_sg_count
MATI_id_count=0   # Ganti mati_id_count dengan MATI_id_count
MATI_sg_count=0   # Ganti mati_sg_count dengan MATI_sg_count

# Bersihkan file sebelumnya
> "$HIDUP_file"
> "$MATI_file"
> "$temp_file"

# Fungsi untuk menampilkan log
log_success() {
    echo "✅ $1"
}

log_error() {
    echo "❌ $1"
}

log_info() {
    echo "🔍 $1"
}

log_warning() {
    echo "⚠️ $1"
}

# Fungsi untuk menguji proxy
test_proxy() {
    local ip=$1
    local port=$2
    log_info "Mengambil proxy dari negara: $country"  # Log proses pengecekan

    # Gunakan API untuk mengecek IP
    response=$(curl -s "https://api.vipren.biz.id/?ip=$ip:$port")
    
    # Parsing respons JSON
    proxy_status=$(echo "$response" | jq -r '.proxyStatus')  # ✅ ACTIVE ✅ atau ❌ DEAD ❌
    country_code=$(echo "$response" | jq -r '.countryCode')  # Kode negara (contoh: HK, ID, SG)
    org=$(echo "$response" | jq -r '.isp')  # Nama organisasi/ISP

    # Jika country_code null, set ke "UNKNOWN"
    if [[ "$country_code" == "null" || -z "$country_code" ]]; then
        country_code="UNKNOWN"
    fi

    if [[ "$proxy_status" == "✅ ACTIVE ✅" && ( "$country_code" == "ID" || "$country_code" == "SG" ) ]]; then
        # Proxy HIDUP
        echo "$ip,$port,$country_code,$org" >> "$HIDUP_file"
        HIDUP_count=$((HIDUP_count+1))

        # Hitung jumlah proxy HIDUP berdasarkan negara
        if [[ "$country_code" == "ID" ]]; then
            HIDUP_id_count=$((HIDUP_id_count+1))
        elif [[ "$country_code" == "SG" ]]; then
            HIDUP_sg_count=$((HIDUP_sg_count+1))
        fi

        log_success "✅ HIDUP: $ip:$port ($country_code, $org)"
    else
        # Proxy MATI
        echo "$ip,$port,$country_code,$org" >> "$MATI_file"
        MATI_count=$((MATI_count+1))

        # Hitung jumlah proxy MATI berdasarkan negara
        if [[ "$country_code" == "ID" ]]; then
            MATI_id_count=$((MATI_id_count+1))
        elif [[ "$country_code" == "SG" ]]; then
            MATI_sg_count=$((MATI_sg_count+1))
        fi

        log_error "❌ MATI: $ip:$port ($country_code, $org)"
    fi

    # Tampilkan jumlah yang sudah diuji
    echo "✅ HIDUP: $HIDUP_count, ❌ MATI: $MATI_count"
}

# Mengambil proxy dari API
countries=("ID" "SG")

for country in "${countries[@]}"; do
    log_info "Mengambil proxy dari negara: $country"
    response=$(curl -s --max-time 30 "https://cfip.ashrvpn.v6.army/?country=$country")

    if [[ -n "$response" ]]; then
        proxies=$(echo "$response" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+:[0-9]+')

        while IFS=':' read -r ip port; do
            test_proxy "$ip" "$port"
        done <<< "$proxies"
    else
        log_warning "Tidak ada proxy yang ditemukan untuk negara: $country"
    fi

    sleep 1
done

# Kirim notifikasi ke Telegram setelah selesai
message="*✅ Jumlah Proxy Ditemukan*%0A%0A"
message+="*✅ HIDUP:* \`$HIDUP_count\`%0A"
message+="  \\- *Indonesia 🇮🇩:* \`$HIDUP_id_count\`%0A"
message+="  \\- *Singapura 🇸🇬:* \`$HIDUP_sg_count\`%0A"
message+="*❌ MATI:* \`$MATI_count\`%0A"
message+="  \\- *Indonesia 🇲🇨:* \`$MATI_id_count\`%0A"
message+="  \\- *Singapura 🇸🇬:* \`$MATI_sg_count\`%0A%0A"
message+="*🎉 Proxy Check Selesaii!*"

curl -s -X POST "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendMessage" \
    -d "chat_id=$TELEGRAM_CHAT_ID" \
    -d "text=$message" \
    -d "parse_mode=MarkdownV2"

log_success "Notifikasi Telegram terkirim!"
