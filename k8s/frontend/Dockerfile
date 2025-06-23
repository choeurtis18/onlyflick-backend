# ---------- Étape 1 : Build Flutter Web ----------
FROM ghcr.io/cirruslabs/flutter:latest AS build

WORKDIR /app

# Étape 1.1 : Copie minimale pour cache de dépendances
COPY frontend/onlyflick-app/pubspec.yaml frontend/onlyflick-app/pubspec.lock ./

# Étape 1.2 : Pré-fetch des dépendances
RUN flutter pub get

# Étape 1.3 : Copier le reste du projet Flutter
COPY frontend/onlyflick-app/ ./

# Étape 1.4 : Activer le support Web (idempotent)
RUN flutter config --enable-web

# Étape 1.5 : Build Web optimisé
RUN flutter build web --release

# ----------- Étape 2 : NGINX Runtime sécurisé ----------- #
FROM nginx:stable-alpine AS runtime

# Nettoyage du dossier html
RUN rm -rf /usr/share/nginx/html/*

# Copie du build Flutter
COPY --from=build /app/build/web /usr/share/nginx/html

# Copier la configuration nginx (SEULEMENT le bloc server)
COPY frontend/onlyflick-app/docker/nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
