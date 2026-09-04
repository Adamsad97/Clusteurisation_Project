#!/bin/bash
set -e

if [ -z "$1" ]; then
  echo "Usage : ./restore-mongodb.sh <nom_du_dossier_backup>"
  echo "Exemple : ./restore-mongodb.sh backup_20260825_125728"
  echo ""
  echo "Sauvegardes disponibles :"
  ls -1 /root/project-final-cicd-main/backups/
  exit 1
fi

BACKUP_DIR="/root/project-final-cicd-main/backups/$1"
CONTAINER_ID=$(docker ps -q --filter "name=ecommerce_mongodb")

if [ ! -d "$BACKUP_DIR" ]; then
  echo "Erreur : sauvegarde '$1' introuvable dans $BACKUP_DIR"
  exit 1
fi

if [ -z "$CONTAINER_ID" ]; then
  echo "Erreur : conteneur MongoDB introuvable."
  exit 1
fi

echo "Copie de la sauvegarde vers le conteneur..."
docker cp "$BACKUP_DIR" "$CONTAINER_ID":/tmp/restore_data

echo "Restauration en cours..."
docker exec "$CONTAINER_ID" mongorestore --drop /tmp/restore_data

echo "Nettoyage du conteneur..."
docker exec "$CONTAINER_ID" rm -rf /tmp/restore_data

echo "Restauration terminée depuis : $1"
