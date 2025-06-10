package unit

import (
	"onlyflick/internal/database"
	"onlyflick/internal/utils"
	"os"
	"testing"

	"github.com/DATA-DOG/go-sqlmock"
)

// setupMockDB configure une base de données mock avec matcher regex
func setupMockDB(t *testing.T) (sqlmock.Sqlmock, func()) {
	db, mock, err := sqlmock.New(sqlmock.QueryMatcherOption(sqlmock.QueryMatcherRegexp))
	if err != nil {
		t.Fatalf("Erreur création mock DB: %s", err)
	}
	database.DB = db

	cleanup := func() {
		_ = db.Close()
		database.DB = nil
	}
	return mock, cleanup
}

// setupMockDBExact configure une base de données mock avec matcher exact
func setupMockDBExact(t *testing.T) (sqlmock.Sqlmock, func()) {
	db, mock, err := sqlmock.New(sqlmock.QueryMatcherOption(sqlmock.QueryMatcherEqual))
	if err != nil {
		t.Fatalf("Erreur création mock DB: %s", err)
	}
	database.DB = db

	cleanup := func() {
		_ = db.Close()
		database.DB = nil
	}
	return mock, cleanup
}

// setupTestEnvironment configure l'environnement de test avec les variables d'environnement
func setupTestEnvironment() {
	secretKey := "12345678901234567890123456789012"
	os.Setenv("SECRET_KEY", secretKey)
	utils.SetSecretKeyForTesting(secretKey)
}

// setupFullTestEnvironment configure un environnement de test complet avec toutes les variables
func setupFullTestEnvironment() {
	// Variables d'environnement pour les tests avec les vraies valeurs du .env
	testEnvVars := map[string]string{
		"SECRET_KEY":            "12345678901234567890123456789012",
		"DATABASE_URL":          "postgresql://onlyflick_db_owner:npg_GuDKP6U3gYtZ@ep-curly-sun-a2np1ifi-pooler.eu-central-1.aws.neon.tech/onlyflick_db?sslmode=require",
		"IMAGEKIT_PRIVATE_KEY":  "private_eVPYpbL29tYvF3TSoFWFqnGLRzQ=",
		"IMAGEKIT_PUBLIC_KEY":   "public_i+f7GYBD7M6QSFxLVWLCUGnHht8=",
		"IMAGEKIT_URL_ENDPOINT": "https://ik.imagekit.io/onlyflick",
	}

	for key, value := range testEnvVars {
		os.Setenv(key, value)
	}

	utils.SetSecretKeyForTesting(testEnvVars["SECRET_KEY"])
}

// resetTestEnvironment nettoie l'environnement de test
func resetTestEnvironment() {
	testEnvVars := []string{
		"SECRET_KEY",
		"DATABASE_URL",
		"IMAGEKIT_PRIVATE_KEY",
		"IMAGEKIT_PUBLIC_KEY",
		"IMAGEKIT_URL_ENDPOINT",
	}

	for _, envVar := range testEnvVars {
		os.Unsetenv(envVar)
	}

	utils.SetSecretKeyForTesting("")
}

func cleanupTestData(t *testing.T, email string) {
	if database.DB == nil {
		return
	}

	_, err := database.DB.Exec("DELETE FROM users WHERE email = $1", email)
	if err != nil {
		t.Logf("Erreur lors du nettoyage des données de test: %v", err)
	}
}
