# OnlyFlick - Backend API

OnlyFlick est une plateforme sociale conçue pour connecter créateurs de contenu et abonnés. Ce backend écrit en Go fournit une API RESTful robuste ainsi qu'une messagerie en temps réel via WebSocket.

## 🛠 Stack technique

- **Langage** : Go (Golang)
- **Framework HTTP** : Chi
- **Base de données** : PostgreSQL
- **Authentification** : JWT + Chiffrement AES
- **WebSocket** : Gorilla/WebSocket
- **Migrations SQL** : intégrées en Go
- **Tests** : Suite complète (unitaires, intégration, E2E, performance)
- **Upload de fichiers** : ImageKit

## 📦 Fonctionnalités

- 🔐 Authentification sécurisée (JWT + chiffrement des données sensibles)
- 👤 Profils utilisateurs avec système d'abonnements
- 📝 Création et gestion de posts (public/abonnés uniquement)
- 💬 Messagerie privée en temps réel via WebSocket
- ❤️ Système de likes et commentaires
- 🚨 Système de signalement et modération
- 👑 Interface d'administration complète
- 📊 Demandes de passage créateur avec validation admin

## 🚀 Lancer le projet

```bash
# Installation des dépendances
go mod init onlyflick
go mod tidy

# Configuration
cp .env.example .env
# Éditer .env avec vos variables d'environnement

# Lancement du serveur
go run cmd/server/main.go
```

Le serveur démarre sur `http://localhost:8080`

## 🧪 Tests

### Exécuter tous les tests

```bash
# Tous les tests
go test ./tests/... -v

# Tests unitaires uniquement
go test ./tests/unit/... -v

# Tests d'intégration
go test ./tests/integration/... -v

# Tests E2E
go test ./tests/e2e/... -v

# Tests de performance avec benchmarks
go test ./tests/performance/... -v -bench=.
```

### Suite de tests complète

- ✅ Authentification et sécurité (JWT, chiffrement AES)
- ✅ Handlers API (login, register, profile)
- ✅ Fonctionnalités métier (likes, posts, messages)
- ✅ Administration et abonnements
- ✅ WebSocket et temps réel

#### Tests d'Intégration (2 tests)

- ✅ Flux de création de posts avec authentification
- ✅ Système d'abonnements complet

#### Tests E2E (3 tests)

- ✅ Parcours complet utilisateur (register → login → profile)
- ✅ Workflow admin et sécurité des routes
- ✅ Journey utilisateur avec mise à jour profil

#### Tests de Performance (1 test)

- ✅ Latence d'authentification et benchmarks

### Couverture de tests

- **Total** : 28 tests
- **Succès** : 100%
- **Fonctionnalités couvertes** : Toutes les APIs critiques
- **Durée d'exécution** : ~5 secondes

## 💬 Tester la messagerie WebSocket

```bash
# Lancer deux clients en parallèle
go run scripts/client_a/ws_client_a.go
go run scripts/client_b/ws_client_b.go
```

## 📊 Structure de l'API

### Authentification

- `POST /register` - Inscription
- `POST /login` - Connexion

### Profil utilisateur

- `GET /profile` - Récupérer le profil
- `PATCH /profile` - Mettre à jour le profil
- `DELETE /profile` - Supprimer le compte
- `POST /profile/request-upgrade` - Demande passage créateur

### Posts et contenu

- `GET /posts/all` - Posts publics
- `POST /posts` - Créer un post (créateurs)
- `GET /posts/me` - Mes posts
- `PATCH /posts/{id}` - Modifier un post
- `DELETE /posts/{id}` - Supprimer un post

### Abonnements

- `POST /subscriptions/{creator_id}` - S'abonner
- `DELETE /subscriptions/{creator_id}` - Se désabonner
- `GET /subscriptions` - Mes abonnements

### Messagerie

