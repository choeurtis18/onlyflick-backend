# ---------- Étape 1 : Build Go ----------
FROM golang:1.22-alpine AS builder

WORKDIR /app

# Installer les dépendances pour la compilation
RUN apk add --no-cache git gcc musl-dev

# Copier et télécharger les dépendances
COPY go.mod go.sum ./
RUN go mod download

# Copier le code source
COPY . .

# Compiler l'application
RUN CGO_ENABLED=0 GOOS=linux go build -ldflags="-w -s" -o main cmd/api/main.go

# ---------- Étape 2 : Image finale minimale ----------
FROM alpine:3.18

WORKDIR /app

# Installer les certificats CA pour HTTPS
RUN apk --no-cache add ca-certificates tzdata

# Copier l'exécutable depuis l'étape de build
COPY --from=builder /app/main .

# Exposer le port défini dans l'application
EXPOSE 8080

# Exécuter l'application
CMD ["./main"]
