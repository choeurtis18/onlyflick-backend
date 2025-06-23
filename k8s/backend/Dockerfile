# Étape de build
FROM golang:1.24.4-alpine AS builder

WORKDIR /app

COPY go.mod go.sum ./
RUN go mod download

COPY . .

RUN CGO_ENABLED=0 GOOS=linux go build -o onlyflick-backend ./cmd/server

# Étape finale
FROM alpine:latest

RUN apk --no-cache add ca-certificates

WORKDIR /app

COPY --from=builder /app/onlyflick-backend .

EXPOSE 8080

CMD ["./onlyflick-backend"]
