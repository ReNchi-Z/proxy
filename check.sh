#!/bin/bash
# Script untuk mengambil proxy IP dari cfip.ashrvpn.v6.army dan mengujinya menggunakan API

# URL untuk API Proxy Check
api_check="https://prod-test.jdevcloud.com/check?ip={IP_ADDRESS}&port={PORT}"

# File Output
output_file="proxies.txt"
temp_file="temp_proxies.txt"
valid_count=0
invalid_count=0

# Clear output file jika ada
> "$output_file"
> "$temp_file"

# Fungsi untuk menguji proxy menggunakan API
test_proxy() {
    local ip=$1
    local port=$2
    # Menampilkan proxy yang sedang diuji
    echo "Checking proxy: $ip:$port"

    response=$(curl -s "https://prod-test.jdevcloud.com/check?ip=$ip&port=$port")

    # Mengecek apakah response API mengandung success: true dan is_proxy: true
    success=$(echo "$response" | jq -r '.success')
    is_proxy=$(echo "$response" | jq -r '.is_proxy')
    country=$(echo "$response" | jq -r '.info.country')
    org=$(echo "$response" | jq -r '.info.org')

    # Menambahkan proxy yang diuji ke file, tanpa status valid/invalid
    if [[ "$success" == "true" && "$is_proxy" == "true" && ( "$country" == "ID" || "$country" == "SG" ) ]]; then
        echo "$ip,$port,$country,$org" >> "$temp_file"
        valid_count=$((valid_count+1))
    else
        invalid_count=$((invalid_count+1))
    fi

    # Menampilkan jumlah valid dan invalid proxies setelah setiap proxy diuji
    echo "Valid proxies: $valid_count, Invalid proxies: $invalid_count"
}

# Mengambil daftar kode negara
countries=("ID" "SG")

# Mengambil proxies untuk setiap negara
for country in "${countries[@]}"; do
    # Mengambil data proxies dengan timeout
    response=$(curl -s --max-time 30 "https://cfip.ashrvpn.v6.army/?country=$country")

    if [ -z "$response" ]; then
        continue
    else
        # Mendapatkan proxies dari data yang diterima
        proxies=$(echo "$response" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+:[0-9]+')
        
        # Menguji setiap proxy yang ditemukan
        while IFS=':' read -r ip port; do
            test_proxy "$ip" "$port"
        done <<< "$proxies"
    fi

    # Menunggu sebentar agar tidak membebani server
    sleep 1
done

# Menghapus duplikat dan menyimpan proxy yang valid ke file output
sort -u "$temp_file" > "$output_file"
rm "$temp_file"

# Kirim notifikasi ke Telegram jika selesai
message="Proxy check completed. Valid proxies: $valid_count, Invalid proxies: $invalid_count"
curl -s -X POST "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendMessage" -d "chat_id=$TELEGRAM_CHAT_ID" -d "text=$message"
