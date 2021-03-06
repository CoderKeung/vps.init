#!/bin/sh
#=============================================
# FILE: util.sh
# CREATE: CoderKeung
#=============================================

#=============================================
# NEED AS ROOT
#=============================================
function need_root() {
  if [ $EUID -ne 0 ]; then
    error "This script need run as ROOT!"
    exit 1
  fi
}

#=============================================
# FORMATE COLOR
#=============================================
ESCAPE="\033["
RESET=$ESCAPE"39;49;00m"
BLACK=$ESCAPE"30m"
RED=$ESCAPE"31m"
GREEN=$ESCAPE"32m"
YELLOW=$ESCAPE"33m"
BLUE=$ESCAPE"34m"
CYAN=$ESCAPE"36m"

function ok() {
  if [ $2 ]; then
    echo -e "$GREEN[OK]$RESET" $1 "$GREEN=>" $2 "$RESET"
  else
    echo -e "$GREEN[OK]$RESET" $1
  fi
}

function error() {
  if [ $2 ]; then
    echo -e "$RED[ERROR]$RESET" $1 "$RED=>" $2 "$RESET"
  else
    echo -e "$RED[ERROR]$RESET" $1
  fi
}

function run() {
  if [ $2 ]; then
    echo -e "$BLUE[RUN]$RESET" $1 "$BLUE=>" $2 "$RESET"
  else
    echo -e "$BLUE[RUN]$RESET" $1
  fi
}

function warn() {
  echo -e "$YELLOW[WARN]$RESET" $1
}

function notion() {
  if [ $2 ]; then
    echo -e "$CYAN[NOTION]$RESET" $1 "$CYAN=>" $2 "$RESET"
  else
    echo -e "$CYAN[NOTION]$RESET" $1
  fi
}

function input() {
  echo -e "$BLUE[INPUT]$RESET\c"
}

function has_package() {
  local package=`pacman -Qq | grep "$1\$"`
  if [ $package ]; then
    ok "Has" "$1"
  else
    error "No" "$1"
    run "Start install" "$1"
    pacman -S $1
  fi
}

function action_domain() {
  ping -c 1 $1 >& /dev/null
  if [ $? -eq 0 ]; then
    local web_ip=`ping -c 1 $1 | awk 'NR==1 {print $3}' | tr -d "()"`
    local local_ip=`curl ip.gs`
    if [ $web_ip == $local_ip ]; then
      IP=${web_ip}
    fi
  fi
}
