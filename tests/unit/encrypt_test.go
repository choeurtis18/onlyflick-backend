package unit

import (
	"onlyflick/internal/utils"
	"os"
	"testing"

	"github.com/stretchr/testify/assert"
)

func TestEncryptDecryptAES(t *testing.T) {
	// Configuration de la clé de test
	testKey := "12345678901234567890123456789012"
	utils.SetSecretKeyForTesting(testKey)
	defer utils.SetSecretKeyForTesting("")

	originalText := "test@example.com"

	// Test de chiffrement
	encrypted, err := utils.EncryptAES(originalText)
	assert.NoError(t, err)
	assert.NotEmpty(t, encrypted)

	// Test de déchiffrement
	decrypted, err := utils.DecryptAES(encrypted)
	assert.NoError(t, err)
	assert.Equal(t, originalText, decrypted)
}

func TestGetSecretKey(t *testing.T) {
	// Test avec clé de test
	testKey := "testsecretkey123456789012345678"
	utils.SetSecretKeyForTesting(testKey)

	key := utils.GetSecretKey()
	assert.Equal(t, testKey, key)

	// Nettoyage
	utils.SetSecretKeyForTesting("")

	// Test avec variable d'environnement
	envKey := "envsecretkey1234567890123456789"
	os.Setenv("SECRET_KEY", envKey)
	defer os.Unsetenv("SECRET_KEY")

	key = utils.GetSecretKey()
	assert.Equal(t, envKey, key)
}
