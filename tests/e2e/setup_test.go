package e2e

import (
	"onlyflick/internal/database"
	"testing"
)

func cleanupTestData(t *testing.T, email string) {
	if database.DB == nil {
		return
	}

	// Supprimer l'utilisateur de test s'il existe
	_, err := database.DB.Exec("DELETE FROM users WHERE email = $1", email)
	if err != nil {
		t.Logf("Erreur lors du nettoyage des données de test: %v", err)
	}
}

func TestMain(m *testing.M) {
	// Cette fonction s'exécute avant tous les tests E2E
	// Vous pouvez ajouter ici une configuration globale si nécessaire
	m.Run()
}
