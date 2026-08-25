# Procédure d'installation — Clusterisation Docker Swarm

Projet : e-commerce microservices (frontend Vue.js + auth-service + product-service + order-service + MongoDB)
Infrastructure : 3 VM Debian sous VMware (1 manager + 2 workers)

---

## 1. Création des VM (VMware)

- 3 VM Debian 12 (Bookworm), installation sans interface graphique (mode texte, sans "Environnement de bureau")
- Composants installés : "Utilitaires usuels du système" + "Serveur SSH"
- Réseau : mode **Bridged** (pont) — chaque VM obtient une IP sur le réseau local
- Hostnames : `manager`, `worker1`, `worker2`

### IP attribuées

| Machine | IP              |
| ------- | --------------- |
| manager | 192.168.102.114 |
| worker1 | 192.168.102.115 |
| worker2 | 192.168.102.116 |

### Vérification réseau (sur chaque VM)

```bash
ip -4 a show ens33
hostname -I
```

### Test de connectivité entre les 3 VM

```bash
ping 192.168.102.115
ping 192.168.102.116
```

Résultat : 0% de perte dans tous les sens.

### Connexion SSH depuis le PC hôte (Windows, PowerShell)

```powershell
ssh root@192.168.102.114
ssh root@192.168.102.115
ssh root@192.168.102.116
```

Si le serveur SSH n'est pas actif sur une VM :

```bash
sudo apt update
sudo apt install openssh-server -y
sudo systemctl enable ssh
sudo systemctl start ssh
```

---

## 2. Installation de Docker (sur les 3 VM)

```bash
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER
```

Vérification :

```bash
docker --version
```

---

## 3. Initialisation du cluster Docker Swarm

### Sur Manager1

```bash
docker swarm init --advertise-addr 192.168.102.114
```

