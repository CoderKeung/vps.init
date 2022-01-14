#!/bin/sh
#=============================================
# FILE: init_vps.sh
# CREATE: CoderKeung
# FUNCTION: Initialization VPS
#=============================================

source ./util.sh

#=============================================
# INSTALL REQUIRE PACKAGE
#=============================================
function has_nginx() {
  local package=`pacman -Qq | grep "nginx"`
  if [ $package ]; then
    ok "Has" "nginx"
  else
    error "No" "nginx"
    run "Start install" "nginx"
    pacman -S nginx
  fi
}
function has_v2ray() {
  local package=`pacman -Qq | grep "v2ray$"`
  if [ $package ]; then
    ok "Has" "v2ray"
  else
    error "No" "v2ray"
    run "Start install" "v2ray"
    pacman -S v2ray
  fi
}
function has_acmesh() {
  acme.sh >& /dev/null
  if [ $? -ne 0 ]; then
    ok "Has" "acme.sh"
  else
    error "No" "acme.sh"
    run "Start install" "acme.sh"
    input
    read -r -p "Please input your email: " email
    curl https://get.acme.sh | sh -s email=$email
    if [ $SHELL == "/bin/zsh" ]; then
      source $HOME/.zshrc
    elif [ $SHELL == "/bin/bash" ]; then
      source $HOME/.bashrc
    fi
    acme.sh --upgrade --auto-upgrade
  fi
}

#=============================================
# ADD NEW USER
#=============================================
function add_user() {
  input
  read -r -p "Do you want add a new user? [y|N] " response
  if [[ $response =~ (y|yes|Y) ]]; then
    input
    read -r -p "Please input your username: " USERNAME
    input
    read -r -p "Please input user shell: " USERSHELL
    useradd -m -s $USERSHELL $USERNAME
    id $USERNAME >& /dev/null
    if [ $? -ne 0 ]; then
      ok "Success create user" "$USERNAME"
    fi
  fi
}

#=============================================
# CONFIG NGINX
#=============================================
function config_nginx() {
  local nginxpath="/etc/nginx"
  mkdir $nginxpath/servers
  mv $nginxpath/nginx.conf $nginxpath/nginx.conf.default
  cp ./file/nginx.conf $nginxpath/nginx.conf
}

#=============================================
# CONFIG ACMESH
#=============================================
function config_acmesh() {
  su - $USERNAME <<-EOF
    acme.sh --set-default-ca --server letsencrypt
    acme.sh --issue -d ${DOMAIN} -w ${WEBSITEPATH} --keylength ec-256 --force
    SSLPATH="$USERHOMEPATH/website/$WEBSITEPATH/ssl"
    mkdir -p $SSLPATH
    acme.sh "--install-cert -d ${DOMAIN} --ecc --fullchain-file $SSLPATH/$DOMAIN.crt --key-file $SSLPATH/$DOMAIN.key"
  EOF
}

#=============================================
# START CONFIGURATION
#=============================================
has_v2ray
has_nginx
has_acmesh
config_nginx

NGINXPATH="/etc/nginx/servers/"
V2RAYPATH="/etc/v2ray/"
USERHOMEPATH="/home/$USERNAME"

input
read -r -p "Please input your domain: " DOMAIN
input
read -r -p "Please input your website path[$USERHOMEPATH/website]: " WEBSITEPATH
input 
read -r -p "Please input your v2ray websocket path: " WEBSOCKETPATH
input
read -r -p "Please input your port want to set v2ray: " PORT
UUID=`v2ctl uuid`

config_acmesh

cat >$V2RAYPATH"config.json"<<EOF
{
  "inbounds": [{
    "port": ${PORT},
    "listen": "127.0.0.1",
    "protocol": "vmess",
    "settings": {
      "clients": [
        {
          "id": "${DOMAIN}",
          "level": 1,
          "alterId": 0
        }
      ],
      "disableInsecureEncryption": false
    },
    "streamSettings": {
        "network": "ws",
        "wsSettings": {
            "path": "/${WEBSOCKETPATH}",
            "headers": {
                "Host": "${DOMAIN}"
            }
        }
    }
  }],
  "outbounds": [{
    "protocol": "freedom",
    "settings": {}
  },{
    "protocol": "blackhole",
    "settings": {},
    "tag": "blocked"
  }]
}
EOF


cat >$NGINXPATH$DOMAIN.conf <<EOF
server {
  listen 80;
  listen [::]:80;
  server_name ${DOMAIN};
  return 301 https://$server_name:443$request_uri;
}

server {
  listen 443 ssl http2;
  listen [::]:443 ssl http2;
  server_name ${DOMAIN};
  charset utf-8;

  ssl_protocols TLSv1.1 TLSv1.2;
  ssl_ciphers ECDHE-RSA-AES128-GCM-SHA256:ECDHE:ECDH:AES:HIGH:!NULL:!aNULL:!MD5:!ADH:!RC4;
  ssl_ecdh_curve secp384r1;
  ssl_prefer_server_ciphers on;
  ssl_session_cache shared:SSL:10m;
  ssl_session_timeout 10m;
  ssl_session_tickets off;
  ssl_certificate $SSLPATH/$DOMAIN.crt;
  ssl_certificate_key $SSLPATH/$DOMAIN.key;
  location / {
    root $USERHOMEPATH/website/$WEBSITEPATH/site;
    index index.html index.htm;
  }

  location /${WEBSOCKETPATH} {
    if ($http_upgrade != "websocket") { 
      rewrite ${WEBSOCKETPATH} /index.html last;
    }
    proxy_redirect off;
    proxy_pass http://127.0.0.1:${PORT};
    proxy_http_version 1.1;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection "upgrade";
    proxy_set_header Host $host;
    # Show real IP in v2ray access.log
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
  }
}
EOF

systemctl enable nginx
systemctl start nginx
systemctl enable v2ray
systemctl start v2ray
