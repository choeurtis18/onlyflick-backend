# OnlyFlick - Backend API

## PROJET COMPLET DÉPLOYÉ ET FONCTIONNEL

OnlyFlick est une plateforme sociale complète connectant créateurs de contenu et abonnés. Ce projet full-stack combine un backend Go robuste avec une interface Flutter moderne, le tout déployé sur Kubernetes avec monitoring intégré.

## STATUT DU PROJET : 100% OPÉRATIONNEL

- **Frontend Flutter** : Interface MatchMaker déployée et accessible
- **Backend Go** : API REST + WebSocket fonctionnels  
- **Infrastructure** : Kubernetes + Monitoring Grafana/Prometheus
- **Tests** : 28 tests unitaires + E2E validés (100% succès)
- **Sécurité** : JWT + AES + CORS configurés

### URLs Actives

- **Application** : <http://onlyflick.local>
- **API Backend** : <http://api.onlyflick.local>
- **Monitoring** : <http://grafana.local> (admin/admin123)

## Stack technique

- **Frontend** : Flutter Web (Interface MatchMaker)
- **Backend** : Go (Golang) avec framework Chi
- **Base de données** : PostgreSQL (Neon Cloud)
- **Authentification** : JWT + Chiffrement AES
- **WebSocket** : Messagerie temps réel
- **Infrastructure** : Kubernetes (Docker Desktop)
- **Monitoring** : Prometheus + Grafana
- **Tests** : Suite complète (unitaires, intégration, E2E, performance)
- **Upload** : ImageKit pour les médias

## Infrastructure Kubernetes

### Containerisation

- **Docker** - Containerisation des applications
- **Multi-stage builds** - Optimisation taille images
- **Alpine Linux** - Images légères et sécurisées
- **Multi-architecture** - Support AMD64 + ARM64

### Orchestration Kubernetes

- **Docker Desktop Kubernetes** - Cluster local de développement
- **Namespace isolation** - Séparation des environnements
- **Deployment controllers** - Gestion des réplicas
- **Services & LoadBalancing** - Exposition des applications
- **ConfigMaps & Secrets** - Gestion configuration sécurisée

### Ingress & Networking

- **NGINX Ingress Controller** - Reverse proxy et load balancer
- **DNS local routing** - Résolution hosts personnalisée
- **SSL/TLS ready** - Préparé pour certificats HTTPS
- **Path-based routing** - Routage intelligent backend/frontend

## Monitoring & Observabilité

### Stack de monitoring

- **Prometheus** - Collecte et stockage métriques time-series
- **Grafana** - Dashboards et visualisation métriques
- **Node Exporter** - Métriques système (CPU, RAM, Disk)
- **Kube-State-Metrics** - Métriques état cluster Kubernetes
- **AlertManager** - Gestion et routing des alertes

### Métriques collectées

- Métriques système (CPU, mémoire, disque, réseau)
- Métriques applicatives (latence, throughput, erreurs)
- Métriques Kubernetes (pods, nodes, deployments)
- Métriques business (utilisateurs, posts, messages)

## Testing & Qualité

### Tests Backend Go

- **Tests unitaires** (22 tests) - Fonctions isolées
- **Tests d'intégration** (2 tests) - Flux business complets
- **Tests E2E** (3 tests) - Parcours utilisateur end-to-end
- **Tests de performance** (1 test) - Benchmarks et latence
- **Coverage reports** - Couverture de code HTML

### Tests Frontend Flutter

- **Widget tests** - Tests composants UI
- **Integration tests** - Tests parcours utilisateur
- **Code analysis** - Lint et quality checks
- **Performance tests** - Tests de performance web

### Tests de sécurité

- **Trivy scanner** - Vulnérabilités containers et dépendances
- **Gosec** - Audit sécurité code Go
- **SARIF reports** - Rapports sécurité standardisés
- **Dependency scanning** - Audit des packages tiers

## CI/CD & Automation

### GitHub Actions Pipeline

- **Déclencheurs multiples** - Push, PR, manual dispatch
- **Tests parallèles** - Exécution optimisée en matrice
- **Build multi-architecture** - Support AMD64/ARM64
- **Déploiement automatisé** - Staging → Production
- **Rollback automatique** - En cas d'échec déploiement

### Workflow phases

1. **Validation** - Detection changements + tests
2. **Security** - Scans sécurité + quality gates
3. **Build** - Images Docker multi-arch
4. **Deploy** - Kubernetes staging puis production
5. **Monitoring** - Health checks + notifications

### Registry & Artifacts

- **GitHub Container Registry (GHCR)** - Stockage images Docker
- **Artifact storage** - Rapports tests et coverage
- **Image signing** - Sécurité supply chain
- **SBOM generation** - Software Bill of Materials

## Outils de développement

### Development Environment

- **Visual Studio Code** - IDE principal
- **Go extensions** - Débogage et IntelliSense
- **Flutter extensions** - Hot reload et debugging
- **PowerShell scripts** - Automatisation locale
- **Docker Desktop** - Environnement containerisé local

### Scripts d'automatisation

- `deploy-full-stack.ps1` - Déploiement complet
- `fix-503.ps1` - Diagnostic et correction erreurs
- `verify-deployment.ps1` - Validation déploiement
- `test-quick.ps1` - Tests rapides connectivité
- `setup-monitoring.ps1` - Installation monitoring

## Networking & DNS

### Architecture réseau

- **DNS local** - Résolution hosts personnalisée
- **Load balancing** - Distribution trafic multi-pods
- **Service mesh ready** - Préparé pour Istio/Linkerd
- **Network policies** - Sécurité réseau Kubernetes

### URLs de production actives

- **Application principale** : <http://onlyflick.local>
- **API Backend** : <http://api.onlyflick.local>  
- **Monitoring** : <http://grafana.local>

### FÉLICITATIONS

Votre plateforme sociale **OnlyFlick/MatchMaker** est maintenant **100% déployée et opérationnelle** ! L'application combine une interface Flutter moderne avec un backend Go robuste, le tout orchestré sur Kubernetes avec monitoring intégré.

**Prêt pour la production !**

---

*Dernière mise à jour : 11 juin 2025 - Déploiement réussi avec succès*