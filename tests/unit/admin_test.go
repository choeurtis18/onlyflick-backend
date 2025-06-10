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
	req := httptest.NewRequest(http.MethodGet, "/admin/dashboard", nil)
	rr := httptest.NewRecorder()

	handler.AdminDashboard(rr, req)

	assert.Equal(t, http.StatusOK, rr.Code)
	assert.Contains(t, rr.Body.String(), "Bienvenue")
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
