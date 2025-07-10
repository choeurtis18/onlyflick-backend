package e2e

import (
	"testing"

	"onlyflick/internal/database"
)

// cleanupTestData supprime l’utilisateur pour l’email donné
func cleanupTestData(t *testing.T, email string) {
	if database.DB == nil {
		t.Fatalf("Database connection is not initialized")
	}
	if _, err := database.DB.Exec("DELETE FROM users WHERE email = $1", email); err != nil {
		t.Logf("Failed to cleanup test data for %s: %v", email, err)
	}
}

// cleanupAllTestData supprime tous les utilisateurs e2e_*
func cleanupAllTestData(t *testing.T) {
	if database.DB == nil {
		t.Fatalf("Database connection is not initialized")
	}
	if _, err := database.DB.Exec("DELETE FROM users WHERE email LIKE 'e2e_%@example.com'"); err != nil {
		t.Logf("Failed to cleanup all E2E test data: %v", err)
	}
}
