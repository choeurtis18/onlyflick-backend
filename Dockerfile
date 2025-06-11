# ---------- Étape 1 : Build Go ----------
FROM golang:1.24.4 AS builder

WORKDIR /app

# Étape 1.1 : Copie go.mod et go.sum pour le cache
COPY go.mod go.sum ./
RUN go mod download

# Étape 1.2 : Copier le reste du code
COPY . .

# Étape 1.3 : Build en statique (binaire Linux) - Chemin corrigé
RUN CGO_ENABLED=0 GOOS=linux go build -o onlyflick-backend ./cmd/server

# ---------- Étape 2 : Image finale minimale ----------
FROM alpine:latest

# Installer ca-certificates pour les connexions HTTPS
RUN apk --no-cache add ca-certificates

WORKDIR /app

# Étape 2.1 : Copier le binaire
COPY --from=builder /app/onlyflick-backend .

# Étape 2.2 : Copier fichiers utiles (facultatif)
# COPY migrations ./migrations

# Étape 2.3 : Exposer le port d'écoute
EXPOSE 8080

# Étape 2.4 : Commande de lancement
CMD ["./onlyflick-backend"]
