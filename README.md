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