> Si erreur "This node is already part of a swarm" (résidu d'un test précédent) :
>
> ```bash
> docker swarm leave --force
> docker swarm init --advertise-addr 192.168.102.114
> ```

Cette commande affiche un token de jonction du type :

```bash
docker swarm join --token SWMTKN-1-xxxxx... 192.168.102.114:2377
```

### Sur Worker1 et Worker2

Vérifier d'abord l'état existant :

```bash
docker info | grep Swarm
```

Si `active` (résidu d'un ancien swarm) :

```bash
docker swarm leave --force
```

Puis rejoindre le nouveau cluster avec le token obtenu sur Manager1 :

```bash
docker swarm join --token SWMTKN-1-xxxxx... 192.168.102.114:2377
```

### Vérification du cluster (depuis Manager1 uniquement)

```bash
docker node ls
```

Résultat attendu :

```
ID                            HOSTNAME   STATUS    AVAILABILITY   MANAGER STATUS
mfnagtrh31wakyiz7gt8gutca *   manager    Ready     Active         Leader
ujeu652xb6j0htn827g0w0tt9     worker1    Ready     Active
kmyt653if4i4k2my6dthmg17q     worker2    Ready     Active
```

---

## 4. Transfert du projet sur Manager1 depuis Windows

Sur PowerShell :

```powershell
cd C:\MAMP\htdocs\M2\S2\CLUSTEURISATION\PROJET_A_ZERO
scp -r .\project-final-cicd-main root@192.168.102.114:/root/
```

### Vérification sur Manager1

```bash
cd /root/project-final-cicd-main
ls -la
```

### Nettoyage du dossier `node_modules` (transféré par erreur, inutile car réinstallé dans les images)

```bash
find . -name "node_modules" -type d -prune -exec rm -rf {} \;
du -sh /root/project-final-cicd-main
```

---

## 5. Installation de Docker Compose (plugin, sur Manager1)

```bash
sudo apt install ca-certificates curl -y
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt update
sudo apt install docker-compose-plugin -y
```

Vérification :

```bash
docker compose version
```

---

## 6. Dockerisation des 4 composants

Dockerfile écrits pour :

- `frontend/Dockerfile` (multi-stage : base → build-production → production / development)
- `services/auth-service/Dockerfile`
- `services/product-service/Dockerfile`
- `services/order-service/Dockerfile`

### Build individuel de test (sur Manager1)

```bash
docker build --target production -t frontend:latest ./frontend
docker build -t auth-service:latest ./services/auth-service
docker build -t product-service:latest ./services/product-service
docker build -t order-service:latest ./services/order-service
```

Vérification :

```bash
docker images
```

---

## 7. Test en local avec `docker-compose.yml` (avant Swarm)

Fichier `docker-compose.yml` (mode développement) définissant : `mongodb`, `auth-service`, `product-service`, `order-service`, `frontend` (target: development), reliés sur un même réseau Docker par défaut, avec un volume `mongodb_data` pour la persistance.

### Lancement du test complet

```bash
docker compose up --build
```

Vérifications dans les logs :

- `MongoDB Connected: mongodb` pour chaque service
- `VITE v5.4.10 ready` pour le frontend
- Test dans le navigateur : http://192.168.102.114:8080

### Arrêt propre du test

```bash
docker compose down
```

---

## 8. Création du registre Docker local (sur Manager1)

```bash
docker service create --name registry --publish 5000:5000 registry:2
```

Vérification :

```bash
docker service ls
```

---

## 9. Configuration du registre non sécurisé (HTTP) — sur les 3 VM

Le registre local ne dispose pas de certificat HTTPS ; il faut autoriser explicitement Docker à lui parler en HTTP sur chaque nœud du cluster.

### Sur Manager1, Worker1, Worker2 (procédure identique)

```bash
sudo nano /etc/docker/daemon.json
```

Contenu :

```json
{
  "insecure-registries": ["192.168.102.114:5000"]
}
```

Redémarrage de Docker pour appliquer :

```bash
sudo systemctl restart docker
```

### Vérification (sur chaque VM)

```bash
cat /etc/docker/daemon.json
docker info | grep -A 3 "Insecure Registries"
```

### Vérification finale du cluster après redémarrages (depuis Manager1)

```bash
docker node ls
```

---

## 10. Retag et push des 4 images vers le registre local

Sur Manager1 :

```bash
docker tag frontend:latest 192.168.102.114:5000/frontend:latest
docker tag auth-service:latest 192.168.102.114:5000/auth-service:latest
docker tag product-service:latest 192.168.102.114:5000/product-service:latest
docker tag order-service:latest 192.168.102.114:5000/order-service:latest

docker push 192.168.102.114:5000/frontend:latest
docker push 192.168.102.114:5000/auth-service:latest
docker push 192.168.102.114:5000/product-service:latest
docker push 192.168.102.114:5000/order-service:latest
```

### Vérification du contenu du registre

```bash
curl http://192.168.102.114:5000/v2/_catalog
```

Résultat attendu :

```json
{
  "repositories": [
    "auth-service",
    "frontend",
    "order-service",
    "product-service"
  ]
}
```

> ⚠️ Point de vigilance : le registre `registry:2` ne dispose pas de volume persistant par défaut. Un redémarrage du service (ex. suite à `systemctl restart docker`) peut faire perdre les images stockées et forcer un nouveau push. Amélioration possible :
>
> ```bash
> docker service update --mount-add type=volume,source=registry_data,target=/var/lib/registry registry
> ```

---

## 11. Écriture de `docker-compose.prod.yml` (version Swarm)

Différences clés par rapport à la version développement :

- `image:` (pointant vers le registre) au lieu de `build:` — Swarm ne build pas, il télécharge des images prêtes
- `networks: driver: overlay` au lieu de `bridge` — réseau fonctionnant à travers plusieurs machines
- Section `deploy: replicas:` — 3 pour le frontend, 2 pour chaque service backend, 1 pour MongoDB
- Contrainte de placement `node.role == worker` pour frontend/auth/product/order (réservent le manager à MongoDB et au registre)
- Contrainte de placement `node.role == manager` pour MongoDB (persistance simplifiée sur un nœud fixe)
- La ligne `version: '3.8'` est requise en première ligne pour que `docker stack deploy` accepte le fichier (sinon erreur `unsupported Compose file version: 1.0`)

---

## 12. Déploiement sur le cluster Swarm

```bash
docker stack deploy -c docker-compose.prod.yml ecommerce
```

### Vérification de l'état des services

```bash
docker service ls
```

Résultat attendu (une fois les images bien accessibles depuis le registre) :

```
NAME                        REPLICAS
ecommerce_auth-service      2/2
ecommerce_frontend          3/3
ecommerce_mongodb           1/1
ecommerce_order-service     2/2
ecommerce_product-service   2/2
```

### En cas d'échec de pull ("No such image") sur les workers

Repousser les images vers le registre puis forcer la mise à jour des services concernés :

```bash
docker push 192.168.102.114:5000/frontend:latest
docker push 192.168.102.114:5000/auth-service:latest
docker push 192.168.102.114:5000/product-service:latest
docker push 192.168.102.114:5000/order-service:latest

docker service update --force ecommerce_frontend
docker service update --force ecommerce_auth-service
docker service update --force ecommerce_product-service
docker service update --force ecommerce_order-service
```

### Vérifier la répartition réelle sur les nœuds

```bash
docker service ps ecommerce_frontend
docker service ps ecommerce_auth-service
docker service ps ecommerce_product-service
docker service ps ecommerce_order-service
```

---

## 13. Test de résilience (haute disponibilité)

Objectif : prouver qu'un conteneur supprimé manuellement est automatiquement recréé par Swarm.

### Étape 1 — Identifier un conteneur actif (sur Worker1, par exemple)

```bash
docker ps --filter "name=frontend"
```

### Étape 2 — Supprimer volontairement ce conteneur

```bash
docker rm -f <CONTAINER_ID>
```

### Étape 3 — Vérifier la recréation automatique (sur le même worker)

```bash
docker ps --filter "name=frontend"
```

Un nouveau conteneur apparaît avec un nouvel ID, créé en quelques secondes.

### Étape 4 — Confirmer depuis Manager1

```bash
docker service ps ecommerce_frontend --filter "desired-state=running"
docker service ls
```

Le nombre de réplicas reste inchangé (3/3), la tâche recréée porte un timestamp récent.

---

## 14. Ajout de produits via l'API (test applicatif)

Deux contextes possibles selon où le test est fait — l'URL change en conséquence.

### A. Test local avec `docker-compose.yml` (section 7) — depuis la VM Manager1 elle-même

Quand la stack tourne en local sur Manager1 (`docker compose up`), `product-service` publie son port 3000 directement sur l'hôte : on peut donc l'appeler sur `localhost:3000`.

```powershell
function Create-Product($name, $price, $description, $stock) {
    $body = @{
        name = $name
        price = $price
        description = $description
        stock = $stock
    } | ConvertTo-Json

    Invoke-RestMethod -Uri "http://localhost:3000/api/products" -Method Post -ContentType "application/json" -Body $body
}

Create-Product "Smartphone Galaxy S21" 899 "Dernier smartphone Samsung" 15
Create-Product "MacBook Pro M1" 1299 "Ordinateur portable Apple M1" 10
Create-Product "PS5" 499 "Console de jeu derniere generation" 5
Create-Product "Nintendo Switch" 299 "Console de jeu portable" 12
```

### B. Déploiement Swarm (section 12) — depuis le PC hôte Windows

Une fois déployé sur le cluster, seul le frontend (port 8080) est exposé publiquement ; il fait office de reverse proxy vers `product-service` en interne. L'appel se fait donc sur l'IP de Manager1, port 8080 :

```powershell
function Create-Product($name, $price, $description, $stock) {
    $body = @{
        name = $name
        price = $price
        description = $description
        stock = $stock
    } | ConvertTo-Json

    Invoke-RestMethod -Uri "http://192.168.102.114:8080/api/products" -Method Post -ContentType "application/json" -Body $body
}

Create-Product "Smartphone Galaxy S21" 899 "Dernier smartphone Samsung" 15
Create-Product "MacBook Pro M1" 1299 "Ordinateur portable Apple M1" 10
Create-Product "PS5" 499 "Console de jeu derniere generation" 5
Create-Product "Nintendo Switch" 299 "Console de jeu portable" 12
```

### Lister les produits

```powershell
Invoke-RestMethod -Uri "http://192.168.102.114:8080/api/products" -Method Get
```

### Supprimer un produit (par son `_id` MongoDB)

```powershell
Invoke-RestMethod -Uri "http://192.168.102.114:8080/api/products/<ID_DU_PRODUIT>" -Method Delete
```

---

## 15. Commandes de référence rapide (diagnostic réseau / SSH)

### Connaître l'IP d'une VM

```bash
ip -4 a show ens33
```

### Se connecter en SSH depuis le PC hôte

```powershell
ssh root@192.168.102.114
```

### Vérifier l'état du service SSH sur une VM

```bash
systemctl status ssh
```

### Installer et activer SSH si absent

```bash
sudo apt update
sudo apt install openssh-server -y
sudo systemctl enable ssh
sudo systemctl start ssh
```

---

## État d'avancement par rapport au barème du sujet

| Critère                                      | Statut                                                         |
| -------------------------------------------- | -------------------------------------------------------------- |
| Cluster (1 master + 2 workers)               | ✅ Fait                                                        |
| Déploiement (front, back, BDD conteneurisés) | ✅ Fait                                                        |
| Persistance (volume MongoDB)                 | ✅ Fait                                                        |
| Haute disponibilité (kill + auto-heal)       | ✅ Testé et documenté                                          |
| Sécurité (secrets, HTTPS)                    | ✅ Fait — Docker Secrets (JWT_SECRET) + Traefik/HTTPS          |
| Exposition (LB/Ingress, DNS/hosts)           | ✅ Fait — Traefik comme reverse proxy + /etc/hosts (app.local) |
| Documentation & scripts                      | 🔜 À finaliser (ce document)                                   |

---

## 16. Sécurité — Docker Secrets (JWT_SECRET)

Contrainte du projet : ne pas modifier le code source applicatif (JS). Le secret est donc injecté via un script `entrypoint.sh` au niveau du conteneur, transparent pour le code.

### Étape 1 — Créer le secret JWT dans Swarm (sur Manager1)

```bash
echo "project_cluster_esgi_iwj" | docker secret create jwt_secret -
```

Vérification :

```bash
docker secret ls
```

### Étape 2 — Créer un script `entrypoint.sh` pour chaque service concerné

`services/auth-service/entrypoint.sh` et `services/order-service/entrypoint.sh` (contenu identique) :

```sh
#!/bin/sh
if [ -f /run/secrets/jwt_secret ]; then
  export JWT_SECRET=$(cat /run/secrets/jwt_secret)
fi
exec npm run start
```

Rendre exécutable :

```bash
chmod +x services/auth-service/entrypoint.sh
chmod +x services/order-service/entrypoint.sh
```

Ce script lit le fichier secret monté automatiquement par Swarm (`/run/secrets/jwt_secret`) et le transforme en variable d'environnement classique `JWT_SECRET` avant de lancer l'application — le code applicatif n'est jamais modifié.

### Étape 3 — Adapter les Dockerfile concernés

Ajout de `RUN chmod +x entrypoint.sh` et remplacement de `CMD ["npm", "start"]` par `CMD ["./entrypoint.sh"]` dans `services/auth-service/Dockerfile` et `services/order-service/Dockerfile`.

### Étape 4 — Adapter `docker-compose.prod.yml`

Pour `auth-service` et `order-service` : suppression de la ligne `JWT_SECRET: ...` en clair, remplacée par :

```yaml
secrets:
  - jwt_secret
```

`product-service` : la variable `JWT_SECRET` a été retirée du compose après vérification (`grep -r "jwtSecret\|JWT_SECRET" services/product-service/src/`) confirmant qu'elle n'était pas utilisée par ce service.

Ajout en fin de fichier :

```yaml
secrets:
  jwt_secret:
    external: true
```

### Étape 5 — Rebuild, repush et redéploiement

```bash
docker build -t auth-service:latest ./services/auth-service
docker build -t order-service:latest ./services/order-service

docker tag auth-service:latest 192.168.102.114:5000/auth-service:latest
docker tag order-service:latest 192.168.102.114:5000/order-service:latest

docker push 192.168.102.114:5000/auth-service:latest
docker push 192.168.102.114:5000/order-service:latest

docker stack deploy -c docker-compose.prod.yml ecommerce
```

### Vérification

```bash
docker service ls
docker service logs ecommerce_auth-service --tail 20
```

Résultat confirmé : `Auth service running on port 3001 (production)` + `MongoDB Connected: mongodb`, sans erreur `JWT_SECRET est obligatoire` — le secret est bien lu via le script, sans qu'aucune valeur sensible n'apparaisse en clair dans le compose ou le code source.

---

## 17. Sécurité — HTTPS via Traefik (reverse proxy)

Objectif : exposer le frontend en HTTPS avec un certificat auto-signé, via une stack Traefik intégrée au Swarm — conforme à l'exigence du sujet (section 3.4 et 3.5).

### Étape 1 — Générer un certificat auto-signé (sur Manager1)

```bash
mkdir -p /root/certs
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout /root/certs/app.local.key \
  -out /root/certs/app.local.crt \
  -subj "/CN=app.local" \
  -addext "subjectAltName=DNS:app.local"
```

### Étape 2 — Stocker le certificat et la clé comme Docker Secrets

```bash
docker secret create tls_cert /root/certs/app.local.crt
docker secret create tls_key /root/certs/app.local.key
```

### Étape 3 — Créer la configuration Traefik (2 fichiers distincts)

Point important : Traefik distingue **configuration statique** (entryPoints, providers — figée au démarrage) et **configuration dynamique** (routers, certificats TLS — peut changer à chaud). Les deux doivent être dans des fichiers séparés, sinon la partie dynamique est silencieusement ignorée.

**Configuration statique** — `/root/traefik/traefik.yml` :

```yaml
entryPoints:
  web:
    address: ":80"
  websecure:
    address: ":443"

providers:
  docker:
    endpoint: "unix:///var/run/docker.sock"
    exposedByDefault: false
    swarmMode: true
    network: ecommerce_ecommerce_net
  file:
    filename: /etc/traefik/dynamic.yml
```

> Attention : le provider Swarm de Traefik v2 se configure via `providers.docker` avec `swarmMode: true` — il n'existe pas de clé `providers.swarm` distincte en v2 (source d'une erreur `field not found, node: swarm` rencontrée en cours de route).

**Configuration dynamique** — `/root/traefik/dynamic.yml` :

```yaml
tls:
  certificates:
    - certFile: /run/secrets/tls_cert
      keyFile: /run/secrets/tls_key
```

### Étape 4 — Ajouter le service Traefik et les labels de routage dans `docker-compose.prod.yml`

Service `traefik` (tourne sur le manager, expose les ports 80/443, monte le docker.sock en lecture seule, les 2 fichiers de config, et les 2 secrets TLS) :

```yaml
traefik:
  image: traefik:v2.11
  command:
    - "--configFile=/etc/traefik/traefik.yml"
  ports:
    - "80:80"
    - "443:443"
  volumes:
    - /var/run/docker.sock:/var/run/docker.sock:ro
    - /root/traefik/traefik.yml:/etc/traefik/traefik.yml:ro
    - /root/traefik/dynamic.yml:/etc/traefik/dynamic.yml:ro
  secrets:
    - tls_cert
    - tls_key
  deploy:
    placement:
      constraints:
        - node.role == manager
  networks:
    - ecommerce_net
```

Sur le service `frontend` : suppression de l'exposition directe (`ports: - "8080:8080"` retiré, Traefik devient le seul point d'entrée), ajout de labels sous `deploy:` (spécificité Swarm — les labels de routage Traefik doivent être déclarés sous `deploy.labels`, pas au niveau racine du service) :

