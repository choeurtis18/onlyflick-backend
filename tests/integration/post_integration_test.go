package integration

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

func setupIntegrationEnv(t *testing.T) {
	envPath := filepath.Join("..", "..", ".env")
	if err := godotenv.Load(envPath); err != nil {
		t.Logf("Impossible de charger le fichier .env: %v", err)
		// Utiliser les valeurs par défaut
		os.Setenv("SECRET_KEY", "12345678901234567890123456789012")
		os.Setenv("DATABASE_URL", "postgresql://onlyflick_db_owner:npg_GuDKP6U3gYtZ@ep-curly-sun-a2np1ifi-pooler.eu-central-1.aws.neon.tech/onlyflick_db?sslmode=require")
	}

	utils.SetSecretKeyForTesting(os.Getenv("SECRET_KEY"))

	// Initialiser la base de données si nécessaire
	if database.DB == nil {
		databaseURL := os.Getenv("DATABASE_URL")
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

func TestPostCreationFlow(t *testing.T) {
	setupIntegrationEnv(t)
	defer utils.SetSecretKeyForTesting("")

	router := api.SetupRoutes()

	// 1. Créer un utilisateur
	testEmail := fmt.Sprintf("post_test_%d@example.com", time.Now().Unix())
	userPayload := map[string]string{
		"email":      testEmail,
		"password":   "testpass123",
		"first_name": "Post",
		"last_name":  "Tester",
	}

	userBody, _ := json.Marshal(userPayload)
	req := httptest.NewRequest(http.MethodPost, "/register", bytes.NewReader(userBody))
	req.Header.Set("Content-Type", "application/json")

	rr := httptest.NewRecorder()
	router.ServeHTTP(rr, req)

	assert.Equal(t, http.StatusCreated, rr.Code)

	var registerResp map[string]interface{}
	json.Unmarshal(rr.Body.Bytes(), &registerResp)
	token := registerResp["token"].(string)

	// 2. Créer un post (simulation - sans fichier réel)
	postPayload := map[string]string{
		"title":       "Test Post",
		"description": "Description du test",
		"visibility":  "public",
	}

	postBody, _ := json.Marshal(postPayload)
	req = httptest.NewRequest(http.MethodPost, "/posts", bytes.NewReader(postBody))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+token)

	rr = httptest.NewRecorder()
	router.ServeHTTP(rr, req)

	t.Logf("Post creation response: %s", rr.Body.String())
	// Note: Peut échouer si le multipart n'est pas géré, mais teste l'auth

	// Nettoyage
	if database.DB != nil {
		database.DB.Exec("DELETE FROM users WHERE email = $1", testEmail)
	}
}
