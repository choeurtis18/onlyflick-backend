package main

import (
	"log"
	"net/http"
	"onlyflick/api"
	"onlyflick/internal/config"
	"onlyflick/internal/database"
	"onlyflick/internal/service"
)

// Point d'entrée principal du serveur OnlyFlick
func main() {
	log.Println("🔧 [DEMARRAGE] Initialisation du serveur OnlyFlick...")

	// Chargement des variables d'environnement
	log.Println("🌱 [CONFIG] Chargement des variables d'environnement...")
	config.LoadEnv()
	log.Println("✅ [CONFIG] Variables d'environnement chargées.")

	// Connexion à la base de données
	log.Println("🔗 [BD] Connexion à la base de données...")
	database.Init()
	log.Println("✅ [BD] Connexion à la base de données réussie.")

	// Exécution des migrations de la base de données
	log.Println("🛠️ [BD] Exécution des migrations de la base de données...")
	database.RunMigrations()
	log.Println("✅ [BD] Migrations terminées.")

	// Initialisation du service ImageKit
	log.Println("🖼️ [SERVICE] Initialisation du service ImageKit...")
	service.InitImageKit()
	log.Println("✅ [SERVICE] Service ImageKit initialisé.")

	// Configuration des routes de l'API
	log.Println("🛣️ [ROUTAGE] Configuration des routes de l'API...")
	router := api.SetupRoutes()
	log.Println("✅ [ROUTAGE] Routes de l'API configurées.")

	// Démarrage du serveur HTTP
	addr := ":8080"
	log.Printf("🚀 [SERVEUR] Le serveur OnlyFlick est démarré sur http://localhost%s\n", addr)
	if err := http.ListenAndServe(addr, router); err != nil {
		log.Fatalf("❌ [ERREUR FATALE] Échec du démarrage du serveur : %v", err)
	}
}