- `GET /conversations` - Mes conversations
- `POST /conversations/{receiverId}` - Démarrer une conversation
- `GET /conversations/{id}/messages` - Messages d'une conversation
- `POST /conversations/{id}/messages` - Envoyer un message
- `WS /ws/messages/{conversation_id}` - WebSocket temps réel

### Administration

- `GET /admin/dashboard` - Tableau de bord
- `GET /admin/creator-requests` - Demandes créateurs
- `POST /admin/creator-requests/{id}/approve` - Approuver
- `POST /admin/creator-requests/{id}/reject` - Rejeter

## 🔒 Variables d'environnement

```env
SECRET_KEY=your_32_character_secret_key
DATABASE_URL=postgresql://user:password@localhost/onlyflick_db
IMAGEKIT_PRIVATE_KEY=your_imagekit_private_key
IMAGEKIT_PUBLIC_KEY=your_imagekit_public_key
IMAGEKIT_URL_ENDPOINT=https://ik.imagekit.io/your_endpoint
```

## 🏗 Architecture

```txt
onlyflick-backend/
├── api/                 # Configuration des routes
├── cmd/server/          # Point d'entrée de l'application
├── internal/
│   ├── database/        # Connexion et migrations DB
│   ├── domain/          # Modèles métier
│   ├── handler/         # Contrôleurs HTTP
│   ├── middleware/      # Middlewares (auth, CORS)
│   ├── repository/      # Accès aux données
│   ├── service/         # Logique métier
│   └── utils/           # Utilitaires (chiffrement, etc.)
├── pkg/                 # Packages partagés
├── scripts/             # Scripts de test WebSocket
└── tests/               # Suite de tests complète
    ├── unit/            # Tests unitaires
    ├── integration/     # Tests d'intégration
    ├── e2e/             # Tests de bout en bout
    └── performance/     # Tests de performance
```

## 🚀 Déploiement

L'application est prête pour le déploiement avec :

- Gestion complète des erreurs
- Logs structurés
- Sécurité renforcée (chiffrement AES)
- Tests exhaustifs validant toutes les fonctionnalités
- Base de données PostgreSQL en production

## 🧩 Intégration du frontend Flutter

Le frontend Flutter est stocké dans un dépôt séparé. Pour éviter de mélanger les projets et garantir une bonne synchronisation, on utilise un **sous-module Git** :

### 1. Ajouter le frontend comme sous-module (une seule fois)

```bash
cd onlyflick-backend
git submodule add https://github.com/ibrahima-eemi/onlyflick.git frontend/onlyflick-app
git commit -m "🔗 Ajout du frontend Flutter en sous-module"
git push
```

### 2. Cloner le projet avec son sous-module

À l'avenir, cloner les deux projets ensemble :

```bash
git clone --recurse-submodules https://github.com/ton-repo/onlyflick-backend.git
cd onlyflick-backend
```

Si on oublie `--recurse-submodules`, on pourra faire ensuite :

```bash
git submodule init
git submodule update
```

### 3. Installation du frontend Flutter

Une fois le sous-module cloné :

```bash
cd frontend/onlyflick-app
flutter clean
flutter pub get
flutter run -d chrome
```

### 4. Mettre à jour le frontend

Quand le dépôt frontend évolue, synchronise-le :

```bash
cd frontend/onlyflick-app
git pull origin main
cd ../..
git add frontend/onlyflick-app
git commit -m "⬆️ Mise à jour du sous-module Flutter"
git push
```

### 5. Modifier et développer dans le frontend

Si tu ajoutes/modifies du code :

```bash
cd frontend/onlyflick-app
# Développement, commit & push du frontend
git add .
git commit -m "🎨 Modifs front"
git push origin main

cd ../..
git add frontend/onlyflick-app
git commit -m "📦 Mise à jour du commit de sous-module"
git push
```

### 6. Architecture projet complet

