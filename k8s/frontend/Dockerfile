# ---------- Étape 1 : Build Flutter Web ----------
FROM ghcr.io/cirruslabs/flutter:latest AS build

WORKDIR /app

# Étape 1.1 : Copie minimale pour cache de dépendances
COPY onlyflick-app/pubspec.yaml onlyflick-app/pubspec.lock ./

# Étape 1.2 : Pré-fetch des dépendances
RUN flutter pub get

# Étape 1.3 : Copier le reste du projet (après pub get pour le cache)
COPY onlyflick-app/. ./

# Étape 1.4 : Activer le support Web (idempotent)
RUN flutter config --enable-web

# Étape 1.5 : Build Web optimisé
RUN flutter build web --release

# ---------- Étape 2 : Serveur léger NGINX ----------
FROM nginx:stable-alpine AS runtime

RUN rm -rf /usr/share/nginx/html/*

COPY --from=build /app/build/web /usr/share/nginx/html
COPY k8s/frontend/nginx.conf /etc/nginx/nginx.conf

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
