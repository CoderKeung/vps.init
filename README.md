# Initialization new vps script

This script will change your vps to `archlinux os`. Then configuration your vps on the `archlinux` .

If your don't want use `archlinux`. This script not for you.

## File Introduction

[to_arch.sh](./to_arch.sh) : Change your vps to arch. Use [vps2arch](https://github.com/felixonmars/vps2arch)

[init_vps.sh](./init_vps.sh) : The main code

- Create New User
- Install `nginx` `v2ray` `socat` `openssl` `curl` `cronie`
- Configuration `nginx`
  - Nginx `.conf` files : **/etc/nginx/servers**
  - Backup `nginx.conf` to `nginx.conf.default`
- Use [acme.sh](https://github.com/acmesh-official/acme.sh) get cert
  - `acme.sh` use my email: `coderkeung@gmail.com`
- Configuration `v2ray` (ws+tls+web)
  - Website home directory: **$HOME/website/yourcustom/site**
  - Website ssl directory: **$HOME/website/yourcustom/ssl**

## How to use

- Install `git`
- Then execute sequentially

```bash

git clone https://github.com/CoderKeung/vps.init

cd vps.init

sh to_arch.sh

sh init_vps.sh

```
