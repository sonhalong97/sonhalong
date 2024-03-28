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
    sudo sed -i "/# Only allow cachemgr access from localhost/i \
# Allow access only to authenticated users\n\
auth_param basic program /usr/lib64/squid/basic_ncsa_auth /etc/squid/passwd\n\
auth_param basic realm Squid Basic Authentication\n\
acl auth_users proxy_auth REQUIRED\n\
http_access allow auth_users\n" /etc/squid/squid.conf
    
    sudo touch /etc/squid/passwd

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
    cat << EOF > /etc/systemd/system/squid.service
[Unit]
Description=Squid Web Proxy
After=network.target

[Service]
Type=forking
ExecStart=/usr/sbin/squid -f /etc/squid/squid.conf -z
ExecReload=/bin/kill -HUP \$MAINPID
ExecStop=/usr/sbin/squid -k shutdown
PrivateTmp=true

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
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
    
    echo "Cài đặt và cấu hình Squid hoàn thành!"
    echo "IP:Port:Username:Password"
    echo "${ip_address}:${port}:${username}:${password}"
}

main
