----#!/bin/bash

install_squid() {
    yum -y install squid
}

backup_squid_config() {
    cp /etc/squid/squid.conf /etc/squid/squid.conf.bak
}

port() {
    echo $(shuf -i 2000-65000 -n 1)
}

random() {
    cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 10 | head -n 1
}

configure_squid() {
    local port=$(port)
    local username=$(random)
    local password=$(random)

    sed -i "s/http_port 3128/http_port $port/" /etc/squid/squid.conf
    sed -i "s/http_access deny all/http_access allow all/" /etc/squid/squid.conf
    sed -i "/# INSERT_AUTHENTICATION_RULE_HERE/i auth_param basic program /usr/lib/squid/basic_ncsa_auth /etc/squid/passwd\nauth_param basic realm proxy\nacl authenticated proxy_auth REQUIRED\nhttp_access allow authenticated\n" /etc/squid/squid.conf

    htpasswd -bc /etc/squid/passwd $username $password
}

restart_squid() {
    systemctl restart squid
}

open_firewall_port() {
    local port=$(grep -oP 'http_port \K\d+' /etc/squid/squid.conf)
    firewall-cmd --permanent --add-port=$port/tcp
    firewall-cmd --reload
}

send_to_google_sheet() {
    local ip=$(hostname -I | awk '{print $1}')
    local port=$(grep -oP 'http_port \K\d+' /etc/squid/squid.conf)
    local username=$(grep '^AuthUser' /etc/squid/squid.conf | awk '{print $2}')
    local password=$(grep '^AuthPass' /etc/squid/squid.conf | awk '{print $2}')
    
    local form_url="https://forms.gle/bqHB5Z2mV6AoBwcZ8"
    local submission_data="ip=$ip&port=$port&username=$username&password=$password"
    
    curl -X POST -d "$submission_data" "$form_url"
}

main() {
    install_squid
    backup_squid_config
    configure_squid
    restart_squid
    open_firewall_port
    send_to_google_sheet
    echo "Cài đặt và cấu hình Squid hoàn thành!"
}

main
