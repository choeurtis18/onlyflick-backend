// internal/middleware/websocket_middleware.go
package middleware

import (
	"context"
	"log"
	"net/http"
	"strings"

	"onlyflick/internal/service"
	"onlyflick/pkg/response"

	"github.com/golang-jwt/jwt"
)

// WebSocketJWTMiddleware middleware spécialement conçu pour les WebSockets.
// Il accepte l'authentification soit par header Authorization soit par query parameter 'token'.
// Ceci résout les limitations des navigateurs web qui ne permettent pas toujours 
// d'envoyer des headers personnalisés avec les WebSockets.
func WebSocketJWTMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		var tokenString string

		// Première tentative : lire le token depuis l'header Authorization
		authHeader := r.Header.Get("Authorization")
		if authHeader != "" {
			tokenString = strings.TrimPrefix(authHeader, "Bearer ")
			if tokenString != authHeader {
				log.Println("[WebSocketJWTMiddleware] Token trouvé dans l'header Authorization")
			} else {
				tokenString = "" // Format invalide
			}
		}

		// Deuxième tentative : lire le token depuis les query parameters
		if tokenString == "" {
			tokenFromQuery := r.URL.Query().Get("token")
			if tokenFromQuery != "" {
				tokenString = tokenFromQuery
				log.Println("[WebSocketJWTMiddleware] Token trouvé dans les query parameters")
			}
		}

		// Si aucun token n'est trouvé
		if tokenString == "" {
			log.Println("[WebSocketJWTMiddleware] Aucun token d'authentification trouvé")
			response.RespondWithError(w, http.StatusUnauthorized, "Token d'authentification requis")
			return
		}

		// Valider le token JWT
		token, err := service.ValidateJWT(tokenString)
		if err != nil || !token.Valid {
			log.Printf("[WebSocketJWTMiddleware] Token invalide ou expiré: %v\n", err)
			response.RespondWithError(w, http.StatusUnauthorized, "Token invalide ou expiré")
			return
		}

		// Extraire les claims du token
		claims, ok := token.Claims.(jwt.MapClaims)
		if !ok {
			log.Println("[WebSocketJWTMiddleware] Claims du token invalides")
			response.RespondWithError(w, http.StatusUnauthorized, "Claims du token invalides")
			return
		}

		// Extraire l'ID utilisateur
		userID, ok := claims["sub"].(float64)
		if !ok {
			log.Println("[WebSocketJWTMiddleware] ID utilisateur invalide dans le token")
			response.RespondWithError(w, http.StatusUnauthorized, "ID utilisateur invalide")
			return
		}

		// Extraire le rôle utilisateur
		userRole, ok := claims["role"].(string)
		if !ok {
			log.Println("[WebSocketJWTMiddleware] Rôle invalide dans le token")
			response.RespondWithError(w, http.StatusUnauthorized, "Rôle invalide")
			return
		}

		log.Printf("[WebSocketJWTMiddleware] WebSocket authentifié: ID=%d, Role=%s\n", int64(userID), userRole)

		// Ajouter les informations d'authentification au contexte
		ctx := context.WithValue(r.Context(), ContextUserIDKey, int64(userID))
		ctx = context.WithValue(ctx, ContextUserRoleKey, userRole)
		
		// Continuer avec le handler suivant
		next.ServeHTTP(w, r.WithContext(ctx))
	})
}