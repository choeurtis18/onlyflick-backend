package config

import (
	"log"
	"os"
	"path/filepath"

	"github.com/joho/godotenv"
)

// SecretKey contient la clé secrète de l'application chargée depuis les variables d'environnement.
var SecretKey string

// LoadEnv charge les variables d'environnement depuis un fichier .env et valide les variables requises.
func LoadEnv() {
	log.Println("[CONFIG] 🔄 Chargement des variables d'environnement depuis le fichier .env...")

	// Récupère le répertoire de travail courant
	dir, err := os.Getwd()
	if err != nil {
		log.Fatalf("[CONFIG] ❌ Impossible de récupérer le répertoire de travail : %v", err)
	}

	// Construit le chemin vers le fichier .env
	envPath := filepath.Join(dir, ".env")

	// Charge le fichier .env (écrase les variables existantes)
	if err := godotenv.Overload(envPath); err != nil {
		log.Printf("[CONFIG] ⚠️  Fichier .env introuvable ou erreur de chargement : %s (%v)", envPath, err)
	} else {
		log.Printf("[CONFIG] ✅ Fichier .env chargé avec succès : %s", envPath)
	}

	// Vérifie que les variables d'environnement requises sont définies
	SecretKey = os.Getenv("SECRET_KEY")
	if SecretKey == "" {
		log.Fatal("[CONFIG] ❌ La variable requise SECRET_KEY n'est pas définie dans le .env")
	}
	if os.Getenv("DATABASE_URL") == "" {
		log.Fatal("[CONFIG] ❌ La variable requise DATABASE_URL n'est pas définie dans le .env")
	}

	log.Println("[CONFIG] ✅ Toutes les variables d'environnement requises sont définies.")
}
