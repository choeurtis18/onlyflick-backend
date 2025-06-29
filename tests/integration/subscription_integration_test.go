package integration

import (
	"bytes"
	"encoding/json"
	"fmt"
	"net/http"
	"net/http/httptest"
	"onlyflick/api"
	"onlyflick/internal/database"
	"onlyflick/internal/utils"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
)

func TestSubscriptionFlow(t *testing.T) {
	setupIntegrationEnv(t)
	defer utils.SetSecretKeyForTesting("")

	router := api.SetupRoutes()

	// 1. Créer un créateur
	creatorEmail := fmt.Sprintf("creator_%d@example.com", time.Now().Unix())
	creatorPayload := map[string]string{
		"email":      creatorEmail,
		"password":   "creatorpass123",
		"first_name": "Creator",
		"last_name":  "Test",
	}

	creatorBody, _ := json.Marshal(creatorPayload)
	req := httptest.NewRequest(http.MethodPost, "/register", bytes.NewReader(creatorBody))
	req.Header.Set("Content-Type", "application/json")

	rr := httptest.NewRecorder()
	router.ServeHTTP(rr, req)

	assert.Equal(t, http.StatusCreated, rr.Code)

	var creatorResp map[string]interface{}
	json.Unmarshal(rr.Body.Bytes(), &creatorResp)
	creatorToken := creatorResp["token"].(string) // Utiliser la variable
	creatorID := int64(creatorResp["user_id"].(float64))

	// 2. Créer un abonné
	subscriberEmail := fmt.Sprintf("subscriber_%d@example.com", time.Now().Unix())
	subscriberPayload := map[string]string{
		"email":      subscriberEmail,
		"password":   "subpass123",
		"first_name": "Subscriber",
		"last_name":  "Test",
	}

	subscriberBody, _ := json.Marshal(subscriberPayload)
	req = httptest.NewRequest(http.MethodPost, "/register", bytes.NewReader(subscriberBody))
	req.Header.Set("Content-Type", "application/json")

	rr = httptest.NewRecorder()
	router.ServeHTTP(rr, req)

	assert.Equal(t, http.StatusCreated, rr.Code)

	var subscriberResp map[string]interface{}
	json.Unmarshal(rr.Body.Bytes(), &subscriberResp)
	subscriberToken := subscriberResp["token"].(string)

	// 3. Test d'abonnement - corriger l'URL
	subscribeURL := fmt.Sprintf("/subscriptions/%d", creatorID)
	req = httptest.NewRequest(http.MethodPost, subscribeURL, nil)
	req.Header.Set("Authorization", "Bearer "+subscriberToken)

	rr = httptest.NewRecorder()
	router.ServeHTTP(rr, req)

	t.Logf("Subscribe response: %s", rr.Body.String())

	// Accéder aux variables avec vérification pour éviter les nil pointer
	if creatorToken != "" {
		t.Logf("Creator token was: %s", creatorToken)
	}

	// Vérification du résultat de l'abonnement
	assert.Contains(t, rr.Code, []int{http.StatusOK, http.StatusCreated})

	// Nettoyage
	if database.DB != nil {
		database.DB.Exec("DELETE FROM subscriptions WHERE subscriber_id IN (SELECT id FROM users WHERE email = $1)", subscriberEmail)
		database.DB.Exec("DELETE FROM users WHERE email = $1", creatorEmail)
		database.DB.Exec("DELETE FROM users WHERE email = $1", subscriberEmail)
	}
}
