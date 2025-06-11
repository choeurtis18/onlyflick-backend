# ---------- Étape 1 : Build Flutter Web ----------
FROM ghcr.io/cirruslabs/flutter:latest AS build

WORKDIR /app

# Étape 1.1 : Copie minimale pour cache de dépendances
COPY pubspec.yaml pubspec.lock ./

# Étape 1.2 : Pré-fetch des dépendances
RUN flutter pub get

# Étape 1.3 : Copier le reste du projet (après pub get pour le cache)
COPY . .

# Étape 1.4 : Activer le support Web (idempotent)
RUN flutter config --enable-web

# Étape 1.5 : Build Web optimisé
RUN flutter build web --release

# ---------- Étape 2 : Serveur léger NGINX ----------
FROM nginx:stable-alpine AS runtime

# Étape 2.1 : Supprimer les fichiers par défaut
RUN rm -rf /usr/share/nginx/html/*

# Étape 2.2 : Copier les fichiers générés de Flutter
COPY --from=build /app/build/web /usr/share/nginx/html

# Étape 2.3 : Configuration personnalisée de NGINX
COPY nginx.conf /etc/nginx/nginx.conf

# Étape 2.4 : Exposer le port d'écoute
EXPOSE 80

# Étape 2.5 : Lancer NGINX en mode foreground
CMD ["nginx", "-g", "daemon off;"]