```yaml
  frontend:
    ...
    deploy:
      replicas: 3
      placement:
        constraints:
          - node.role == worker
      labels:
        - "traefik.enable=true"
        - "traefik.http.routers.frontend.rule=Host(`app.local`)"
        - "traefik.http.routers.frontend.entrypoints=websecure"
        - "traefik.http.routers.frontend.tls=true"
        - "traefik.http.services.frontend.loadbalancer.server.port=8080"
```

Déclaration des 2 nouveaux secrets en fin de fichier :

```yaml
secrets:
  jwt_secret:
    external: true
  tls_cert:
    external: true
  tls_key:
    external: true
```

### Étape 5 — Résolution du nom `app.local` (sur le PC hôte Windows)

Ajout dans `C:\Windows\System32\drivers\etc\hosts` (édition en administrateur requise) :

```
192.168.102.114 app.local
```

Vidage du cache DNS après modification :

```powershell
ipconfig /flushdns
```

### Étape 6 — Déploiement

```bash
docker stack deploy -c docker-compose.prod.yml ecommerce
```

### Vérification

```bash
docker service ls
docker service logs ecommerce_traefik --tail 20
```

Test dans le navigateur : **https://app.local** — avertissement de sécurité normal (certificat auto-signé, non reconnu par une autorité), à accepter manuellement. Vérification du certificat via l'icône de la barre d'adresse : CN émis pour/par `app.local`, confirmant que Traefik sert bien le certificat personnalisé et non son certificat par défaut.

