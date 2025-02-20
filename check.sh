#!/bin/bash

# File Output
output_file="proxies.txt"
temp_file="temp_proxies.txt"

# Clear output file if exists
> "$output_file"
> "$temp_file"

# Function to test proxy using the API
test_proxy() {
    local ip=$1
    local port=$2
    # API check URL, replace {IP_ADDRESS} and {PORT} placeholders
    response=$(curl -s "https://prod-test.jdevcloud.com/check?ip=$ip&port=$port")

    # Parse response
    success=$(echo "$response" | jq -r '.success')
    is_proxy=$(echo "$response" | jq -r '.is_proxy')
    country=$(echo "$response" | jq -r '.info.country')
    org=$(echo "$response" | jq -r '.info.org')

    # Add debug log if valid proxy
    if [[ "$success" == "true" && "$is_proxy" == "true" && ( "$country" == "ID" || "$country" == "SG" ) ]]; then
        # Save valid proxy to temporary file
        echo "$ip,$port,$country,$org" >> "$temp_file"
        echo "✅ Valid: $ip,$port,$country,$org"
    else
        echo "❌ Invalid: $ip,$port"
    fi
}

# Fetch proxies for each country (ID and SG)
countries=("ID" "SG")

for country in "${countries[@]}"; do
    echo "Fetching data for country $country..."
    
    # Fetch proxy data for the country
    response=$(curl -s --max-time 30 "https://cfip.ashrvpn.v6.army/?country=$country")

    if [ -z "$response" ]; then
        echo "❌ Error: No data received for country $country"
        continue
    else
        echo "✅ Data fetched successfully for country $country"
        # Extract proxies from the response
        proxies=$(echo "$response" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+:[0-9]+')
        
        # Test each proxy
        while IFS=':' read -r ip port; do
            test_proxy "$ip" "$port"
        done <<< "$proxies"
    fi

    # Sleep for a while to avoid overloading the server
    sleep 1
done

# Remove duplicates and save valid proxies to final output file
sort -u "$temp_file" > "$output_file"
rm "$temp_file"

echo "Completed! Valid proxies saved to $output_file (duplicates removed)"
