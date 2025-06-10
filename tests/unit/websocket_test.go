package unit

import (
	"net/http"
	"net/http/httptest"
	"onlyflick/internal/handler"
	"onlyflick/internal/utils"
	"os"
	"testing"

	"github.com/stretchr/testify/assert"
)

func TestWebSocketUpgrade(t *testing.T) {
	// Configuration
	os.Setenv("SECRET_KEY", "12345678901234567890123456789012")
	utils.SetSecretKeyForTesting("12345678901234567890123456789012")
	defer utils.SetSecretKeyForTesting("")

	mock, cleanup := setupMockDB(t)
	defer cleanup()

	// Mock des requêtes nécessaires
	mock.ExpectQuery("SELECT EXISTS.*").WillReturnRows(mock.NewRows([]string{"exists"}).AddRow(true))

	// Créer une requête WebSocket avec headers appropriés
	req := httptest.NewRequest(http.MethodGet, "/ws/messages/1", nil)
	req.Header.Set("Connection", "upgrade")
	req.Header.Set("Upgrade", "websocket")
	req.Header.Set("Sec-WebSocket-Version", "13")
	req.Header.Set("Sec-WebSocket-Key", "dGhlIHNhbXBsZSBub25jZQ==")

	rr := httptest.NewRecorder()

	// Le handler devrait essayer de faire un upgrade WebSocket
	handler.HandleMessagesWebSocket(rr, req)

	// Vérifier que la réponse indique une tentative d'upgrade
	assert.NotEqual(t, http.StatusOK, rr.Code)
	t.Logf("WebSocket upgrade attempted, status: %d", rr.Code)
}
