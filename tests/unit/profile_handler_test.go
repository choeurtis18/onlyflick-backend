package unit

import (
	"context"
	"net/http"
	"net/http/httptest"
	"onlyflick/internal/handler"
	"onlyflick/internal/middleware"
	"onlyflick/internal/utils"
	"os"
	"testing"

	"github.com/DATA-DOG/go-sqlmock"
	"github.com/stretchr/testify/assert"
)

func TestProfileHandlerSuccess(t *testing.T) {
	// Configuration
	os.Setenv("SECRET_KEY", "12345678901234567890123456789012")
	utils.SetSecretKeyForTesting("12345678901234567890123456789012")
	defer utils.SetSecretKeyForTesting("")

	mock, cleanup := setupMockDB(t)
	defer cleanup()

	userID := int64(123)

	// Mock pour GetUserByID avec regex flexible
	mock.ExpectQuery("SELECT.*FROM users WHERE.*id").
		WithArgs(userID).
		WillReturnRows(sqlmock.NewRows([]string{"id", "first_name", "last_name", "email", "password", "role"}).
			AddRow(userID, "encrypted_john", "encrypted_doe", "encrypted_john@test.com", "hashedpwd", "subscriber"))

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
