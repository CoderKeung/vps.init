#!/bin/sh
#=============================================
# FILE: to_arch.sh
# CREATE: CoderKeung
# FUNCTION: CHANGE VPS TO ARCHLINUX
#=============================================

source ./util.sh

function vpstoarch() {
  run "Start download" "vps2arch"
  wget https://felixc.at/vps2arch
  local scriptpath=`pwd`"/vps2arch"
  if [ -f $scriptpath ]; then
    ok "Success download" "vps2arch"
    chmod +x $scriptpath
    run "Start install..."
    ./vps2arch
  fi
}

function is_reboot() {
  read -r -p "Do you want reboot vps? [y|N] " response
  if [[ $response =~ (y|yes|Y) ]]; then
    run "Start rebook..."
    reboot -f
  else
    notion "No reboot..."
  fi
}

need_root
vpstoarch
is_reboot
