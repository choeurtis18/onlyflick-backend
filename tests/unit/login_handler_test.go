package unit

import (
	"bytes"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"onlyflick/internal/handler"
	"onlyflick/internal/service"
	"onlyflick/internal/utils"
	"os"
	"strings"
	"testing"

	"github.com/DATA-DOG/go-sqlmock"
	"github.com/stretchr/testify/assert"
)

func TestLoginHandlerSuccess(t *testing.T) {
	// Configuration
	os.Setenv("SECRET_KEY", "12345678901234567890123456789012")
	utils.SetSecretKeyForTesting("12345678901234567890123456789012")
	defer utils.SetSecretKeyForTesting("")

	mock, cleanup := setupMockDB(t)
	defer cleanup()

	// Hasher le mot de passe de test
	hashedPassword, _ := service.HashPassword("password123")

	// Chiffrer l'email de test
	encryptedEmail, _ := utils.EncryptAES("john@test.com")

	// Mock pour GetUserByEmail avec regex
	mock.ExpectQuery("SELECT.*FROM users").
		WillReturnRows(sqlmock.NewRows([]string{"id", "first_name", "last_name", "email", "password", "role"}).
			AddRow(1, "encrypted_john", "encrypted_doe", encryptedEmail, hashedPassword, "subscriber"))

	// Corps de la requête
	loginData := map[string]string{
		"email":    "john@test.com",
		"password": "password123",
	}
	body, _ := json.Marshal(loginData)

	req := httptest.NewRequest(http.MethodPost, "/login", bytes.NewReader(body))
	req.Header.Set("Content-Type", "application/json")

	rr := httptest.NewRecorder()
	handler.LoginHandler(rr, req)

	assert.Equal(t, http.StatusOK, rr.Code)
	assert.Contains(t, rr.Body.String(), "token")
	assert.Contains(t, rr.Body.String(), "Connexion réussie")
}

func TestLoginHandlerInvalidJSON(t *testing.T) {
	req := httptest.NewRequest(http.MethodPost, "/login", strings.NewReader("invalid json"))
	req.Header.Set("Content-Type", "application/json")

	rr := httptest.NewRecorder()
	handler.LoginHandler(rr, req)

	assert.Equal(t, http.StatusBadRequest, rr.Code)
	assert.Contains(t, rr.Body.String(), "Requête invalide")
}

func TestLoginHandlerUserNotFound(t *testing.T) {
	mock, cleanup := setupMockDB(t)
	defer cleanup()

	// Mock pour GetUserByEmail - aucun utilisateur trouvé
	mock.ExpectQuery("SELECT id, first_name, last_name, email, password, role FROM users").
		WillReturnRows(sqlmock.NewRows([]string{"id", "first_name", "last_name", "email", "password", "role"}))

	loginData := map[string]string{
		"email":    "notfound@test.com",
		"password": "password123",
	}
	body, _ := json.Marshal(loginData)

	req := httptest.NewRequest(http.MethodPost, "/login", bytes.NewReader(body))
	req.Header.Set("Content-Type", "application/json")

	rr := httptest.NewRecorder()
	handler.LoginHandler(rr, req)

	assert.Equal(t, http.StatusUnauthorized, rr.Code)
	assert.Contains(t, rr.Body.String(), "Email ou mot de passe invalide")
}
