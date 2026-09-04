#!/bin/bash
# Script de scalabilite automatique pour Docker Swarm
# A executer sur le noeud MANAGER uniquement.
# Mesure le temps de reponse HTTP du frontend et ajuste les replicas en consequence.

SERVICE_NAME="${1:-ecommerce_frontend}"
MIN_REPLICAS="${2:-3}"
MAX_REPLICAS="${3:-6}"
URL="${4:-https://localhost/api/products}"
RESPONSE_TIME_HIGH=1.0   # secondes : au-dessus, on considere le service charge
RESPONSE_TIME_LOW=0.2    # secondes : en dessous, on considere le service peu charge
CHECK_INTERVAL=15

echo "=== Autoscaling demarre pour $SERVICE_NAME ==="
echo "Replicas min: $MIN_REPLICAS | max: $MAX_REPLICAS"
echo "URL surveillee: $URL"
echo "Seuils temps de reponse: scale-up > ${RESPONSE_TIME_HIGH}s, scale-down < ${RESPONSE_TIME_LOW}s"
echo ""

while true; do
  CURRENT_REPLICAS=$(docker service ls --filter "name=$SERVICE_NAME" --format "{{.Replicas}}" | cut -d'/' -f2)

  if [ -z "$CURRENT_REPLICAS" ]; then
    echo "$(date '+%H:%M:%S') Erreur : service $SERVICE_NAME introuvable."
    sleep "$CHECK_INTERVAL"
    continue
  fi

  RESPONSE_TIME=$(curl -k -s -o /dev/null -w "%{time_total}" -H "Host: app.local" "$URL")

  echo "$(date '+%H:%M:%S') Replicas actuels: $CURRENT_REPLICAS | Temps de reponse: ${RESPONSE_TIME}s"

  IS_HIGH=$(echo "$RESPONSE_TIME > $RESPONSE_TIME_HIGH" | bc)
  IS_LOW=$(echo "$RESPONSE_TIME < $RESPONSE_TIME_LOW" | bc)

  if [ "$IS_HIGH" -eq 1 ] && [ "$CURRENT_REPLICAS" -lt "$MAX_REPLICAS" ]; then
    NEW_REPLICAS=$((CURRENT_REPLICAS + 1))
    echo "$(date '+%H:%M:%S') Temps de reponse eleve -> scale up : $CURRENT_REPLICAS -> $NEW_REPLICAS"
    docker service scale "$SERVICE_NAME=$NEW_REPLICAS"
  elif [ "$IS_LOW" -eq 1 ] && [ "$CURRENT_REPLICAS" -gt "$MIN_REPLICAS" ]; then
    NEW_REPLICAS=$((CURRENT_REPLICAS - 1))
    echo "$(date '+%H:%M:%S') Temps de reponse faible -> scale down : $CURRENT_REPLICAS -> $NEW_REPLICAS"
    docker service scale "$SERVICE_NAME=$NEW_REPLICAS"
  fi

  sleep "$CHECK_INTERVAL"
done
