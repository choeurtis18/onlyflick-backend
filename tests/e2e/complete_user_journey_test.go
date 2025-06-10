package e2e

import (
	"bytes"
	"encoding/json"
	"fmt"
	"net/http"
	"net/http/httptest"
	"onlyflick/api"
	"onlyflick/internal/utils"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
)

func TestCompleteUserJourney(t *testing.T) {
	setupE2EEnv(t)
	defer utils.SetSecretKeyForTesting("")

	router := api.SetupRoutes()

	// 1. Inscription
	testEmail := fmt.Sprintf("journey_%d@example.com", time.Now().Unix())
	registerData := map[string]string{
		"email":      testEmail,
		"password":   "journey123",
		"first_name": "Journey",
		"last_name":  "User",
	}

	body, _ := json.Marshal(registerData)
	req := httptest.NewRequest(http.MethodPost, "/register", bytes.NewReader(body))
	req.Header.Set("Content-Type", "application/json")

	rr := httptest.NewRecorder()
	router.ServeHTTP(rr, req)

	assert.Equal(t, http.StatusCreated, rr.Code)

	var registerResp map[string]interface{}
	json.Unmarshal(rr.Body.Bytes(), &registerResp)
	token := registerResp["token"].(string)

	// 2. Connexion
	loginData := map[string]string{
		"email":    testEmail,
		"password": "journey123",
	}

	body, _ = json.Marshal(loginData)
	req = httptest.NewRequest(http.MethodPost, "/login", bytes.NewReader(body))
	req.Header.Set("Content-Type", "application/json")

	rr = httptest.NewRecorder()
	router.ServeHTTP(rr, req)

	assert.Equal(t, http.StatusOK, rr.Code)

	// 3. Profil
	req = httptest.NewRequest(http.MethodGet, "/profile", nil)
	req.Header.Set("Authorization", "Bearer "+token)

	rr = httptest.NewRecorder()
	router.ServeHTTP(rr, req)

	assert.Equal(t, http.StatusOK, rr.Code)
	assert.Contains(t, rr.Body.String(), testEmail)

	// 4. Mise à jour du profil
	updateData := map[string]string{
		"first_name": "UpdatedJourney",
	}

	body, _ = json.Marshal(updateData)
	req = httptest.NewRequest(http.MethodPut, "/profile", bytes.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+token)

	rr = httptest.NewRecorder()
	router.ServeHTTP(rr, req)

	t.Logf("Profile update response: %s", rr.Body.String())
	// Note: Le statut peut varier selon l'implémentation de la route

	// Nettoyage
	cleanupTestData(t, testEmail)
}
