#!/bin/bash
# Script de scalabilité automatique pour Docker Swarm
# Surveille la charge CPU moyenne d'un service et ajuste ses replicas en consequence

SERVICE_NAME="${1:-ecommerce_frontend}"
MIN_REPLICAS="${2:-3}"
MAX_REPLICAS="${3:-6}"
CPU_SCALE_UP_THRESHOLD=70    # % CPU moyen au-dessus duquel on augmente les replicas
CPU_SCALE_DOWN_THRESHOLD=20  # % CPU moyen en dessous duquel on reduit les replicas
CHECK_INTERVAL=30            # secondes entre chaque verification

echo "=== Autoscaling demarre pour $SERVICE_NAME ==="
echo "Replicas min: $MIN_REPLICAS | max: $MAX_REPLICAS"
echo "Seuils CPU: scale-up > ${CPU_SCALE_UP_THRESHOLD}%, scale-down < ${CPU_SCALE_DOWN_THRESHOLD}%"
echo ""

while true; do
  CURRENT_REPLICAS=$(docker service ls --filter "name=$SERVICE_NAME" --format "{{.Replicas}}" | cut -d'/' -f2)

  if [ -z "$CURRENT_REPLICAS" ]; then
    echo "$(date '+%H:%M:%S') Erreur : service $SERVICE_NAME introuvable."
    sleep "$CHECK_INTERVAL"
    continue
  fi

  CONTAINER_IDS=$(docker ps -q --filter "name=${SERVICE_NAME}\." )

  if [ -z "$CONTAINER_IDS" ]; then
    echo "$(date '+%H:%M:%S') Aucun conteneur actif trouve localement pour $SERVICE_NAME (peut-etre sur un autre noeud)."
    sleep "$CHECK_INTERVAL"
    continue
  fi

  TOTAL_CPU=0
  COUNT=0
  for cid in $CONTAINER_IDS; do
    CPU=$(docker stats --no-stream --format "{{.CPUPerc}}" "$cid" | tr -d '%')
    TOTAL_CPU=$(echo "$TOTAL_CPU + $CPU" | bc)
    COUNT=$((COUNT + 1))
  done

  if [ "$COUNT" -eq 0 ]; then
    sleep "$CHECK_INTERVAL"
    continue
  fi

  AVG_CPU=$(echo "scale=2; $TOTAL_CPU / $COUNT" | bc)
  echo "$(date '+%H:%M:%S') Replicas actuels: $CURRENT_REPLICAS | CPU moyen (noeud local): ${AVG_CPU}%"

  AVG_CPU_INT=$(echo "$AVG_CPU / 1" | bc)

  if [ "$AVG_CPU_INT" -gt "$CPU_SCALE_UP_THRESHOLD" ] && [ "$CURRENT_REPLICAS" -lt "$MAX_REPLICAS" ]; then
    NEW_REPLICAS=$((CURRENT_REPLICAS + 1))
    echo "$(date '+%H:%M:%S') CPU eleve -> scale up : $CURRENT_REPLICAS -> $NEW_REPLICAS"
    docker service scale "$SERVICE_NAME=$NEW_REPLICAS"
  elif [ "$AVG_CPU_INT" -lt "$CPU_SCALE_DOWN_THRESHOLD" ] && [ "$CURRENT_REPLICAS" -gt "$MIN_REPLICAS" ]; then
    NEW_REPLICAS=$((CURRENT_REPLICAS - 1))
    echo "$(date '+%H:%M:%S') CPU faible -> scale down : $CURRENT_REPLICAS -> $NEW_REPLICAS"
    docker service scale "$SERVICE_NAME=$NEW_REPLICAS"
  fi

  sleep "$CHECK_INTERVAL"
done