---

## 18. Schéma d'architecture

```
                          Utilisateur (navigateur)
                                   │
                                   │ HTTPS (https://app.local)
                                   ▼
    ┌──────────────────────────────────────────────────────────────────┐
    │                    Cluster Docker Swarm                          │
    │                  1 manager + 2 workers                           │
    │                                                                  │
    │  ┌─────────────────────────┐   ┌───────────────┐ ┌───────────────┐
    │  │   Manager                │   │   Worker1     │ │   Worker2     │
    │  │   192.168.102.114        │   │ 192.168.102.115│ │192.168.102.116│
    │  │                          │   │               │ │               │
    │  │  ┌────────────────────┐  │   │ ┌───────────┐ │ │ ┌───────────┐ │
    │  │  │ Traefik             │  │   │ │ Services  │ │ │ │ Services  │ │
    │  │  │ Reverse proxy       │  │   │ │(réplicas  │ │ │ │(réplicas  │ │
    │  │  │ HTTPS + routage     │  │   │ │ répartis  │ │ │ │ répartis  │ │
    │  │  └────────────────────┘  │   │ │dynamique- │ │ │ │dynamique- │ │
    │  │  ┌────────────────────┐  │   │ │  ment)    │ │ │ │  ment)    │ │
    │  │  │ MongoDB             │  │   │ │           │ │ │ │           │ │
    │  │  │ Base de données     │  │   │ │ frontend  │ │ │ │ frontend  │ │
    │  │  │ (volume persistant) │  │   │ │  ×3 total │ │ │ │  ×3 total │ │
    │  │  └────────────────────┘  │   │ │ auth ×2   │ │ │ │ auth ×2   │ │
    │  │  ┌────────────────────┐  │   │ │ product×2 │ │ │ │ product×2 │ │
    │  │  │ Registry             │ │   │ │ order ×2  │ │ │ │ order ×2  │ │
    │  │  │ Images Docker        │ │   │ └───────────┘ │ │ └───────────┘ │
    │  │  └────────────────────┘  │   └───────────────┘ └───────────────┘
    │  └─────────────────────────┘                                     │
    └──────────────────────────────────────────────────────────────────┘
```

