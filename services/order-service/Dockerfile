# Utiliser une image Node.js officielle comme base
FROM node:18-alpine

# Créer et définir le répertoire de travail
WORKDIR /app

# Copier les fichiers package.json et package-lock.json
COPY package*.json ./
RUN rm -rf node_modules && npm cache clean --force
# Installer les dépendances
RUN npm install

# Copier le reste des fichiers du projet
COPY . .

# Exposer le port utilisé par l'application
EXPOSE 3002

# Commande pour démarrer l'application
CMD ["npm", "start"]