```txt
onlyflick-backend/
├── api/                     # Backend Go - Configuration des routes
├── cmd/server/              # Backend Go - Point d'entrée
├── internal/                # Backend Go - Code métier
├── tests/                   # Backend Go - Suite de tests
├── frontend/                # Frontend Flutter (sous-module)
│   └── onlyflick-app/       # App Flutter complète
│       ├── lib/             # Code Dart/Flutter
│       ├── android/         # Projet Android
│       ├── ios/             # Projet iOS
│       ├── web/             # Version web
│       ├── k8s/             # Configuration Kubernetes
│       └── grafana/         # Dashboards monitoring
└── README.md                # Documentation complète
```

### 7. Workflow de développement fullstack

```bash
# Terminal 1 : Backend Go
go run cmd/server/main.go

# Terminal 2 : Frontend Flutter
cd frontend/onlyflick-app
flutter run -d chrome

# Terminal 3 : Tests automatisés
go test ./tests/... -v -watch
```

## 🔄 Synchronisation des deux projets

- **Backend** : API REST + WebSocket + Tests
- **Frontend** : Interface Flutter + Intégration API
- **Communication** : JSON via HTTP/HTTPS + WebSocket temps réel
- **Authentification** : JWT partagé entre les deux projets
- **Base de données** : PostgreSQL centralisée côté backend

## 🚀 Infrastructure et Monitoring (Frontend Flutter)

Le frontend Flutter inclut une infrastructure Kubernetes complète avec monitoring intégré via Prometheus et Grafana.

### Services de monitoring déployés

- **Prometheus** : collecte des métriques système, applicatives et Kubernetes
- **Grafana** : visualisation des métriques via dashboards dynamiques
- **Kube-State-Metrics** : expose les états des ressources Kubernetes
- **Node Exporter** : expose les métriques des nœuds (CPU, mémoire, disque)

### Déploiement Kubernetes complet

```bash
# 1. Installer Prometheus et Grafana via Helm
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

helm install monitoring prometheus-community/kube-prometheus-stack \
  --namespace monitoring --create-namespace

# 2. Appliquer les Ingress
cd frontend/onlyflick-app
kubectl apply -f k8s/grafana-ingress.yaml
kubectl apply -f k8s/onlyflick-ingress.yaml

# 3. Port-forwarding pour accès local
kubectl port-forward svc/monitoring-grafana -n monitoring 3000:80
```

### Dashboards Grafana intégrés

- **Chemin** : `frontend/onlyflick-app/grafana/dashboards/devops_dashboard_grafana.json`
- **Contenu** :
  - Métriques système : CPU, RAM, disque, uptime
  - Métriques Kubernetes : pods, nodes, namespaces
  - Variables dynamiques pour filtrage

### Accès aux services

Ajouter dans `/etc/hosts` :

```txt
127.0.0.1 grafana.local onlyflick.local
```

- **Grafana** : `http://grafana.local:3000`
- **OnlyFlick App** : `http://onlyflick.local`
- **Backend API** : `http://localhost:8080`

## 🎯 Prérequis complets

### Backend Go

- Go 1.21+
- PostgreSQL
- Variables d'environnement configurées

### Frontend Flutter

- [Flutter](https://flutter.dev/docs/get-started/install)
- [Chrome browser](https://www.google.com/chrome/)
- [Docker](https://docs.docker.com/get-docker/)
- [kubectl](https://kubernetes.io/docs/tasks/tools/)
- [Helm](https://helm.sh/)
- [Grafana](https://grafana.com/)
- [Prometheus](https://prometheus.io/)

## 🔮 Roadmap

- ✅ Backend Go avec API REST complète
- ✅ Suite de tests exhaustive (28 tests)
- ✅ Frontend Flutter avec monitoring K8s
- 🔄 Intégration CI/CD automatisée
- 🔄 Logging centralisé avec Loki
- 🔄 Export de métriques applicatives personnalisées
- 🔄 Déploiement cloud-native (AWS/GCP/Azure)
