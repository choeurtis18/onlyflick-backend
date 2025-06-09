# OnlyFlick - Backend API

OnlyFlick est une plateforme sociale conçue pour connecter créateurs de contenu et abonnés. Ce backend écrit en Go fournit une API RESTful robuste ainsi qu'une messagerie en temps réel via WebSocket.

## 🛠 Stack technique

- **Langage** : Go (Golang)
- **Framework HTTP** : Chi
- **Base de données** : PostgreSQL
- **Authentification** : JWT
- **WebSocket** : Gorilla/WebSocket
- **Migrations SQL** : intégrées en Go
- **Tests** : via Postman + scripts

## 📦 Fonctionnalités

- 🔐 Authentification (login/signup avec JWT)
- 👤 Profils utilisateurs (abonnements, demandes de passage créateur)
- 📬 Système de messagerie privée temps réel entre créateurs et abonnés
- 🚨 Système de signalement de contenu (posts & commentaires)
- 📊 Tableau de bord administrateur avec actions modératives
- 🧪 Scripts de test WebSocket (clients multiples)

## 🚀 Lancer le projet

```bash
go run cmd/server/main.go
``` 

## 💬 Tester la messagerie WebSocket

```bash
go run scripts/client_a/ws_client_a.go
go run scripts/client_b/ws_client_b.go
``` 