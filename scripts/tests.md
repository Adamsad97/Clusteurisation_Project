# services/product-service

```bash
npm install --save-dev mongodb-memory-server @babel/core @babel/preset-env
npm install --save-dev mongodb-memory-server
npm install --save-dev cross-env
npm test
npm run lint
```

# services/order-service
```bash
npm test
```

# services/auth-service
```bash
npm test
```

# /frontend
```bash
npm run test
npm run test:unit
npm run test:coverage
npm run lint:report || true
```

#### Auth Service

- **Inscription d'un Nouvel Utilisateur**

  ```bash
  curl -X POST http://localhost:3001/api/auth/register \
       -H "Content-Type: application/json" \
       -d '{"email": "user@example.com", "password": "password123"}'
  ```

```json
{"message":"Utilisateur créé avec succès","token":"eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VySWQiOiI2NzNiNmIyYzAyNTJmZDViZmU5OTdkYWMiLCJlbWFpbCI6InVzZXJAZXhhbXBsZS5jb20iLCJpYXQiOjE3MzE5NDczMDgsImV4cCI6MTczMjAzMzcwOH0.Zcbj4jVTY0Ma3z-pCKl_bGiXbqT8aSFghE2MQBkCmXo","userId":"673b6b2c0252fd5bfe997dac"}
```


- **Connexion d'un Utilisateur**

  ```bash
  curl -X POST http://localhost:3001/api/auth/login \
       -H "Content-Type: application/json" \
       -d '{"email": "user@example.com", "password": "password123"}'
  ```

```json
{"token":"eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VySWQiOiI2NzNiNmIyYzAyNTJmZDViZmU5OTdkYWMiLCJlbWFpbCI6InVzZXJAZXhhbXBsZS5jb20iLCJpYXQiOjE3MzE5NDczNDYsImV4cCI6MTczMjAzMzc0Nn0.RcwtvVyp6gw15Zs8addBS25FzuqpqZmxp7OqwglFBG4","userId":"673b6b2c0252fd5bfe997dac","email":"user@example.com"}
```


- **Récupération du Profil Utilisateur**

  ```bash
  curl -X GET http://localhost:3001/api/auth/profile \
       -H "Authorization: Bearer <JWT_TOKEN>"
  ```

```json
{"_id":"673b6b2c0252fd5bfe997dac","email":"user@example.com","createdAt":"2024-11-18T16:28:28.239Z","__v":0}
```

#### Product Service

- **Récupération de la Liste des Produits**

  ```bash
  curl -X GET http://localhost:3000/api/products
  ```

```json
[{"_id":"673b6ba048c194f02ade2aac","name":"Smartphone Galaxy S21","price":899,"description":"Dernier smartphone Samsung avec appareil photo 108MP","stock":15,"createdAt":"2024-11-18T16:30:24.472Z","__v":0},{"_id":"673b6ba048c194f02ade2aae","name":"MacBook Pro M1","price":1299,"description":"Ordinateur portable Apple avec puce M1","stock":10,"createdAt":"2024-11-18T16:30:24.489Z","__v":0},{"_id":"673b6ba048c194f02ade2ab0","name":"PS5","price":499,"description":"Console de jeu dernière génération","stock":5,"createdAt":"2024-11-18T16:30:24.498Z","__v":0},{"_id":"673b6ba048c194f02ade2ab2","name":"Écouteurs AirPods Pro","price":249,"description":"Écouteurs sans fil avec réduction de bruit","stock":20,"createdAt":"2024-11-18T16:30:24.506Z","__v":0},{"_id":"673b6ba048c194f02ade2ab4","name":"Nintendo Switch","price":299,"description":"Console de jeu portable","stock":12,"createdAt":"2024-11-18T16:30:24.516Z","__v":0},{"_id":"673b6ba048c194f02ade2ab6","name":"iPad Air","price":599,"description":"Tablette Apple avec écran Retina","stock":8,"createdAt":"2024-11-18T16:30:24.526Z","__v":0},{"_id":"673b6ba048c194f02ade2ab8","name":"Montre connectée","price":199,"description":"Montre intelligente avec suivi d'activité","stock":25,"createdAt":"2024-11-18T16:30:24.535Z","__v":0},{"_id":"673b6ba048c194f02ade2aba","name":"Enceinte Bluetooth","price":79,"description":"Enceinte portable waterproof","stock":30,"createdAt":"2024-11-18T16:30:24.544Z","__v":0}]1
```


