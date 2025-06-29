# Étape 1 : Build du backend Go
FROM golang:1.23 AS builder

WORKDIR /app

# Téléchargement des dépendances
COPY go.mod go.sum ./
RUN go mod download

# Copier les sources
COPY . .

# Compiler le backend
RUN CGO_ENABLED=0 GOOS=linux go build -o onlyflick-backend ./cmd/server/

# Étape 2 : Image d'exécution minimale
FROM alpine:3.18

WORKDIR /app

# Copier le binaire compilé
COPY --from=builder /app/onlyflick-backend .

# Port exposé
EXPOSE 8080

# Point d'entrée
CMD ["./onlyflick-backend"]
