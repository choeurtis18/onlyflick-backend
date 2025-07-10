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
	"strings"
	"testing"
	"time"

	"github.com/joho/godotenv"
	_ "github.com/lib/pq"
	"github.com/stretchr/testify/assert"
)

func setupE2EEnv(t *testing.T) {
	// Charger le .env à la racine du projet
	envPath := filepath.Join("..", "..", ".env")
	if err := godotenv.Load(envPath); err != nil {
		t.Logf("Impossible de charger .env: %v", err)
		// Valeurs par défaut
		os.Setenv("SECRET_KEY", "12345678901234567890123456789012")
		os.Setenv("DATABASE_URL", "postgresql://onlyflick_db_owner:npg_GuDKP6U3gYtZ@ep-curly-sun-a2np1ifi-pooler.eu-central-1.aws.neon.tech/onlyflick_db?sslmode=require")
	}

	secretKey := os.Getenv("SECRET_KEY")
	databaseURL := os.Getenv("DATABASE_URL")
	if secretKey == "" {
		t.Log("SECRET_KEY non définie, fallback par défaut")
		secretKey = "12345678901234567890123456789012"
		os.Setenv("SECRET_KEY", secretKey)
	}
	if databaseURL == "" {
		t.Fatal("DATABASE_URL non définie")
	}

	t.Logf("SECRET_KEY chargée: %s", secretKey)
	t.Logf("DATABASE_URL chargée: %s", databaseURL)
	utils.SetSecretKeyForTesting(secretKey)

	// Initialiser la connexion DB si nécessaire
	if database.DB == nil {
		db, err := sql.Open("postgres", databaseURL)
		if err != nil {
			t.Fatalf("Impossible d'ouvrir la BD: %v", err)
		}
		if err := db.Ping(); err != nil {
			t.Fatalf("Impossible de pinger la BD: %v", err)
		}
		database.DB = db
	}
}

func TestRegisterLoginProfileFlow(t *testing.T) {
	// 1) Setup E2E env
	setupE2EEnv(t)

	// 2) Générer email unique & username tronqué à 20 chars max
	testEmail := fmt.Sprintf("e2e_%d_%d@example.com", time.Now().Unix(), time.Now().Nanosecond())
	rawUsername := strings.Split(testEmail, "@")[0]
	username := rawUsername
	if len(username) > 20 {
		username = username[:20]
	}
	t.Logf("Test email: %s", testEmail)
	t.Logf("Test username: %s", username)

	// 3) Nettoyage avant test
	cleanupAllTestData(t)

	// 4) Nettoyage après test
	t.Cleanup(func() {
		cleanupTestData(t, testEmail)
		cleanupAllTestData(t)
		utils.SetSecretKeyForTesting("")
	})

	router := api.SetupRoutes()

	// --- Étape 1 : Inscription ---
	registerPayload := map[string]string{
		"username":   username,
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

	// --- Étape 2 : Connexion ---
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

	// --- Étape 3 : Profil ---
	req = httptest.NewRequest(http.MethodGet, "/profile", nil)
	req.Header.Set("Authorization", "Bearer "+token)
	rr = httptest.NewRecorder()
	router.ServeHTTP(rr, req)

	t.Logf("Profile response: %s", rr.Body.String())
	assert.Equal(t, http.StatusOK, rr.Code)
	assert.Contains(t, rr.Body.String(), `"email"`)
}
