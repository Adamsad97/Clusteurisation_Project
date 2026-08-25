#!/bin/bash
set -e

echo "Génération du certificat auto-signé pour app.local..."
mkdir -p /root/certs
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout /root/certs/app.local.key \
  -out /root/certs/app.local.crt \
  -subj "/CN=app.local" \
  -addext "subjectAltName=DNS:app.local"

echo "Création des Docker Secrets (certificat TLS)..."
docker secret create tls_cert /root/certs/app.local.crt || echo "tls_cert existe déjà"
docker secret create tls_key /root/certs/app.local.key || echo "tls_key existe déjà"

echo "Copie des fichiers de configuration Traefik..."
mkdir -p /root/traefik
cp traefik/traefik.yml /root/traefik/traefik.yml
cp traefik/dynamic.yml /root/traefik/dynamic.yml

echo "Setup Traefik terminé."
echo "N'oublie pas d'ajouter '<IP_MANAGER> app.local' dans /etc/hosts sur ta machine cliente."
