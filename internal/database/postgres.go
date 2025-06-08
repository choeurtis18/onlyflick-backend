package database

import (
	"database/sql"
	"log"
	"os"
	"time"

	_ "github.com/lib/pq"
)

// DB est la variable globale pour la connexion à la base de données PostgreSQL.
var DB *sql.DB

// Init initialise la connexion à la base de données PostgreSQL en utilisant la variable d'environnement DATABASE_URL.
// Elle configure le pool de connexions et effectue un ping pour vérifier la connexion.
// En cas d'erreur, l'application s'arrête avec un message explicite.
func Init() {
	log.Println("[database] 🚀 Initialisation de la connexion à la base de données PostgreSQL...")

	// Récupération de l'URL de connexion depuis la variable d'environnement
	url := os.Getenv("DATABASE_URL")
	if url == "" {
		log.Fatal("[database] ❌ La variable d'environnement DATABASE_URL n'est pas définie.")
	}

	var err error
	DB, err = sql.Open("postgres", url)
	if err != nil {
		log.Fatalf("[database] ❌ Échec de l'ouverture de la base de données : %v", err)
	}

	// Configuration du pool de connexions
	DB.SetMaxOpenConns(25)                 // Nombre maximal de connexions ouvertes
	DB.SetMaxIdleConns(25)                 // Nombre maximal de connexions inactives
	DB.SetConnMaxLifetime(5 * time.Minute) // Durée de vie maximale d'une connexion

	// Vérification de la connexion à la base de données
	if err := DB.Ping(); err != nil {
		log.Fatalf("[database] ❌ Impossible de joindre la base de données : %v", err)
	}

	log.Printf("[database] ✅ Connexion à PostgreSQL réussie (%s)", url)
}
