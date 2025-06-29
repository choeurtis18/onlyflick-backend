package middleware

import (
	"net/http"
	"onlyflick/internal/logger"
	"onlyflick/internal/utils"
	"time"

	"github.com/go-chi/chi/v5/middleware"
	"go.uber.org/zap"
)

// LoggingMiddleware est un middleware qui enregistre les requêtes HTTP au format JSON
func LoggingMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		start := time.Now()

		// Extraire le requestID ou en générer un nouveau
		requestID := middleware.GetReqID(r.Context())
		if requestID == "" {
			requestID = utils.GenerateUUID()
		}

		// Extraire l'ID utilisateur si présent dans le contexte
		var userID int64
		if id, ok := r.Context().Value(ContextUserIDKey).(int64); ok {
			userID = id
		}

		// Créer un writer qui capture le code de statut
		ww := middleware.NewWrapResponseWriter(w, r.ProtoMajor)

		// Exécuter le prochain handler dans la chaîne
		next.ServeHTTP(ww, r)

		// Calculer la durée de la requête
		duration := time.Since(start)

		// Logger les informations de la requête en JSON
		logger.Log.Info("HTTP Request",
			zap.String("method", r.Method),
			zap.String("path", r.URL.Path),
			zap.String("query", r.URL.RawQuery),
			zap.String("ip", r.RemoteAddr),
			zap.String("user_agent", r.UserAgent()),
			zap.Int("status", ww.Status()),
			zap.Int("bytes", ww.BytesWritten()),
			zap.Duration("duration", duration),
			zap.String("request_id", requestID),
			zap.Int64("user_id", userID),
		)
	})
}