**Principe de placement** : les contraintes `node.role == manager` / `node.role == worker` dans `docker-compose.prod.yml` réservent le manager à l'infrastructure de support (proxy, base de données, registre), et les workers à l'exécution des services applicatifs — évitant que le nœud de pilotage du cluster soit chargé par le trafic applicatif.

---

## 19. Test de persistance — MongoDB

Objectif : prouver que les données survivent à la suppression complète du conteneur MongoDB (exigence explicite du sujet, section 3.3).

### Étape 1 — Relever l'état des données avant le test

Via l'API, à travers Traefik :

```
https://app.local/api/products
```

Résultat de référence : 4 produits enregistrés, avec leurs `_id` MongoDB notés.

### Étape 2 — Identifier et supprimer le conteneur MongoDB (sur Manager1)

```bash
docker ps --filter "name=mongodb"
docker rm -f <CONTAINER_ID>
```

### Étape 3 — Vérifier la recréation automatique

```bash
docker ps --filter "name=mongodb"
docker service ls
```

Résultat observé : nouveau conteneur recréé en 15 secondes (nouvel ID de conteneur et de tâche Swarm), service toujours à `1/1` réplicas.

### Étape 4 — Vérifier l'intégrité des données après recréation

```
https://app.local/api/products
```

**Résultat : les 4 produits sont revenus avec des `_id` strictement identiques à l'état initial** — confirme que le volume `mongodb_data` (déclaré dans `docker-compose.prod.yml`) conserve bien les données indépendamment du cycle de vie du conteneur.

