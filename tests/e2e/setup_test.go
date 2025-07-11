package e2e

import (
	"database/sql"
	"log"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"onlyflick/internal/database"
	"onlyflick/internal/utils"

	"github.com/joho/godotenv"
	_ "github.com/lib/pq"
)

// Schema minimal pour les tests e2e
const testDBSchema = `
CREATE TABLE IF NOT EXISTS users (
    id SERIAL PRIMARY KEY,
    username VARCHAR(50) UNIQUE NOT NULL,
    email TEXT UNIQUE NOT NULL,
    password TEXT NOT NULL,
    first_name TEXT NOT NULL,
    last_name TEXT NOT NULL,
    role VARCHAR(20) NOT NULL DEFAULT 'subscriber',
    bio TEXT,
    avatar_url TEXT,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS posts (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    content TEXT NOT NULL,
    media_url TEXT,
    visibility VARCHAR(20) NOT NULL DEFAULT 'public',
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS subscriptions (
    id SERIAL PRIMARY KEY,
    subscriber_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    creator_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    status BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    end_at TIMESTAMP,
    UNIQUE(subscriber_id, creator_id)
);

CREATE TABLE IF NOT EXISTS likes (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    post_id INTEGER NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    UNIQUE(user_id, post_id)
);
`

func TestMain(m *testing.M) {
	var exitCode int = 0
	defer func() {
		// Capture les panics pour avoir un rapport d'erreur propre
		if r := recover(); r != nil {
			log.Printf("E2E Test panic: %v", r)
			exitCode = 1
		}
		os.Exit(exitCode)
	}()

	log.Println("Initialisation des tests E2E...")

	// 1) Charger le .env (mais continuer si le fichier n'existe pas)
	envPath := filepath.Join("..", "..", ".env")
	if err := godotenv.Load(envPath); err != nil {
		log.Printf(".env non trouvé: %v - utilisation des valeurs par défaut", err)
	} else {
		log.Println(".env chargé avec succès")
	}

	// 2) SECRET_KEY
	secretKey := os.Getenv("SECRET_KEY")
	if secretKey == "" {
		secretKey = "12345678901234567890123456789012"
		os.Setenv("SECRET_KEY", secretKey)
		log.Println("SECRET_KEY non définie, utilisation de la valeur par défaut")
	}
	utils.SetSecretKeyForTesting(secretKey)
	log.Println("SECRET_KEY configurée")

	// 3) DATABASE_URL & connexion
	databaseURL := os.Getenv("DATABASE_URL")
	if databaseURL == "" {
		// Utiliser l'URL PostgreSQL fournie par GitHub Actions
		databaseURL = "postgresql://postgres:postgres@localhost:5432/onlyflick_test?sslmode=disable"
		os.Setenv("DATABASE_URL", databaseURL)
		log.Printf("DATABASE_URL non définie, utilisation de: %s",
			strings.Replace(databaseURL, "postgres:postgres", "postgres:***", 1))
	}

	// Tentatives multiples de connexion avec délai
	var db *sql.DB
	var err error
	maxRetries := 3

	for i := 0; i < maxRetries; i++ {
		log.Printf("Tentative de connexion à la BD (%d/%d)...", i+1, maxRetries)

		db, err = sql.Open("postgres", databaseURL)
		if err == nil {
			if err = db.Ping(); err == nil {
				log.Println("Connexion à la BD réussie")
				break
			}
		}

		if i < maxRetries-1 {
			log.Printf("Échec connexion: %v - nouvelle tentative dans 2 secondes...", err)
			time.Sleep(2 * time.Second)
		} else {
			log.Printf("Toutes les tentatives de connexion ont échoué: %v", err)
			exitCode = 1
			return
		}
	}

	database.DB = db

	// 4) Création du schéma de test si nécessaire
	log.Println("Initialisation du schéma de test...")
	if _, err = db.Exec(testDBSchema); err != nil {
		log.Printf("Erreur lors de la création du schéma: %v", err)
		exitCode = 1
		return
	}
	log.Println("Schéma de test initialisé")

	// 5) Lancer la suite de tests
	log.Println("Démarrage des tests E2E...")
	exitCode = m.Run()

	// 6) Nettoyage
	if db != nil {
		log.Println("Nettoyage des données de test...")
		_, _ = db.Exec("DELETE FROM users WHERE email LIKE 'e2e_%@example.com'")
		_ = db.Close()
	}
	log.Println("Tests E2E terminés")
}
