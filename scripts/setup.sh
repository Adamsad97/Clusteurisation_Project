#!/bin/bash

set -e  # Arrête le script en cas d'erreur

# Fonction pour afficher les messages en couleur
function echo_info {
    echo -e "\e[34m[INFO]\e[0m $1"
}

function echo_success {
    echo -e "\e[32m[SUCCESS]\e[0m $1"
}

function echo_warning {
    echo -e "\e[33m[WARNING]\e[0m $1"
}

function echo_error {
    echo -e "\e[31m[ERROR]\e[0m $1"
}

# Fonction pour vérifier si une commande existe
function command_exists {
    command -v "$1" >/dev/null 2>&1
}

# Vérification des prérequis
echo_info "Vérification des prérequis..."

# Vérifier Git
if command_exists git; then
    echo_success "Git est installé."
else
    echo_error "Git n'est pas installé. Veuillez l'installer et réexécuter le script."
    exit 1
fi

# Vérifier Node.js
if command_exists node; then
    NODE_VERSION=$(node -v)
    echo_success "Node.js est installé (Version: $NODE_VERSION)."
    # Vérifier la version de Node.js (>=14.x)
    if [[ "$NODE_VERSION" < "v14." ]]; then
        echo_error "La version de Node.js doit être >= 14.x. Actuellement : $NODE_VERSION."
        exit 1
    fi
else
    echo_error "Node.js n'est pas installé. Veuillez l'installer et réexécuter le script."
    exit 1
fi

# Vérifier npm
if command_exists npm; then
    NPM_VERSION=$(npm -v)
    echo_success "npm est installé (Version: $NPM_VERSION)."
else
    echo_error "npm n'est pas installé. Veuillez l'installer et réexécuter le script."
    exit 1
fi

# Vérifier Docker (optionnel, si Docker est utilisé pour le déploiement)
if command_exists docker; then
    DOCKER_VERSION=$(docker --version)
    echo_success "Docker est installé ($DOCKER_VERSION)."
else
    echo_warning "Docker n'est pas installé. Si vous prévoyez d'utiliser Docker pour le déploiement, veuillez l'installer."
fi

# Vérifier Docker Compose (optionnel, si Docker Compose est utilisé)
if command_exists docker-compose; then
    DOCKER_COMPOSE_VERSION=$(docker-compose --version)
    echo_success "Docker Compose est installé ($DOCKER_COMPOSE_VERSION)."
else
    echo_warning "Docker Compose n'est pas installé. Si vous prévoyez d'utiliser Docker Compose pour le déploiement, veuillez l'installer."
fi

# Vérifier MongoDB (local ou via Docker)
if command_exists mongod; then
    echo_success "MongoDB est installé et en cours d'exécution localement."
else
    echo_warning "MongoDB n'est pas installé localement. Veuillez l'installer ou vous assurer qu'un service MongoDB est accessible."
    # Optionnel : Proposer d'utiliser Docker pour MongoDB
    read -p "Souhaitez-vous utiliser Docker pour exécuter MongoDB? (y/N) " USE_DOCKER_MONGO
    if [[ "$USE_DOCKER_MONGO" =~ ^[Yy]$ ]]; then
        echo_info "Lancement de MongoDB via Docker..."
        docker run --name mongo -d -p 27017:27017 mongo:4.4
        echo_success "MongoDB lancé sur le port 27017 via Docker."
    else
        echo_error "MongoDB n'est pas disponible. Le script s'arrête."
        exit 1
    fi
fi

# Définir les variables du projet
REPO_URL="<URL_DU_DÉPÔT>"  # Remplacez par l'URL de votre dépôt Git
PROJECT_DIR="<NOM_DU_PROJET>"  # Remplacez par le nom de votre projet

# Cloner le dépôt si ce n'est pas déjà fait
if [ ! -d "$PROJECT_DIR" ]; then
    echo_info "Clonage du dépôt depuis $REPO_URL..."
    git clone "$REPO_URL" "$PROJECT_DIR"
    echo_success "Dépôt cloné dans le répertoire '$PROJECT_DIR'."
else
    echo_warning "Le répertoire '$PROJECT_DIR' existe déjà. Assurez-vous que c'est le bon dépôt."
fi

cd "$PROJECT_DIR"

# Installer les dépendances du frontend
echo_info "Installation des dépendances du frontend..."
cd frontend
npm install
echo_success "Dépendances du frontend installées."

# Configurer les variables d'environnement du frontend
if [ ! -f .env ]; then
    echo_info "Création du fichier .env pour le frontend..."
    cp .env.example .env
    echo_success "Fichier .env créé pour le frontend."
    echo_warning "Veuillez éditer le fichier frontend/.env pour configurer les variables d'environnement nécessaires."
else
    echo_warning "Le fichier frontend/.env existe déjà. Veuillez vérifier les configurations."
fi

# Construire le frontend
echo_info "Construction du frontend..."
npm run build
echo_success "Frontend construit avec succès."

cd ..

# Installer les dépendances et configurer chaque service backend
for SERVICE in auth-service product-service order-service
do
    echo_info "Configuration du service '$SERVICE'..."
    cd services/"$SERVICE"
    npm install
    echo_success "Dépendances installées pour le service '$SERVICE'."

    # Configurer les variables d'environnement du service
    if [ ! -f .env ]; then
        echo_info "Création du fichier .env pour le service '$SERVICE'..."
        cp .env.example .env
        echo_success "Fichier .env créé pour le service '$SERVICE'."
        echo_warning "Veuillez éditer le fichier services/$SERVICE/.env pour configurer les variables d'environnement nécessaires."
    else
        echo_warning "Le fichier services/$SERVICE/.env existe déjà. Veuillez vérifier les configurations."
    fi

    cd ../..
done

# Installation terminée
echo_success "Configuration de l'environnement terminée avec succès."

echo_info "Vous pouvez maintenant déployer l'application manuellement en exécutant ./scripts/deploy.sh ou utiliser Docker Compose."

echo_info "N'oubliez pas d'initialiser les données des produits en exécutant ./scripts/init-products.sh"

echo_info "Si vous avez choisi d'utiliser Docker pour MongoDB, assurez-vous que le conteneur MongoDB est en cours d'exécution."

exit 0
