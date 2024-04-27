#!/bin/bash
# Script to init docker volumes directories

source .env

if [[ ! -d ${TRAEFIK_VOL} && ! -d ${LETSENCRYPT_VOL} ]]; then
    mkdir -p ${TRAEFIK_VOL}/etc/traefik
    mkdir -p ${TRAEFIK_VOL}/log
    mkdir -p ${LETSENCRYPT_VOL}

    chmod 750 ${TRAEFIK_VOL}/etc/traefik
    cp ./traefik-config/traefik.toml.example ${TRAEFIK_VOL}/etc/traefik/traefik.toml
    chmod 640 ${TRAEFIK_VOL}/etc/traefik/traefik.toml
    cp -R ./traefik-config/dynamic/ ${TRAEFIK_VOL}/etc/traefik/

    echo "Complete email address required by Letsencrypt in ${TRAEFIK_VOL}/etc/traefik/traefik.toml"
fi

echo "End."
