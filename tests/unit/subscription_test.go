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
	"github.com/go-chi/chi/v5"
	"github.com/stretchr/testify/assert"
)

func TestSubscribeHandler(t *testing.T) {
	// Configuration
	os.Setenv("SECRET_KEY", "12345678901234567890123456789012")
	utils.SetSecretKeyForTesting("12345678901234567890123456789012")
	defer utils.SetSecretKeyForTesting("")

	mock, cleanup := setupMockDB(t)
	defer cleanup()

	userID := int64(123)
	creatorID := int64(456)

	// Vérifier si l'abonnement existe déjà
	mock.ExpectQuery("SELECT id FROM subscriptions WHERE").
		WithArgs(userID, creatorID).
		WillReturnRows(sqlmock.NewRows([]string{"id"}))

	// Mock pour l'abonnement - utiliser ExpectExec plutôt que ExpectQuery pour INSERT
	mock.ExpectExec("INSERT INTO subscriptions").
		WithArgs(userID, creatorID, sqlmock.AnyArg(), sqlmock.AnyArg(), true).
		WillReturnResult(sqlmock.NewResult(1, 1))

	// Créer un routeur Chi pour tester les paramètres d'URL
	r := chi.NewRouter()
	r.Post("/subscribe/{creator_id}", handler.Subscribe)

	req := httptest.NewRequest(http.MethodPost, "/subscribe/456", nil)
	ctx := context.WithValue(req.Context(), middleware.ContextUserIDKey, userID)
	req = req.WithContext(ctx)

	rr := httptest.NewRecorder()
	r.ServeHTTP(rr, req)

	// Vérifier que les attentes SQL ont été satisfaites
	if err := mock.ExpectationsWereMet(); err != nil {
		t.Errorf("Attentes SQL non satisfaites: %s", err)
	}

	assert.Equal(t, http.StatusOK, rr.Code)
	assert.Contains(t, rr.Body.String(), "Abonnement réussi")
}
