package unit

import (
	"bytes"
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"onlyflick/internal/handler"
	"onlyflick/internal/middleware"
	"onlyflick/internal/utils"
	"os"
	"testing"
	"time"

	"github.com/DATA-DOG/go-sqlmock"
	"github.com/go-chi/chi/v5"
	"github.com/stretchr/testify/assert"
)

func TestGetMyConversations(t *testing.T) {
	// Configuration
	os.Setenv("SECRET_KEY", "12345678901234567890123456789012")
	utils.SetSecretKeyForTesting("12345678901234567890123456789012")
	defer utils.SetSecretKeyForTesting("")

	mock, cleanup := setupMockDB(t)
	defer cleanup()

	userID := int64(123)

	// Mock pour récupérer les conversations - adapter selon le vrai format
	mock.ExpectQuery("SELECT.*FROM conversations WHERE.*creator_id.*OR.*subscriber_id.*ORDER BY").
		WithArgs(userID).
		WillReturnRows(sqlmock.NewRows([]string{"id", "user1_id", "user2_id", "created_at"}).
			AddRow(1, 456, userID, time.Now()).
			AddRow(2, userID, 789, time.Now()))

	req := httptest.NewRequest(http.MethodGet, "/conversations", nil)
	ctx := context.WithValue(req.Context(), middleware.ContextUserIDKey, userID)
	req = req.WithContext(ctx)

	rr := httptest.NewRecorder()
	handler.GetMyConversations(rr, req)

	assert.Equal(t, http.StatusOK, rr.Code)
	// Adapter l'assertion selon le format réel retourné
	assert.Contains(t, rr.Body.String(), "user1_id")
}

func TestSendMessageInConversation(t *testing.T) {
	// Configuration
	os.Setenv("SECRET_KEY", "12345678901234567890123456789012")
	utils.SetSecretKeyForTesting("12345678901234567890123456789012")
	defer utils.SetSecretKeyForTesting("")

	mock, cleanup := setupMockDB(t)
	defer cleanup()

	userID := int64(123)
	conversationID := int64(1)

	// Mock pour vérifier la participation - regex plus flexible
	mock.ExpectQuery("SELECT COUNT.*FROM conversations WHERE.*id.*AND.*creator_id.*OR.*subscriber_id").
		WithArgs(conversationID, userID).
		WillReturnRows(sqlmock.NewRows([]string{"count"}).AddRow(1))

	// Mock pour récupérer les détails de la conversation
	mock.ExpectQuery("SELECT.*creator_id.*subscriber_id.*FROM conversations WHERE.*id").
		WithArgs(conversationID).
		WillReturnRows(sqlmock.NewRows([]string{"creator_id", "subscriber_id"}).
			AddRow(456, userID))

	// Mock pour vérifier l'abonnement
	mock.ExpectQuery("SELECT EXISTS.*FROM subscriptions WHERE.*subscriber_id.*AND.*creator_id").
		WithArgs(userID, int64(456)).
		WillReturnRows(sqlmock.NewRows([]string{"exists"}).AddRow(true))

	// Mock pour créer le message
	mock.ExpectQuery("INSERT INTO messages.*VALUES.*RETURNING").
		WithArgs(conversationID, userID, "Test message").
		WillReturnRows(sqlmock.NewRows([]string{"id", "created_at"}).
			AddRow(1, time.Now()))

	// Créer le payload
	payload := map[string]string{"content": "Test message"}
	body, _ := json.Marshal(payload)

	// Créer un routeur Chi pour tester les paramètres d'URL
	r := chi.NewRouter()
	r.Post("/conversations/{id}/messages", handler.SendMessageInConversation)

	req := httptest.NewRequest(http.MethodPost, "/conversations/1/messages", bytes.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	ctx := context.WithValue(req.Context(), middleware.ContextUserIDKey, userID)
	req = req.WithContext(ctx)

	rr := httptest.NewRecorder()
	r.ServeHTTP(rr, req)

	assert.Equal(t, http.StatusCreated, rr.Code)
	assert.Contains(t, rr.Body.String(), "Test message")
}
