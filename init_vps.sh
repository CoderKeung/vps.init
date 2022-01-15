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
function has_v2ray() {
  local package=`pacman -Qq | grep "acme.sh"`
  if [ $package ]; then
    ok "Has" "acme.sh"
  else
    error "No" "acme.sh"
    run "Start install" "acme.sh"
    pacman -S acme.sh
  fi
}


#=============================================
# ADD NEW USER
#=============================================
function add_user() {
  run "Start add a new user..."
  input
  read -r -p "Do you want add a new user? [y|N] " response
  if [[ $response =~ (y|yes|Y) ]]; then
    while true; do
      input
      read -r -p "Please input your username [default:vpsname]: " username
      id ${username:-"vpsname"} >& /dev/null
      if [ $? -ne 0 ]; then
        break
      fi
      error "This user has ben create! Please input a new name."
    done
    USERNAME=${username:-"vpsname"}
    input
    read -r -p "Please input user shell [default:/bin/bash]: " usershell
    USERSHELL=${usershell:-"/bin/bash"}
    useradd -m -s $USERSHELL $USERNAME
    id $USERNAME >& /dev/null
    if [ $? -eq 0 ]; then
      ok "Success create user" "$USERNAME"
      USERHOMEPATH="/home/$USERNAME"
    fi
  else
    USERNAME=$USER
    USERSHELL=$SHELL
    USERHOMEPATH=$HOME
  fi
}

#=============================================
# CONFIG NGINX
#=============================================
function config_nginx() {
  NGINXPATH="/etc/nginx"
  NGINXSERVER=""$NGINXPATH"/servers"
  if [[ ! -d $NGINXSERVER ]]; then
    run "Start make new directory: " "$NGINXSERVER"
    mkdir "$NGINXSERVER"
    if [[ ! -d $NGINXSERVER ]]; then
      ok "Make directory " "$NGINXSERVER"
    fi
  else
    ok "Has " $NGINXSERVER
  fi
  if [[ ! -f "$NGINXPATH/nginx.conf.default" ]]; then
    run "Back nginx.conf to nginx.conf.default..."
    mv "$NGINXPATH/nginx.conf" "$NGINXPATH/nginx.conf.default"
  else
    ok "Has " "$NGINXPATH/nginx.conf.default"
  fi
    run "Create new nginx.conf..."
    cat > $NGINXPATH/nginx.conf<<-EOF
#user http;
worker_processes  1;

events {
  worker_connections  1024;
}

http {
  include       mime.types;
  default_type  application/octet-stream;
  sendfile        on;

  keepalive_timeout  65;

  server {
    listen       80;
    server_name  localhost;

    location / {
      root   /usr/share/nginx/html;
      index  index.html index.htm;
    }

    error_page   500 502 503 504  /50x.html;
    location = /50x.html {
      root   /usr/share/nginx/html;
    }

  }
  include servers/*;
}
EOF
}

#=============================================
# CONFIG ACMESH
#=============================================
function config_acmesh() {
  su - $USERNAME <<-EOF
    acme.sh --set-default-ca --server letsencrypt
    acme.sh --issue -d $DOMAIN -w $WEBSITEPATH --keylength ec-256 --force
    SSLPATH="$WEBSITEPATH/ssl"
    mkdir -p $SSLPATH
    acme.sh "--install-cert -d ${DOMAIN} --ecc --fullchain-file $SSLPATH/$DOMAIN.crt --key-file $SSLPATH/$DOMAIN.key"
EOF
}

#=============================================
# GET USER INFOMATION
#=============================================
function get_user_info() {
  input
  read -r -p "Please input your domain: " domain
  action_domain $domain
  if [ $IP ]; then
    ok "This domain is action" $domain
    DOMAIN=$domain
  else
    error "This domain is no action" $domain
    exit 1
  fi
  input
  read -r -p "Please input your website path[default: $USERHOMEPATH/website/$DOMAIN]: " websitepath
  WEBSITEPATH="$USERHOMEPATH/website/${websitepath:-$DOMAIN}"
  su - $USERNAME -c "mkdir -p $WEBSITEPATH/site"
  input
  read -r -p "Please input your v2ray websocket path[default: api]: " websocketpath
  WEBSOCKETPATH=${websocket:-"api"}
  su - $USERNAME -c "mkdir -p $WEBSITEPATH/site/$WEBSOCKETPATH"
  input 
  read -r -p "Please input your port want to set v2ray[default: 8888]: " port
  PORT=${port:-"8888"}
  UUID=`v2ctl uuid`
}


#=============================================
# START CONFIGURATION
#=============================================
V2RAYPATH="/etc/v2ray"
cat >$V2RAYPATH"/config.json"<<EOF
{
  "inbounds": [{
    "port": ${PORT},
    "listen": "127.0.0.1",
    "protocol": "vmess",
    "settings": {
      "clients": [
        {
          "id": "${UUID}",
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

cat >$NGINXSERVER"/"$DOMAIN.conf <<EOF
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
    root $WEBSITEPATH/site;
    index index.html index.htm;
  }

  location /${WEBSOCKETPATH} {
    if ($http_upgrade != "websocket") { 
      rewrite /${WEBSOCKETPATH} /index.html last;
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