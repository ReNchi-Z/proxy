#!/bin/bash
# Script untuk mengambil dan menguji proxy

# URL API untuk cek proxy
api_check="https://prod-test.jdevcloud.com/check?ip={IP_ADDRESS}&port={PORT}"

# File output
valid_file="valid_proxies.txt"
invalid_file="invalid_proxies.txt"
temp_file="temp_proxies.txt"

# Inisialisasi hitungan
valid_count=0
invalid_count=0

# Bersihkan file sebelumnya
> "$valid_file"
> "$invalid_file"
> "$temp_file"

# Fungsi untuk menguji proxy
test_proxy() {
    local ip=$1
    local port=$2
    echo "Checking proxy: $ip:$port"  # Log proses pengecekan

    response=$(curl -s "https://prod-test.jdevcloud.com/check?ip=$ip&port=$port")
    
    success=$(echo "$response" | jq -r '.success')
    is_proxy=$(echo "$response" | jq -r '.is_proxy')
    country=$(echo "$response" | jq -r '.info.country')
    org=$(echo "$response" | jq -r '.info.org')

    if [[ "$success" == "true" && "$is_proxy" == "true" && ( "$country" == "ID" || "$country" == "SG" ) ]]; then
        echo "$ip,$port,$country,$org" >> "$valid_file"
        valid_count=$((valid_count+1))
    else
        echo "$ip,$port" >> "$invalid_file"
        invalid_count=$((invalid_count+1))
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
message="✅ *Proxy Check Completed*\n\n✔ *Valid Proxies:* $valid_count\n❌ *Invalid Proxies:* $invalid_count\n\n🎉 _Proxy Check Successful!_"

curl -s -X POST "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendMessage" \
    -d "chat_id=$TELEGRAM_CHAT_ID" \
    -d "text=$message" \
    -d "parse_mode=MarkdownV2"
