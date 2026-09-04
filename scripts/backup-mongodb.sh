#!/bin/bash
set -e

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="/root/project-final-cicd-main/backups"
CONTAINER_ID=$(docker ps -q --filter "name=ecommerce_mongodb")

if [ -z "$CONTAINER_ID" ]; then
  echo "Erreur : conteneur MongoDB introuvable."
  exit 1
fi

echo "Sauvegarde de MongoDB en cours..."
docker exec "$CONTAINER_ID" mongodump --out /tmp/backup_$TIMESTAMP

echo "Copie de la sauvegarde vers l'hôte..."
docker cp "$CONTAINER_ID":/tmp/backup_$TIMESTAMP "$BACKUP_DIR/backup_$TIMESTAMP"

echo "Nettoyage du conteneur..."
docker exec "$CONTAINER_ID" rm -rf /tmp/backup_$TIMESTAMP

echo "Sauvegarde terminée : $BACKUP_DIR/backup_$TIMESTAMP"
