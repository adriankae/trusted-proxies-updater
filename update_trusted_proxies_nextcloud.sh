#!/bin/bash

config_file="/var/www/nextcloud/config/config.php.bak"    ### put the path to your own config.php here

###########################################
## Check if we have a public IP
###########################################
ipv4_regex='([01]?[0-9]?[0-9]|2[0-4][0-9]|25[0-5])\.([01]?[0-9]?[0-9]|2[0-4][0-9]|25[0-5])\.([01]?[0-9]?[0-9]|2[0-4][0-9]|25[0-5])\.([01]?[0-9]?[0-9]|2[0-4][0-9]|25[0-5])'
ipv4=$(curl -s -4 https://cloudflare.com/cdn-cgi/trace | grep -E '^ip'); ret=$?
if [[ ! $ret == 0 ]]; then # In the case that cloudflare failed to return an ip.
    # Attempt to get the ip from other websites.
    ipv4=$(curl -s https://api.ipify.org || curl -s https://ipv4.icanhazip.com)
else
    # Extract just the ip from the ip line from cloudflare.
    ipv4=$(echo $ipv4 | sed -E "s/^ip=($ipv4_regex)$/\1/")
fi

###############################################
## Make sure we have a valid IPv6 connection
################################################
if ! { curl -6 -s --head --fail https://ipv6.google.com >/dev/null; }; then
    logger -s "$log_header_name: Unable to establish a valid IPv6 connection to a known host."
    exit 1
fi

################################################
## Finding our IPv6 address
################################################
# Regex credits to https://stackoverflow.com/a/17871737
ipv6_regex="(([0-9a-fA-F]{1,4}:){7,7}[0-9a-fA-F]{1,4}|([0-9a-fA-F]{1,4}:){1,7}:|([0-9a-fA-F]{1,4}:){1,6}:[0-9a-fA-F]{1,4}|([0-9a-fA-F]{1,4}:){1,5}(:[0-9a-fA-F]{1,4}){1,2}|([0-9a-fA-F]{1,4}:){1,4}(:[0-9a-fA-F]{1,4}){1,3}|([0-9a-fA-F]{1,4}:){1,3}(:[0-9a-fA-F]{1,4}){1,4}|([0-9a-fA-F]{1,4}:){1,2}(:[0-9a-fA-F]{1,4}){1,5}|[0-9a-fA-F]{1,4}:((:[0-9a-fA-F]{1,4}){1,6})|:((:[0-9a-fA-F]{1,4}){1,7}|:)|fe80:(:[0-9a-fA-F]{0,4}){0,4}%[0-9a-zA-Z]{1,}|::(ffff(:0{1,4}){0,1}:){0,1}((25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])\.){3,3}(25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])|([0-9a-fA-F]{1,4}:){1,4}:((25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])\.){3,3}(25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9]))"

if $static_IPv6_mode; then
    # Test whether 'ip' command is available
    if { command -v "ip" &>/dev/null; }; then
        ipv6=$(ip -6 -o addr show scope global primary -deprecated | grep -oE "$ipv6_regex" | grep -oE ".*($last_notable_hexes)$")
    else
        # Fall back to 'ifconfig' command
        ipv6=$(ifconfig | grep -oE "$ipv6_regex" | grep -oE ".*($last_notable_hexes)$")
    fi
else
    # Use external services to discover our system's preferred IPv6 address
    ipv6=$(curl -s -6 https://cloudflare.com/cdn-cgi/trace | grep -E '^ip')
    ret=$?
    if [[ ! $ret == 0 ]]; then # In the case that cloudflare failed to return an ip.
        # Attempt to get the ip from other websites.
        ipv6=$(curl -s -6 https://api64.ipify.org || curl -s -6 https://ipv6.icanhazip.com)
    else
        # Extract just the ip from the ip line from cloudflare.
        ipv6=$(echo $ipv6 | sed -E "s/^ip=($ipv6_regex)$/\1/")
    fi
fi

# Check point: Make sure the collected IPv6 address is valid
if [[ ! $ipv6 =~ ^$ipv6_regex$ ]]; then
    logger -s "$log_header_name: Failed to find a valid IPv6 address."
    exit 1
fi

################################################
## if IP not in nextcloud config, update it
################################################

# Function to update IP in config file
update_config() {
    local ip=$1
    local ip_pattern=$2
    local awk_filter=$3
    
    if ! awk '/^\s*'\''trusted_proxies'\'' =>/,/^\s*\),/' "$config_file" | grep -q "$ip"; then
        # Create a temporary file for editing
        temp_file=$(mktemp)
        
        # Comment out existing IP entries based on the provided filter
        awk "$awk_filter" "$config_file" > "$temp_file"
        
        # Find the last index in the array
        last_index=$(awk '/^\s*'\''trusted_proxies'\'' =>/,/^\s*\),/ {if ($1 ~ /^[0-9]+/) max=$1} END {print max+1}' "$temp_file")
        
        # Add the new IP to the array and ensure closing brackets are placed correctly
        awk -v new_ip="$ip" -v idx="$last_index" '
            /^\s*'\''trusted_proxies'\'' =>/ {in_block=1; print; next}
            in_block && /^\s*\),/ {
                printf "    %d => '\''%s'\'',\n%s\n", idx, new_ip, $0
                in_block=0
                next
            }
            in_block {
                print
            }
            !in_block {
                print
            }
        ' "$temp_file" > "$temp_file.new"
        
        # Move the temporary file back to the original location
        mv "$temp_file.new" "$config_file"
        rm "$temp_file"
    fi
}

# Update for IPv4
update_config "$ipv4" "([0-9]{1,3}\.){3}[0-9]{1,3}" '
    /^\s*'\''trusted_proxies'\'' =>/ {in_block=1}
    in_block && /^\s*[0-9]+ => '\''([0-9]{1,3}\.){3}[0-9]{1,3}'\''/ {
        ip=$3
        gsub(/^'\''|'\''$/, "", ip)
        if (!(ip ~ /^127\./ || ip ~ /^10\./ || ip ~ /^192\.168\./ || ip ~ /^172\.1[6-9]\./ || ip ~ /^172\.2[0-9]\./ || ip ~ /^172\.3[0-1]\./)) {
            print "#" $0
        } else {
            print
        }
        next
    }
    in_block && /^\s*\),/ {in_block=0}
    {print}
'

# Update for IPv6
update_config "$ipv6" "[0-9a-fA-F:]+" '
    /^\s*'\''trusted_proxies'\'' =>/ {in_block=1}
    in_block && /^\s*[0-9]+ => '\''[0-9a-fA-F:]+'\''/ {
        if (index($0, "::1") == 0) {
            print "#" $0
        } else {
            print
        }
        next
    }
    in_block && /^\s*\),/ {in_block=0}
    {print}
'

chown www-data:www-data "$config_file" ## modify ownership back to www-data user