- **Ajout d'un Produit au Panier**

```bash
curl -X POST http://localhost:3000/api/cart/add \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer efrei_super_pass" \
  -d '{
    "userId": "673b6b2c0252fd5bfe997dac",
    "productId": "673b6ba048c194f02ade2aba",
    "quantity": 2
  }'  
```


```json
{"userId":"673b6b2c0252fd5bfe997dac","items":[{"productId":{"_id":"673b6ba048c194f02ade2aba","name":"Enceinte Bluetooth","price":79,"description":"Enceinte portable waterproof","stock":30,"createdAt":"2024-11-18T16:30:24.544Z","__v":0},"quantity":1,"_id":"673b6f7f48c194f02ade2ad0"}],"_id":"673b6f7f48c194f02ade2acf","updatedAt":"2024-11-18T16:46:55.284Z","__v":0}
```

#### Order Service

- **Passation d'une Commande**


```bash
curl -X POST http://localhost:3002/api/orders \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VySWQiOiI2NzNiNmIyYzAyNTJmZDViZmU5OTdkYWMiLCJlbWFpbCI6InVzZXJAZXhhbXBsZS5jb20iLCJpYXQiOjE3MzE5NDczNDYsImV4cCI6MTczMjAzMzc0Nn0.RcwtvVyp6gw15Zs8addBS25FzuqpqZmxp7OqwglFBG4" \
  -H "Content-Type: application/json" \
  -d '{
    "products": [{
      "productId": "673b6ba048c194f02ade2aba",
      "quantity": 1
    }],
    "shippingAddress": {
      "street": "123 Test St",
      "city": "Test City",
      "postalCode": "12345"
    }
  }'
```


```json
{"userId":"673b6b2c0252fd5bfe997dac","products":[{"productId":"673b6ba048c194f02ade2aba","name":"Enceinte Bluetooth","price":79,"quantity":1,"_id":"673b70050a40d45c0f920818"}],"totalAmount":79,"status":"pending","shippingAddress":{"street":"123 Test St","city":"Test City","postalCode":"12345"},"_id":"673b70050a40d45c0f920817","createdAt":"2024-11-18T16:49:09.281Z","__v":0}
```


- **Consultation de l'Historique des Commandes**

```bash
  curl -X GET http://localhost:3002/api/orders \
       -H "Authorization: Bearer <JWT_TOKEN>"
```

```json
[{"shippingAddress":{"street":"123 Test St","city":"Test City","postalCode":"12345"},"_id":"673b70050a40d45c0f920817","userId":"673b6b2c0252fd5bfe997dac","products":[{"productId":"673b6ba048c194f02ade2aba","name":"Enceinte Bluetooth","price":79,"quantity":1,"_id":"673b70050a40d45c0f920818"}],"totalAmount":79,"status":"pending","createdAt":"2024-11-18T16:49:09.281Z","__v":0}]
```

# Utiliser un token en variable pour les tests
```bash
TOKEN=$(curl -X POST http://localhost:3001/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"password123"}' \
  | jq -r '.token')
```

# Créer une commande

```bash
curl -X POST http://localhost:3002/api/orders \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "products": [{
      "productId": "672e4f620add9bcd996c2edb",
      "quantity": 1
    }],
    "shippingAddress": {
      "street": "123 Test St",
      "city": "Test City",
      "postalCode": "12345"
    }
  }'
```

# Récupérer les commandes
```bash
curl http://localhost:3002/api/orders \
  -H "Authorization: Bearer $TOKEN"
```

# Récupérer une commande spécifique
```bash
curl http://localhost:3002/api/orders/ID_COMMANDE \
  -H "Authorization: Bearer $TOKEN"
```