# OnlyFlick

OnlyFlick est une application Flutter Web conçue pour permettre la découverte, la visualisation et l'interaction avec du contenu multimédia dans un environnement distribué et scalable. Le projet s'appuie sur une infrastructure Kubernetes et un système de monitoring complet pour garantir performance, résilience et observabilité.

## Getting Started

### Prérequis

Avant de démarrer, assurez-vous d'avoir installé :

- [Flutter](https://flutter.dev/docs/get-started/install)
- [Chrome browser](https://www.google.com/chrome/) (pour le développement web)
- [Docker](https://docs.docker.com/get-docker/)
- [kubectl](https://kubernetes.io/docs/tasks/tools/)
- [Helm](https://helm.sh/)
- [Grafana](https://grafana.com/)
- [Prometheus](https://prometheus.io/)
- (Optionnel) [minikube](https://minikube.sigs.k8s.io/) ou [KinD](https://kind.sigs.k8s.io/)

### Installation de l'application Flutter

1. Cloner le dépôt :

    ```bash
    git clone https://github.com/ibrahima-eemi/onlyflick.git
    cd onlyflick
    ```

2. Nettoyer le projet :

    ```bash
    flutter clean
    ```

3. Installer les dépendances :

    ```bash
    flutter pub get
    ```

4. Lancer l'application dans Chrome :

    ```bash
    flutter run -d chrome
    ```

## Fonctionnalités de l'application

- Interface web développée avec Flutter
- Composants interactifs simulant une expérience utilisateur multimédia
- Architecture scalable, pensée pour un futur backend en Go
- Prête à être containerisée et déployée en environnement cloud

## Infrastructure Kubernetes et Monitoring

Le projet est conçu pour tourner sur un cluster Kubernetes avec un monitoring natif intégré via Prometheus et Grafana.

### Services déployés

- **Prometheus** : collecte des métriques système, applicatives et Kubernetes
- **Grafana** : visualisation des métriques via dashboards dynamiques
- **Kube-State-Metrics** : expose les états des ressources Kubernetes
- **Node Exporter** : expose les métriques des nœuds (CPU, mémoire, disque)

### Dashboards Grafana

#### Dashboard principal

- **Chemin** : `grafana/dashboards/devops_dashboard_grafana.json`
- **Contenu** :
  - Métriques système : CPU, RAM, disque, uptime
  - Métriques Kubernetes : pods, nodes, namespaces
  - Variables dynamiques pour filtrage

##### Import manuel dans Grafana

1. Ouvrir Grafana ex: `http://grafana.local:3000`
2. Aller dans Dashboards > Import
3. Cliquer sur Upload JSON file
4. Sélectionner le fichier `grafana/dashboards/devops_dashboard_grafana.json`

##### Import via API Grafana

```bash
curl -X POST http://<GRAFANA_URL>/api/dashboards/db \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <API_KEY>" \
  --data-binary @grafana/dashboards/devops_dashboard_grafana.json
```

Remplacez `<GRAFANA_URL>` et `<API_KEY>` par vos valeurs spécifiques.

### Déploiement Kubernetes (en local)

1. Démarrer kubernetes

    ```bash
    kubectl port-forward svc/monitoring-grafana -n monitoring 3000:80
    ```

2. Installer Prometheus et Grafana via Helm :

    ```bash
    helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
    helm repo update

    helm install monitoring prometheus-community/kube-prometheus-stack \
      --namespace monitoring --create-namespace
    ```

3. Appliquer les Ingress pour exposer les services :

    ```bash
    kubectl apply -f k8s/grafana-ingress.yaml
    kubectl apply -f k8s/onlyflick-ingress.yaml
    ```

4. Ajouter les entrées dans `/etc/hosts` :

    ```txt
    127.0.0.1 grafana.local onlyflick.local
    ```

## À venir

- Intégration backend Go
- Export de métriques personnalisées
- Logging centralisé avec Loki
- Déploiement CI/CD automatisé
