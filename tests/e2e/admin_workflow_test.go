package e2e

import (
	"net/http"
	"net/http/httptest"
	"onlyflick/api"
	"onlyflick/internal/utils"
	"testing"

	"github.com/stretchr/testify/assert"
)

func TestAdminWorkflow(t *testing.T) {
	setupE2EEnv(t)
	defer utils.SetSecretKeyForTesting("")

	router := api.SetupRoutes()

	// Test d'accès admin sans token
	req := httptest.NewRequest(http.MethodGet, "/admin/dashboard", nil)
	rr := httptest.NewRecorder()
	router.ServeHTTP(rr, req)

	assert.Equal(t, http.StatusUnauthorized, rr.Code)

	// Test liste des demandes de créateurs sans auth
	req = httptest.NewRequest(http.MethodGet, "/admin/creator-requests", nil)
	rr = httptest.NewRecorder()
	router.ServeHTTP(rr, req)

	assert.Equal(t, http.StatusUnauthorized, rr.Code)

	t.Log("Tests d'accès admin réussis - accès refusé sans authentification")
}
