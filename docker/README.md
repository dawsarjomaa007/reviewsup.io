# Environnement de developpement local avec Docker

Ce guide explique comment lancer le projet **reviewsup.io** en local avec Docker Compose.

## Pre-requis

- [Docker](https://docs.docker.com/get-docker/) et [Docker Compose](https://docs.docker.com/compose/install/) installes
- Un conteneur PostgreSQL deja en cours d'execution (ou en creer un)

## Architecture

```
        reseau externe : dorar-network
                  |
         [PostgreSQL existant]
                  |
            [api] ── port 5500
            NestJS (watch mode)
                  |
           reviewsup-net (bridge)
                  |
            [web] ── port 5510
            Next.js (Turbopack)
```

## Mise en place

### 1. PostgreSQL

Si vous n'avez pas encore de conteneur PostgreSQL, creez-en un :

```bash
docker network create dorar-network

docker run -d \
  --name dorar-postgres \
  --network dorar-network \
  -e POSTGRES_USER=dorar \
  -e POSTGRES_PASSWORD=dorar_dev_password \
  -e POSTGRES_DB=reviewsup \
  -p 5432:5432 \
  postgres:16-alpine
```

Si vous avez deja un conteneur PostgreSQL sur le reseau `dorar-network`, creez simplement la base de donnees :

```bash
docker exec <nom-du-conteneur-postgres> \
  psql -U <utilisateur> -d <base-existante> \
  -c "CREATE DATABASE reviewsup;"
```

### 2. Fichier `.env`

Copiez le fichier d'exemple et remplissez les valeurs :

```bash
cp .env.example .env
```

Les variables **obligatoires** pour que l'application demarre :

| Variable | Valeur | Description |
|----------|--------|-------------|
| `DATABASE_URL` | `postgresql://dorar:dorar_dev_password@dorar-postgres:5432/reviewsup` | Le hostname doit correspondre au **nom du conteneur** PostgreSQL |
| `JWT_SECRET` | `dev-jwt-secret-reviewsup` | N'importe quelle chaine pour le dev |
| `JWT_EXPIRES` | `7d` | Duree de validite du token |
| `RESEND_API_KEY` | `re_placeholder` | Placeholder (les emails ne seront pas envoyes) |
| `GOOGLE_CLIENT_ID` | `placeholder` | Placeholder (OAuth Google ne fonctionnera pas) |
| `GOOGLE_CLIENT_SECRET` | `placeholder` | Idem |
| `GOOGLE_CALLBACK_URL` | `http://localhost:5500/auth/google/callback` | URL de callback |
| `GITHUBS_CLIENT_ID` | `placeholder` | Placeholder |
| `GITHUBS_CLIENT_SECRET` | `placeholder` | Idem |
| `GITHUBS_CALLBACK_URL` | `http://localhost:5500/auth/github/callback` | URL de callback |
| `TWITTER_CLIENT_ID` | `placeholder` | Placeholder |
| `TWITTER_CLIENT_SECRET` | `placeholder` | Idem |
| `TWITTER_CALLBACK_URL` | `http://localhost:5500/auth/twitter/callback` | URL de callback |
| `NEXT_PUBLIC_API_URL` | `http://localhost:5500` | URL de l'API pour le navigateur |
| `NEXT_PUBLIC_APP_URL` | `http://localhost:5510` | URL de l'app web |

> **Note** : Les placeholders pour OAuth et Resend permettent a l'application de demarrer. Les fonctionnalites correspondantes (connexion Google/GitHub/Twitter, envoi d'emails) ne fonctionneront pas tant que vous n'aurez pas mis de vraies cles.

### 3. Lancer les services

```bash
docker compose -f docker/docker-compose.dev.yml up --build
```

Au premier lancement, Docker va :
1. Construire les images (installation des dependances ~2 min)
2. Executer les migrations Prisma sur la base `reviewsup`
3. Demarrer l'API NestJS en mode watch sur le port **5500**
4. Demarrer l'app Next.js avec Turbopack sur le port **5510**

Une fois lance, vous verrez :
```
reviewsup-api  | Nest application successfully started
reviewsup-web  | ✓ Ready in 2.3s
```

### 4. Verifier

- **API** : [http://localhost:5500](http://localhost:5500)
- **App web** : [http://localhost:5510](http://localhost:5510)

## Commandes utiles

```bash
# Demarrer en arriere-plan
docker compose -f docker/docker-compose.dev.yml up --build -d

# Voir les logs
docker compose -f docker/docker-compose.dev.yml logs -f

# Logs d'un seul service
docker compose -f docker/docker-compose.dev.yml logs -f api
docker compose -f docker/docker-compose.dev.yml logs -f web

# Arreter
docker compose -f docker/docker-compose.dev.yml down

# Arreter et supprimer les volumes (reset complet des node_modules)
docker compose -f docker/docker-compose.dev.yml down -v

# Reconstruire les images sans cache
docker compose -f docker/docker-compose.dev.yml build --no-cache
```

## Hot-reload

Les fichiers sources sont montes en bind mount dans les conteneurs. Toute modification est detectee automatiquement :

- **`apps/api/src/`** : NestJS recompile et redemarre
- **`apps/web/`** : Next.js recharge via Turbopack
- **`packages/api/src/`** : TypeScript recompile les types partages (`tsc --watch` tourne en arriere-plan)

> **Astuce** : Si le hot-reload ne detecte pas vos changements, la variable `WATCHPACK_POLLING=true` est deja configuree dans le fichier compose pour forcer le polling (necessaire sur certains systemes avec Docker).

## Depannage

### L'API ne demarre pas

- Verifiez que le conteneur PostgreSQL est sur le reseau `dorar-network` :
  ```bash
  docker network inspect dorar-network
  ```
- Verifiez que `DATABASE_URL` dans `.env` utilise le **nom du conteneur** comme hostname (pas `localhost`)
- Verifiez que la base `reviewsup` existe :
  ```bash
  docker exec <postgres-container> psql -U dorar -d reviewsup -c "SELECT 1;"
  ```

### Erreurs TypeScript `Cannot find module '@reviewsup/api/...'`

Le package `@reviewsup/api` doit etre compile avant que NestJS demarre. Le script d'entree (`entrypoint-api.sh`) s'en charge automatiquement. Si le probleme persiste, reconstruisez les images :
```bash
docker compose -f docker/docker-compose.dev.yml down -v
docker compose -f docker/docker-compose.dev.yml up --build
```

### Erreur `OAuth2Strategy requires a clientID option`

Les variables `GOOGLE_CLIENT_ID`, `GITHUBS_CLIENT_ID` et `TWITTER_CLIENT_ID` dans `.env` doivent contenir au moins un placeholder (ex: `placeholder`). Elles ne peuvent pas etre vides.

### Le web affiche "API not ready" en boucle

Le conteneur web attend que l'API soit accessible sur le port 5500. Si l'API echoue au demarrage, le web restera bloque. Consultez les logs de l'API :
```bash
docker compose -f docker/docker-compose.dev.yml logs api
```
