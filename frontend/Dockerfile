# Étape 1 : Étape de base commune
FROM node:18.19.0-alpine AS base
WORKDIR /app
COPY package*.json ./
# Installer toutes les dépendances (y compris les devDependencies)
RUN npm install
COPY . .

###############################################################
# Étape 2 : Build pour la production
FROM base AS build-production
ENV NODE_ENV=production
# Ajouter les arguments de build pour les variables VITE_*
ARG VITE_AUTH_SERVICE_URL
ARG VITE_PRODUCT_SERVICE_URL
ARG VITE_ORDER_SERVICE_URL

# Définir les variables d'environnement
ENV NODE_ENV=production
ENV VITE_AUTH_SERVICE_URL=${VITE_AUTH_SERVICE_URL}
ENV VITE_PRODUCT_SERVICE_URL=${VITE_PRODUCT_SERVICE_URL}
ENV VITE_ORDER_SERVICE_URL=${VITE_ORDER_SERVICE_URL}#

## Générer le fichier .env.production
#RUN echo "VITE_AUTH_SERVICE_URL=$VITE_AUTH_SERVICE_URL" > .env.production && \
#    echo "VITE_PRODUCT_SERVICE_URL=$VITE_PRODUCT_SERVICE_URL" >> .env.production && \
#    echo "VITE_ORDER_SERVICE_URL=$VITE_ORDER_SERVICE_URL" >> .env.production

RUN npm run build

###############################################################
# Étape finale pour la production
FROM node:18.19.0-alpine AS production
WORKDIR /app
ENV NODE_ENV=production
COPY package*.json ./
# Installer uniquement les dépendances de production
RUN npm install --omit=dev
# Copier les fichiers buildés depuis l'étape de build
COPY --from=build-production /app/dist ./dist
COPY --from=build-production /app/server.cjs ./server.cjs

EXPOSE 8080
CMD ["npm", "run", "start"]

###############################################################
# Étape finale pour le développement
FROM base AS development
ENV NODE_ENV=development
EXPOSE 8080
CMD ["npm", "run", "dev", "--", "--host", "0.0.0.0"]
