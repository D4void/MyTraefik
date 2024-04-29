#!/bin/bash -x
# Script to init docker volumes directories

source .env

mkdir -p ${TRAEFIK_VOL}/etc/traefik
mkdir -p ${TRAEFIK_VOL}/log
mkdir -p ${LETSENCRYPT_VOL}

chmod 750 ${TRAEFIK_VOL}/etc/traefik
cp ./traefik-config/traefik.toml.example ${TRAEFIK_VOL}/etc/traefik/traefik.toml
chmod 640 ${TRAEFIK_VOL}/etc/traefik/traefik.toml
cp -R ./traefik-config/dynamic/ ${TRAEFIK_VOL}/etc/traefik/
