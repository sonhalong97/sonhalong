#!/bin/bash

install_squid() {
    yum -y install squid
}

port() {
    echo $(shuf -i 2000-65000 -n 1)
}

random_password() {
    cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 10 | head -n 1
}

configure_squid() {
    local port=$(port)
    local username=$(random_password)
    local password=$(random_password)

    sed -i "s/http_port 3128/http_port $port/" /etc/squid/squid.conf
    sudo sed -i "/# Only allow cachemgr access from localhost/i \
# Allow access only to authenticated users\n\
auth_param basic program /usr/lib64/squid/basic_ncsa_auth /etc/squid/passwd\n\
auth_param basic realm Squid Basic Authentication\n\
acl auth_users proxy_auth REQUIRED\n\
http_access allow auth_users\n" /etc/squid/squid.conf
    
    sudo mkdir /etc/squid/passwd

    htpasswd -bc /etc/squid/passwd $username $password
    
    echo "$username:$password" > /etc/squid/stpasswd
    
    port=$(grep -oP 'http_port \K\d+' /etc/squid/squid.conf)

    systemctl restart squid
    open_firewall_port
}

restart_squid() {
    systemctl restart squid
}

open_firewall_port() {
    local port=$(grep -oP 'http_port \K\d+' /etc/squid/squid.conf)
    firewall-cmd --permanent --add-port=$port/tcp
    firewall-cmd --reload
}

main() {
    install_squid
    configure_squid
    
    local ip_address=$(hostname -I)
    local port=$(grep -oP 'http_port \K\d+' /etc/squid/squid.conf)
    local username=$(head -n 1 /etc/squid/stpasswd | cut -d ":" -f 1)
    local password=$(head -n 1 /etc/squid/stpasswd | cut -d ":" -f 2)
    
    echo "Cài đặt và cấu hình Squid hoàn thành!"
    echo "IP:Port:Username:Password"
    echo "${ip_address}:${port}:${username}:${password}"
}

main
