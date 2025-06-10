package unit

import (
	"onlyflick/internal/service"
	"testing"

	"github.com/stretchr/testify/assert"
)

func TestHashPassword(t *testing.T) {
	password := "testpassword123"

	hash, err := service.HashPassword(password)

	assert.NoError(t, err)
	assert.NotEmpty(t, hash)
	assert.NotEqual(t, password, hash)
}

func TestCheckPasswordHash(t *testing.T) {
	password := "testpassword123"
	wrongPassword := "wrongpassword"

	hash, _ := service.HashPassword(password)

	// Test avec le bon mot de passe
	assert.True(t, service.CheckPasswordHash(password, hash))

	// Test avec le mauvais mot de passe
	assert.False(t, service.CheckPasswordHash(wrongPassword, hash))
}

func TestGenerateJWT(t *testing.T) {
	userID := int64(123)
	role := "subscriber"

	token, err := service.GenerateJWT(userID, role)

	assert.NoError(t, err)
	assert.NotEmpty(t, token)
	assert.Contains(t, token, ".")
}

func TestValidateJWT(t *testing.T) {
	userID := int64(123)
	role := "subscriber"

	// Générer un token valide
	token, _ := service.GenerateJWT(userID, role)

	// Valider le token
	parsedToken, err := service.ValidateJWT(token)

	assert.NoError(t, err)
	assert.True(t, parsedToken.Valid)
}

func TestValidateJWT_InvalidToken(t *testing.T) {
	invalidToken := "invalid.token.here"

	parsedToken, err := service.ValidateJWT(invalidToken)

	assert.Error(t, err)
	assert.False(t, parsedToken.Valid)
}