---

## 20. Préparation du dépôt final

### Nettoyage et structuration du projet (sur Manager1)

Ajout au projet des éléments manquants pour un dépôt autonome et rejouable :

- `scripts/setup-traefik.sh` : script regroupant la génération du certificat auto-signé, la création des secrets TLS, et la copie des fichiers de config Traefik
- `scripts/deploy.sh` : adapté pour build + push vers le registre local + `docker stack deploy` (la version d'origine du projet ciblait un registre GitLab CI, non utilisé ici)
- `traefik/traefik.yml` et `traefik/dynamic.yml` : copiés dans le dossier du projet (ils vivaient auparavant hors du repo, dans `/root/traefik/`) pour être versionnés

### Récupération du projet complet sur le PC hôte (Windows)

```powershell
cd C:\MAMP\htdocs\M2\S2\CLUSTEURISATION\PROJET_A_ZERO
scp -r root@192.168.102.114:/root/project-final-cicd-main .\project-final-cicd-main-final
```

### Initialisation Git et premier commit (depuis le PC hôte)

```powershell
cd project-final-cicd-main-final
git init
git add .
git commit -m "Version initiale - clusterisation Docker Swarm complete"
git branch -M main
git remote add origin https://github.com/<TON_USERNAME>/<NOM_DEPOT>.git
git push -u origin main
```

---

## 21. Bonus proposés (en attente de validation par l'enseignant)

Liste communiquée à l'enseignant, mise en pause dans l'attente de son retour :

1. **Resource Requests & Limits** — limites CPU/RAM par conteneur, pour éviter qu'un service défaillant ne monopolise les ressources d'un nœud.
2. **Node Affinity / contraintes de placement** — déjà en place de fait via `node.role == manager/worker` dans `docker-compose.prod.yml` (section 12) ; à présenter explicitement comme bonus.
3. **Rolling Update** — déploiement progressif des mises à jour via `update_config`, pour éviter toute interruption de service.
4. **Rollback automatique** — retour automatique à la version précédente en cas d'échec de déploiement.
5. **Backup / Restauration MongoDB** — script de sauvegarde régulière (`mongodump`) et procédure de restauration.
6. **CI/CD (GitHub Actions)** — pipeline de build/push/déploiement automatisé, via un runner **self-hosted installé sur Manager1** (nécessaire car le cluster est sur un réseau privé local, inaccessible depuis les runners cloud standards de GitHub).

Bonus écartés car sans équivalent direct sous Docker Swarm (conçus pour Kubernetes) : NetworkPolicy, Autoscaling horizontal (HPA), Helm Charts.

---

## État d'avancement par rapport au barème du sujet
