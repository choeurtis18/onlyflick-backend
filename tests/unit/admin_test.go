package unit

import (
	"net/http"
	"net/http/httptest"
	"onlyflick/internal/handler"
	"onlyflick/internal/utils"
	"os"
	"testing"
	"time"

	"github.com/DATA-DOG/go-sqlmock"
	"github.com/stretchr/testify/assert"
)

func TestAdminDashboard(t *testing.T) {
	// Configurer le mock DB avec une correspondance précise des colonnes
	mock, cleanup := setupMockDB(t)
	defer cleanup()

	// Mock pour les statistiques globales - veiller à correspondre exactement au nombre de colonnes
	rows := mock.NewRows([]string{"total_users", "total_posts", "total_subscriptions"}).
		AddRow(100, 250, 50)

	// Expression régulière pour matcher la requête SQL
	mock.ExpectQuery("SELECT COUNT\\(\\*\\) as total_users").WillReturnRows(rows)

	// Créer la requête et le recorder
	req := httptest.NewRequest(http.MethodGet, "/admin/dashboard", nil)
	rr := httptest.NewRecorder()

	t.Log("[AdminDashboard] Accès au tableau de bord admin")
	handler.AdminDashboard(rr, req)

	// Vérification des attentes SQL
	if err := mock.ExpectationsWereMet(); err != nil {
		t.Errorf("Attentes SQL non satisfaites: %s", err)
	}

	// Vérification de la réponse
	assert.Equal(t, http.StatusOK, rr.Code)
	assert.Contains(t, rr.Body.String(), "stats")
}

func TestListCreatorRequests(t *testing.T) {
	// Configuration
	os.Setenv("SECRET_KEY", "12345678901234567890123456789012")
	utils.SetSecretKeyForTesting("12345678901234567890123456789012")
	defer utils.SetSecretKeyForTesting("")

	mock, cleanup := setupMockDB(t)
	defer cleanup()

	// Mock pour récupérer les demandes de créateurs avec regex
	mock.ExpectQuery("SELECT.*FROM creator_requests").
		WillReturnRows(sqlmock.NewRows([]string{"id", "user_id", "status", "created_at", "updated_at"}).
			AddRow(1, 123, "pending", time.Now(), time.Now()).
			AddRow(2, 456, "approved", time.Now(), time.Now()))

	req := httptest.NewRequest(http.MethodGet, "/admin/creator-requests", nil)
	rr := httptest.NewRecorder()

	handler.ListCreatorRequests(rr, req)

	assert.Equal(t, http.StatusOK, rr.Code)
	assert.Contains(t, rr.Body.String(), "pending")
	assert.Contains(t, rr.Body.String(), "approved")
}
