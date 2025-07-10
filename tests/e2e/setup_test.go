package e2e

import (
	"database/sql"
	"os"
	"path/filepath"
	"testing"

	"onlyflick/internal/database"
	"onlyflick/internal/utils"

	_ "github.com/lib/pq"
	"github.com/joho/godotenv"
)

func TestMain(m *testing.M) {
	// 1) Charger le .env
	envPath := filepath.Join("..", "..", ".env")
	_ = godotenv.Load(envPath)

	// 2) SECRET_KEY
	secretKey := os.Getenv("SECRET_KEY")
	if secretKey == "" {
		secretKey = "12345678901234567890123456789012"
		os.Setenv("SECRET_KEY", secretKey)
	}
	utils.SetSecretKeyForTesting(secretKey)

	// 3) DATABASE_URL & connexion
	databaseURL := os.Getenv("DATABASE_URL")
	if databaseURL == "" {
		panic("DATABASE_URL non définie")
	}
	db, err := sql.Open("postgres", databaseURL)
	if err != nil {
		panic(err)
	}
	if err := db.Ping(); err != nil {
		panic(err)
	}
	database.DB = db

	// 4) Lancer la suite de tests
	code := m.Run()
	os.Exit(code)
}
