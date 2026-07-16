#!/bin/bash

# Attendre que le service product soit disponible
echo "Attente du service product..."
sleep 10

# URL du service
API_URL="http://localhost:3000/api"

# Token d'authentification (à adapter selon votre configuration)
TOKEN="efrei_super_pass"

# Fonction pour créer un produit
create_product() {
    local name=$1
    local price=$2
    local description=$3
    local stock=$4

    curl -X POST "${API_URL}/products" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer ${TOKEN}" \
        -d "{
            \"name\": \"${name}\",
            \"price\": ${price},
            \"description\": \"${description}\",
            \"stock\": ${stock}
        }"
    echo
}

echo "Création des produits..."

# Création de plusieurs produits
create_product "Smartphone Galaxy S21" 899 "Dernier smartphone Samsung avec appareil photo 108MP" 15
create_product "MacBook Pro M1" 1299 "Ordinateur portable Apple avec puce M1" 10
create_product "PS5" 499 "Console de jeu dernière génération" 5
create_product "Écouteurs AirPods Pro" 249 "Écouteurs sans fil avec réduction de bruit" 20
create_product "Nintendo Switch" 299 "Console de jeu portable" 12
create_product "iPad Air" 599 "Tablette Apple avec écran Retina" 8
create_product "Montre connectée" 199 "Montre intelligente avec suivi d'activité" 25
create_product "Enceinte Bluetooth" 79 "Enceinte portable waterproof" 30

echo "Initialisation des produits terminée !"