# Configuration des Secrets GitHub pour OnlyFlick CI/CD

## Secrets requis pour le déploiement

### 1. Docker Hub

- `DOCKER_USERNAME` : Votre nom d'utilisateur Docker Hub
- `DOCKER_PASSWORD` : Votre token d'accès Docker Hub

### 2. Application OnlyFlick

- `SECRET_KEY` : Clé secrète pour JWT (32 caractères)
- `DATABASE_URL` : URL de connexion PostgreSQL Neon
- `IMAGEKIT_PRIVATE_KEY` : Clé privée ImageKit
- `IMAGEKIT_PUBLIC_KEY` : Clé publique ImageKit
- `IMAGEKIT_URL_ENDPOINT` : Endpoint ImageKit

### 3. Kubernetes (optionnel)

- `KUBE_CONFIG` : Configuration kubectl en base64

## Comment ajouter les secrets

1. Aller sur votre repository GitHub
2. Settings → Secrets and variables → Actions
3. Cliquer "New repository secret"
4. Ajouter chaque secret avec sa valeur

## Note importante

Sans `KUBE_CONFIG`, le pipeline fonctionne en mode simulation :

- ✅ Tests s'exécutent
- ✅ Images Docker sont construites et poussées
- ⚠️ Déploiement Kubernetes simulé uniquement

Pour un déploiement réel, configurez `KUBE_CONFIG` avec votre cluster.
