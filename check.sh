#!/bin/bash
# Script untuk mengambil dan menguji proxy

# URL API untuk cek proxy
api_check="https://api.vipren.biz.id/?ip={IP_ADDRESS}:{PORT}"

# File output
valid_file="valid_proxies.txt"
invalid_file="invalid_proxies.txt"
temp_file="temp_proxies.txt"

# Inisialisasi hitungan
valid_count=0
invalid_count=0
valid_id_count=0  # Jumlah proxy valid dari Indonesia
valid_sg_count=0  # Jumlah proxy valid dari Singapura
invalid_id_count=0  # Jumlah proxy invalid dari Indonesia
invalid_sg_count=0  # Jumlah proxy invalid dari Singapura

# Bersihkan file sebelumnya
> "$valid_file"
> "$invalid_file"
> "$temp_file"

# Fungsi untuk menguji proxy
test_proxy() {
    local ip=$1
    local port=$2
    echo "Checking proxy: $ip:$port"  # Log proses pengecekan

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
        # Proxy valid
        echo "$ip,$port,$country_code,$org" >> "$valid_file"
        valid_count=$((valid_count+1))

        # Hitung jumlah proxy valid berdasarkan negara
        if [[ "$country_code" == "ID" ]]; then
            valid_id_count=$((valid_id_count+1))
        elif [[ "$country_code" == "SG" ]]; then
            valid_sg_count=$((valid_sg_count+1))
        fi
    else
        # Proxy invalid
        echo "$ip,$port,$country_code,$org" >> "$invalid_file"
        invalid_count=$((invalid_count+1))

        # Hitung jumlah proxy invalid berdasarkan negara
        if [[ "$country_code" == "ID" ]]; then
            invalid_id_count=$((invalid_id_count+1))
        elif [[ "$country_code" == "SG" ]]; then
            invalid_sg_count=$((invalid_sg_count+1))
        fi
    fi

    # Tampilkan jumlah yang sudah diuji
    echo "✔ Valid: $valid_count, ❌ Invalid: $invalid_count"
}

# Mengambil proxy dari API
countries=("ID" "SG")

for country in "${countries[@]}"; do
    response=$(curl -s --max-time 30 "https://cfip.ashrvpn.v6.army/?country=$country")

    if [[ -n "$response" ]]; then
        proxies=$(echo "$response" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+:[0-9]+')

        while IFS=':' read -r ip port; do
            test_proxy "$ip" "$port"
        done <<< "$proxies"
    fi

    sleep 1
done

# Kirim notifikasi ke Telegram setelah selesai
message="✅ *Proxy Check Completed*%0A%0A"
message+="✔ *Valid Proxies:* \`$valid_count\`%0A"
message+="  \\- *Indonesia \\(ID\\):* \`$valid_id_count\`%0A"
message+="  \\- *Singapura \\(SG\\):* \`$valid_sg_count\`%0A"
message+="❌ *Invalid Proxies:* \`$invalid_count\`%0A"
message+="  \\- *Indonesia \\(ID\\):* \`$invalid_id_count\`%0A"
message+="  \\- *Singapura \\(SG\\):* \`$invalid_sg_count\`%0A%0A"
message+="🎉 \\_Proxy Check Successful\\_\\!"

curl -s -X POST "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendMessage" \
    -d "chat_id=$TELEGRAM_CHAT_ID" \
    -d "text=$message" \
    -d "parse_mode=MarkdownV2"
