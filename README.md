# Procédure d'installation et d'exécution

Projet : e-commerce microservices (Vue.js + 3 services Node.js + MongoDB) sur Docker Swarm.

Remplacer `<IP_MANAGER>` par l'IP réelle du nœud manager.

## 1. Cluster Swarm

Sur le manager :

```bash
docker swarm init --advertise-addr <IP_MANAGER>
```

Sur chaque worker (avec le token affiché à l'étape précédente) :

```bash
docker swarm join --token <TOKEN> <IP_MANAGER>:2377
```

Vérification :

```bash
docker node ls
```

## 2. Cloner le dépôt (sur le manager)

```bash
git clone https://github.com/Adamsad97/Clusteurisation_Project.git
cd Clusteurisation_Project
git checkout develop
```

## 3. Registre Docker local

```bash
docker service create --name registry --publish 5000:5000 registry:2
```

Sur chaque nœud du cluster (manager + workers), créer `/etc/docker/daemon.json` :

```json
{
  "insecure-registries": ["<IP_MANAGER>:5000"]
}
```

```bash
sudo systemctl restart docker
```

## 4. Build et push des images (sur le manager)

```bash
docker build -t <IP_MANAGER>:5000/frontend:latest --target production ./frontend
docker build -t <IP_MANAGER>:5000/auth-service:latest ./services/auth-service
docker build -t <IP_MANAGER>:5000/product-service:latest ./services/product-service
docker build -t <IP_MANAGER>:5000/order-service:latest ./services/order-service

docker push <IP_MANAGER>:5000/frontend:latest
docker push <IP_MANAGER>:5000/auth-service:latest
docker push <IP_MANAGER>:5000/product-service:latest
docker push <IP_MANAGER>:5000/order-service:latest
```

## 5. Secrets

```bash
echo "<VOTRE_SECRET_JWT>" | docker secret create jwt_secret -

mkdir -p /root/certs
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout /root/certs/app.local.key \
  -out /root/certs/app.local.crt \
  -subj "/CN=app.local" \
  -addext "subjectAltName=DNS:app.local"

docker secret create tls_cert /root/certs/app.local.crt
docker secret create tls_key /root/certs/app.local.key
```

## 6. Config Traefik

```bash
mkdir -p /root/traefik
cp traefik/traefik.yml /root/traefik/traefik.yml
cp traefik/dynamic.yml /root/traefik/dynamic.yml
```

## 7. Adapter docker-compose.prod.yml

Remplacer toutes les occurrences de `192.168.102.114` par `<IP_MANAGER>` dans `docker-compose.prod.yml`.

## 8. Déploiement

```bash
docker stack deploy -c docker-compose.prod.yml ecommerce
```

Vérification :

```bash
docker service ls
```

Tous les services doivent afficher leur nombre de réplicas cible : `frontend 3/3`, `auth-service 2/2`, `product-service 2/2`, `order-service 2/2`, `mongodb 1/1`, `traefik 1/1`.

## 9. Accès (sur la machine cliente)

Windows — `C:\Windows\System32\drivers\etc\hosts` (admin) :

```
<IP_MANAGER> app.local
```

Linux/macOS — `/etc/hosts` (sudo) :

```
<IP_MANAGER> app.local
```

Ouvrir : **https://app.local** (accepter l'avertissement de certificat auto-signé)

## 10. Tests de résilience

Kill et recréation automatique d'un conteneur frontend :

```bash
docker ps --filter "name=frontend"
docker rm -f <CONTAINER_ID>
docker service ps ecommerce_frontend --filter "desired-state=running"
```

Kill MongoDB (les données doivent survivre) :

```bash
docker ps --filter "name=mongodb"
docker rm -f <CONTAINER_ID>
docker ps --filter "name=mongodb"
```

## 11. Scalabilité manuelle

```bash
docker service scale ecommerce_frontend=5
docker service ls
docker service scale ecommerce_frontend=3
```

Script de scalabilité automatique :

```bash
./scripts/autoscale.sh ecommerce_frontend 3 6 https://localhost/api/products
```

## 12. Backup / Restauration MongoDB

```bash
./scripts/backup-mongodb.sh
./scripts/restore-mongodb.sh backup_<timestamp>
```

## 13. CI/CD

Pipeline dans `.github/workflows/deploy.yml`, exécuté par un runner self-hosted installé sur le manager. Se déclenche à chaque `git push` sur `develop` ou `main` :

```bash
git push origin develop
```

Voir l'exécution : onglet **Actions** du dépôt GitHub.

## Arrêt propre

```bash
docker stack rm ecommerce
```
