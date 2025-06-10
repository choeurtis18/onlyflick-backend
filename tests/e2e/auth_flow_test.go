package e2e

import (
	"bytes"
	"database/sql"
	"encoding/json"
	"fmt"
	"net/http"
	"net/http/httptest"
	"onlyflick/api"
	"onlyflick/internal/database"
	"onlyflick/internal/utils"
	"os"
	"path/filepath"
	"testing"
	"time"

	"github.com/joho/godotenv"
	_ "github.com/lib/pq"
	"github.com/stretchr/testify/assert"
)

func setupE2EEnv(t *testing.T) {
	// Charger le fichier .env depuis la racine du projet
	envPath := filepath.Join("..", "..", ".env")
	if err := godotenv.Load(envPath); err != nil {
		t.Logf("Impossible de charger le fichier .env: %v", err)
		// Fallback avec valeurs par défaut
		os.Setenv("SECRET_KEY", "12345678901234567890123456789012")
		os.Setenv("DATABASE_URL", "postgresql://onlyflick_db_owner:npg_GuDKP6U3gYtZ@ep-curly-sun-a2np1ifi-pooler.eu-central-1.aws.neon.tech/onlyflick_db?sslmode=require")
	}

	// Vérifier que les variables d'environnement critiques sont définies
	secretKey := os.Getenv("SECRET_KEY")
	databaseURL := os.Getenv("DATABASE_URL")

	if secretKey == "" {
		t.Log("SECRET_KEY non définie, utilisation de la valeur par défaut")
		secretKey = "12345678901234567890123456789012"
		os.Setenv("SECRET_KEY", secretKey)
	}
	if databaseURL == "" {
		t.Fatal("DATABASE_URL non définie")
	}

	t.Logf("SECRET_KEY chargée: %s", secretKey)
	t.Logf("DATABASE_URL chargée: %s", databaseURL)

	// Configurer la clé pour les utils
	utils.SetSecretKeyForTesting(secretKey)

	// Initialiser la base de données manuellement si elle n'existe pas
	if database.DB == nil {
		db, err := sql.Open("postgres", databaseURL)
		if err != nil {
			t.Fatalf("Impossible d'ouvrir la connexion à la base de données: %v", err)
		}

		if err := db.Ping(); err != nil {
			t.Fatalf("Impossible de se connecter à la base de données: %v", err)
		}

		database.DB = db
	}
}

func TestRegisterLoginProfileFlow(t *testing.T) {
	// Configuration de l'environnement E2E
	setupE2EEnv(t)

	// Générer un email unique avec plus de précision
	testEmail := fmt.Sprintf("e2e_%d_%d@example.com", time.Now().Unix(), time.Now().Nanosecond())
	t.Logf("Test email: %s", testEmail)

	// Nettoyage plus agressif - supprimer tous les emails e2e de test
	cleanupAllTestData(t)

	// Nettoyage après le test
	t.Cleanup(func() {
		cleanupTestData(t, testEmail)
		cleanupAllTestData(t)
		utils.SetSecretKeyForTesting("")
	})

	router := api.SetupRoutes()

	// 1. Register
	registerPayload := map[string]string{
		"email":      testEmail,
		"password":   "supersecret",
		"first_name": "E2E",
		"last_name":  "Test",
	}
	registerBody, _ := json.Marshal(registerPayload)
	req := httptest.NewRequest(http.MethodPost, "/register", bytes.NewReader(registerBody))
	req.Header.Set("Content-Type", "application/json")

	rr := httptest.NewRecorder()
	router.ServeHTTP(rr, req)

	t.Logf("Register response: %s", rr.Body.String())
	assert.Equal(t, http.StatusCreated, rr.Code)

	// 2. Login
	loginPayload := map[string]string{
		"email":    testEmail,
		"password": "supersecret",
	}
	loginBody, _ := json.Marshal(loginPayload)
	req = httptest.NewRequest(http.MethodPost, "/login", bytes.NewReader(loginBody))
	req.Header.Set("Content-Type", "application/json")
	rr = httptest.NewRecorder()
	router.ServeHTTP(rr, req)

	t.Logf("Login response: %s", rr.Body.String())
	assert.Equal(t, http.StatusOK, rr.Code)

	var loginResp map[string]interface{}
	json.Unmarshal(rr.Body.Bytes(), &loginResp)
	token, ok := loginResp["token"].(string)
	assert.True(t, ok, "Token should be a string")
	assert.NotEmpty(t, token)

	// 3. Get Profile
	req = httptest.NewRequest(http.MethodGet, "/profile", nil)
	req.Header.Set("Authorization", "Bearer "+token)
	rr = httptest.NewRecorder()
	router.ServeHTTP(rr, req)

	t.Logf("Profile response: %s", rr.Body.String())
	assert.Equal(t, http.StatusOK, rr.Code)
	assert.Contains(t, rr.Body.String(), "email")
}

// cleanupAllTestData supprime tous les utilisateurs de test e2e
func cleanupAllTestData(t *testing.T) {
	if database.DB == nil {
		return
	}

	// Supprimer tous les utilisateurs avec des emails commençant par e2e_
	_, err := database.DB.Exec("DELETE FROM users WHERE email LIKE 'e2e_%@example.com'")
	if err != nil {
		t.Logf("Erreur lors du nettoyage global des données de test: %v", err)
	}
}
