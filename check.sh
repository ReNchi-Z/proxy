#!/bin/bash
# Script untuk mengambil dan menguji proxy

# URL API untuk cek proxy
api_check="https://prod-test.jdevcloud.com/check?ip={IP_ADDRESS}&port={PORT}"

# File output
valid_file="valid_proxies.txt"
invalid_file="invalid_proxies.txt"
log_file="proxy_check.log"

declare -A valid_per_country
valid_count=0
invalid_count=0

# Bersihkan file sebelumnya
> "$valid_file"
> "$invalid_file"
> "$log_file"

# Fungsi untuk menguji proxy
test_proxy() {
    local ip=$1
    local port=$2
    echo "Checking proxy: $ip:$port" | tee -a "$log_file"

    response=$(curl -s --max-time 10 "https://prod-test.jdevcloud.com/check?ip=$ip&port=$port")
    
    if [[ -z "$response" ]]; then
        echo "API tidak merespons untuk proxy: $ip:$port" | tee -a "$log_file"
        echo "$ip,$port" >> "$invalid_file"
        ((invalid_count++))
        return
    fi

    success=$(echo "$response" | jq -r '.success')
    is_proxy=$(echo "$response" | jq -r '.is_proxy')
    country=$(echo "$response" | jq -r '.info.country')
    org=$(echo "$response" | jq -r '.info.org')

    if [[ "$success" == "true" && "$is_proxy" == "true" && ( "$country" == "ID" || "$country" == "SG" ) ]]; then
        echo "$ip,$port,$country,$org" >> "$valid_file"
        ((valid_count++))
        ((valid_per_country[$country]++))
    else
        echo "$ip,$port" >> "$invalid_file"
        ((invalid_count++))
    fi

    echo "✔ Valid: $valid_count, ❌ Invalid: $invalid_count" | tee -a "$log_file"
}

# Mengambil proxy dari API
countries=("ID" "SG")
for country in "${countries[@]}"; do
    response=$(curl -s --max-time 30 "https://cfip.ashrvpn.v6.army/?country=$country")
    
    if [[ -z "$response" ]]; then
        echo "Gagal mengambil proxy untuk $country" | tee -a "$log_file"
        continue
    fi

    proxies=$(echo "$response" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+:[0-9]+')

    while IFS=':' read -r ip port; do
        test_proxy "$ip" "$port"
    done <<< "$proxies"
    
    sleep 1
done

# Kirim notifikasi ke Telegram setelah selesai
message="✅ *Proxy Check Completed*\n\n✅ *Valid Proxies:* $valid_count\n❌ *Invalid Proxies:* $invalid_count\n"

if [[ ${#valid_per_country[@]} -gt 0 ]]; then
    message+="\n🌍 *Valid Proxies by Country:*\n"
    for country in "${!valid_per_country[@]}"; do
        message+="- *$country*: ${valid_per_country[$country]}\n"
    done
fi

message+="\n🎉 _Proxy Check Successful!_"

# Escape karakter khusus MarkdownV2 dengan benar
escaped_message=$(echo "$message" | sed -e 's/[_\*\+\-\.\!]/\\\1/g' -e 's/[#\&\%\$]/\\\1/g')

# Kirim ke Telegram
curl -s -X POST "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendMessage" \
    -d "chat_id=$TELEGRAM_CHAT_ID" \
    -d "text=$escaped_message" \
    -d "parse_mode=MarkdownV2"
