package middleware

import (
	"context"
	"fmt"
	"log"
	"net/http"
	"strings"

	"onlyflick/internal/service"
	"onlyflick/pkg/response"

	"github.com/golang-jwt/jwt"
)

// =====================
// Constantes de contexte
// =====================
type contextKey string

const (
	ContextUserIDKey   contextKey = "userID"
	ContextUserRoleKey contextKey = "userRole"
)

// =====================
// Middleware JWT (utilisateur connecté ou invité)
// =====================

// JWTMiddleware permet de capturer les utilisateurs connectés ou anonymes (guest).
// Si aucun token n'est fourni ou si le token est invalide, l'utilisateur est considéré comme "guest".
func JWTMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		authHeader := r.Header.Get("Authorization")
		if authHeader == "" {
			log.Println("[JWTMiddleware] Aucun header Authorization trouvé, utilisateur guest")
			ctx := context.WithValue(r.Context(), ContextUserRoleKey, "guest")
			next.ServeHTTP(w, r.WithContext(ctx))
			return
		}

		tokenString := strings.TrimPrefix(authHeader, "Bearer ")
		if tokenString == authHeader {
			log.Println("[JWTMiddleware] Format du token invalide, utilisateur guest")
			ctx := context.WithValue(r.Context(), ContextUserRoleKey, "guest")
			next.ServeHTTP(w, r.WithContext(ctx))
			return
		}

		token, err := service.ValidateJWT(tokenString)
		if err != nil || !token.Valid {
			log.Printf("[JWTMiddleware] Token invalide ou expiré: %v, utilisateur guest\n", err)
			ctx := context.WithValue(r.Context(), ContextUserRoleKey, "guest")
			next.ServeHTTP(w, r.WithContext(ctx))
			return
		}

		claims, ok := token.Claims.(jwt.MapClaims)
		if !ok {
			log.Println("[JWTMiddleware] Claims du token invalides, utilisateur guest")
			ctx := context.WithValue(r.Context(), ContextUserRoleKey, "guest")
			next.ServeHTTP(w, r.WithContext(ctx))
			return
		}

		userID, _ := claims["sub"].(float64)
		userRole, _ := claims["role"].(string)

		log.Printf("[JWTMiddleware] Utilisateur authentifié: ID=%d, Role=%s\n", int64(userID), userRole)
		ctx := context.WithValue(r.Context(), ContextUserIDKey, int64(userID))
		ctx = context.WithValue(ctx, ContextUserRoleKey, userRole)
		next.ServeHTTP(w, r.WithContext(ctx))
	})
}

// =====================
// Middleware JWT avec vérification de rôle
// =====================

// JWTMiddlewareWithRole exige un JWT valide et vérifie les rôles autorisés.
// Si le token est absent, invalide ou si le rôle n'est pas autorisé, une erreur est retournée.
func JWTMiddlewareWithRole(allowedRoles ...string) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			authHeader := r.Header.Get("Authorization")
			if authHeader == "" {
				log.Println("[JWTMiddlewareWithRole] Header Authorization manquant")
				response.RespondWithError(w, http.StatusUnauthorized, "Missing Authorization header")
				return
			}

			tokenString := strings.TrimPrefix(authHeader, "Bearer ")
			if tokenString == authHeader {
				log.Println("[JWTMiddlewareWithRole] Format du token invalide")
				response.RespondWithError(w, http.StatusUnauthorized, "Invalid token format")
				return
			}

			token, err := service.ValidateJWT(tokenString)
			if err != nil || !token.Valid {
				log.Printf("[JWTMiddlewareWithRole] Token invalide ou expiré: %v\n", err)
				response.RespondWithError(w, http.StatusUnauthorized, "Invalid or expired token")
				return
			}

			claims, ok := token.Claims.(jwt.MapClaims)
			if !ok {
				log.Println("[JWTMiddlewareWithRole] Claims du token invalides")
				response.RespondWithError(w, http.StatusUnauthorized, "Invalid token claims")
				return
			}

			userID, ok := claims["sub"].(float64)
			if !ok {
				log.Println("[JWTMiddlewareWithRole] ID utilisateur invalide dans le token")
				response.RespondWithError(w, http.StatusUnauthorized, "Invalid user ID in token")
				return
			}

			userRole, ok := claims["role"].(string)
			if !ok {
				log.Println("[JWTMiddlewareWithRole] Rôle invalide dans le token")
				response.RespondWithError(w, http.StatusUnauthorized, "Invalid role in token")
				return
			}

			// Vérifie le rôle si des rôles sont spécifiés
			if len(allowedRoles) > 0 {
				authorized := false
				for _, role := range allowedRoles {
					if userRole == role {
						authorized = true
						break
					}
				}
				if !authorized {
					log.Printf("[JWTMiddlewareWithRole] Accès refusé pour le rôle: %s\n", userRole)
					response.RespondWithError(w, http.StatusForbidden, fmt.Sprintf("Access denied for role: %s", userRole))
					return
				}
			}

			log.Printf("[JWTMiddlewareWithRole] Accès autorisé: ID=%d, Role=%s\n", int64(userID), userRole)
			ctx := context.WithValue(r.Context(), ContextUserIDKey, int64(userID))
			ctx = context.WithValue(ctx, ContextUserRoleKey, userRole)
			next.ServeHTTP(w, r.WithContext(ctx))
		})
	}
}
