#!/bin/bash

# scripts/deploy.sh

# Chemin vers le répertoire de votre application
APP_DIR="/opt/e-commerce"  # Mettez à jour ce chemin si nécessaire

# Vérifier si Node.js est installé
if ! command -v node &> /dev/null
then
    echo "Node.js n'est pas installé. Installation de Node.js..."
    curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
    sudo apt-get install -y nodejs
fi

# Vérifier si PM2 est installé
if ! command -v pm2 &> /dev/null
then
    echo "PM2 n'est pas installé. Installation de PM2..."
    sudo npm install -g pm2
fi

# Vérifier si MongoDB est installé
if ! command -v mongod &> /dev/null
then
    echo "MongoDB n'est pas installé. Installation de MongoDB..."

    # 1. Installer libssl1.1 requis pour MongoDB 4.4
    echo "Installation de libssl1.1..."
    wget http://security.debian.org/debian-security/pool/updates/main/o/openssl/libssl1.1_1.1.1n-0+deb10u6_amd64.deb
    sudo dpkg -i libssl1.1_1.1.1n-0+deb10u6_amd64.deb

    # 2. Ajouter la clé GPG de MongoDB
    echo "Ajout de la clé GPG de MongoDB..."
    curl -fsSL https://www.mongodb.org/static/pgp/server-4.4.asc | sudo gpg -o /usr/share/keyrings/mongodb-server-4.4.gpg --dearmor

    # 3. Créer le fichier source pour MongoDB
    echo "Création du fichier source pour MongoDB..."
    echo "deb [signed-by=/usr/share/keyrings/mongodb-server-4.4.gpg] http://repo.mongodb.org/apt/debian buster/mongodb-org/4.4 main" | sudo tee /etc/apt/sources.list.d/mongodb-org-4.4.list

    # 4. Mettre à jour et installer MongoDB
    echo "Mise à jour des paquets et installation de MongoDB..."
    sudo apt-get update
    sudo apt-get install -y mongodb-org

    # 5. Démarrer et activer le service
    echo "Démarrage et activation du service MongoDB..."
    sudo systemctl daemon-reload
    sudo systemctl start mongod
    sudo systemctl enable mongod

    # 6. Vérifier le statut
    sudo systemctl status mongod
else
    # Démarrer MongoDB s'il n'est pas déjà en cours d'exécution
    if ! pgrep mongod > /dev/null
    then
        echo "MongoDB n'est pas en cours d'exécution. Démarrage de MongoDB..."
        sudo systemctl start mongod
    fi
fi

# Installer les dépendances et démarrer les services
SERVICES=("auth-service" "product-service" "order-service")

for SERVICE in "${SERVICES[@]}"
do
    echo "Traitement du service: $SERVICE"
    cd "$APP_DIR/services/$SERVICE"
    npm install
    # Arrêter le service s'il est déjà en cours d'exécution
    pm2 delete "$SERVICE" || true
    # Démarrer le service avec PM2 en utilisant le chemin correct vers app.js
    #pm2 start src/app.js --name "$SERVICE" --env development
    pm2 start npm --name "$SERVICE" -- start
done

# Démarrer le frontend
echo "Traitement du frontend"
cd "$APP_DIR/frontend"
npm install

# Construire le frontend pour la production
npm run build

# Arrêter le frontend s'il est déjà en cours d'exécution
pm2 delete "frontend" || true

# Démarrer le frontend avec PM2 en servant le dossier 'dist'
#pm2 serve "$APP_DIR/frontend/dist" 8080 --name "frontend"
pm2 start npm --name frontend -- start
# Sauvegarder la configuration PM2
pm2 save
