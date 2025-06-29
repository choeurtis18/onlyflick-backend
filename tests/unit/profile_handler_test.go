package unit

import (
	"context"
	"net/http"
	"net/http/httptest"
	"onlyflick/internal/handler"
	"onlyflick/internal/middleware"
	"onlyflick/internal/utils"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
)

func TestProfileHandlerSuccess(t *testing.T) {
	// Configuration
	utils.SetSecretKeyForTesting("12345678901234567890123456789012")
	defer utils.SetSecretKeyForTesting("")

	mock, cleanup := setupMockDB(t)
	defer cleanup()

	userID := int64(123)
	now := time.Now()

	// Mock GetUserByID avec toutes les colonnes nécessaires
	rows := mock.NewRows([]string{
		"id", "first_name", "last_name", "email", "password", "role",
		"created_at", "updated_at", "avatar_url", "bio", "username",
	}).AddRow(
		userID, "Test", "User", "encrypted_email", "hashed_password", "subscriber",
		now, now, "avatar.jpg", "Test bio", "testuser",
	)

	mock.ExpectQuery("SELECT id, first_name, last_name, email, password, role, created_at, updated_at, avatar_url, bio, username FROM users WHERE").
		WithArgs(userID).
		WillReturnRows(rows)

	// Créer la requête
	req := httptest.NewRequest(http.MethodGet, "/profile", nil)
	ctx := context.WithValue(req.Context(), middleware.ContextUserIDKey, userID)
	req = req.WithContext(ctx)

	rr := httptest.NewRecorder()
	handler.ProfileHandler(rr, req)

	assert.Equal(t, http.StatusOK, rr.Code)
	assert.Contains(t, rr.Body.String(), "email")
	assert.Contains(t, rr.Body.String(), "first_name")
}

func TestProfileHandlerUnauthorized(t *testing.T) {
	req := httptest.NewRequest(http.MethodGet, "/profile", nil)

	rr := httptest.NewRecorder()
	handler.ProfileHandler(rr, req)

	assert.Equal(t, http.StatusUnauthorized, rr.Code)
	assert.Contains(t, rr.Body.String(), "Utilisateur non authentifié")
}
