package e2e

import (
	"bytes"
	"encoding/json"
	"net/http"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
)

func TestFrontendBackendIntegration(t *testing.T) {
	// Configuration
	frontendURL := "http://onlyflick.local"
	backendURL := "http://api.onlyflick.local"

	// Test 1: Frontend accessible
	t.Run("Frontend accessible", func(t *testing.T) {
		resp, err := http.Get(frontendURL)
		assert.NoError(t, err)
		assert.Equal(t, http.StatusOK, resp.StatusCode)
		resp.Body.Close()
	})

	// Test 2: API backend accessible depuis frontend
	t.Run("API via frontend", func(t *testing.T) {
		resp, err := http.Get(frontendURL + "/api/health")
		assert.NoError(t, err)
		assert.Equal(t, http.StatusOK, resp.StatusCode)
		resp.Body.Close()
	})

	// Test 3: Workflow complet register -> login
	t.Run("Complete auth workflow", func(t *testing.T) {
		// Registration
		registerData := map[string]string{
			"email":      "e2e-fullstack@example.com",
			"password":   "password123",
			"first_name": "E2E",
			"last_name":  "Fullstack",
		}

		registerJSON, _ := json.Marshal(registerData)
		resp, err := http.Post(backendURL+"/register", "application/json", bytes.NewBuffer(registerJSON))
		assert.NoError(t, err)
		assert.Equal(t, http.StatusCreated, resp.StatusCode)
		resp.Body.Close()

		// Login
		loginData := map[string]string{
			"email":    "e2e-fullstack@example.com",
			"password": "password123",
		}

		loginJSON, _ := json.Marshal(loginData)
		resp, err = http.Post(backendURL+"/login", "application/json", bytes.NewBuffer(loginJSON))
		assert.NoError(t, err)
		assert.Equal(t, http.StatusOK, resp.StatusCode)
		resp.Body.Close()
	})
}

func TestCORSConfiguration(t *testing.T) {
	// Test CORS depuis le frontend
	client := &http.Client{Timeout: 10 * time.Second}
	req, _ := http.NewRequest("OPTIONS", "http://api.onlyflick.local/health", nil)
	req.Header.Set("Origin", "http://onlyflick.local")
	req.Header.Set("Access-Control-Request-Method", "GET")

	resp, err := client.Do(req)
	assert.NoError(t, err)
	// 204 No Content est la réponse correcte pour OPTIONS
	assert.Equal(t, http.StatusNoContent, resp.StatusCode)

	// Vérifier headers CORS
	assert.Equal(t, "*", resp.Header.Get("Access-Control-Allow-Origin"))
	resp.Body.Close()
}
