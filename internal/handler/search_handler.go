// internal/handler/search_handler.go

package handler

import (
	"log"
	"net/http"
	"onlyflick/internal/middleware"
	"onlyflick/internal/repository"
	"onlyflick/pkg/response"
	"strconv"
	"strings"
)

// ===== RECHERCHE D'UTILISATEURS =====

// SearchUsersHandler recherche des utilisateurs par username uniquement
func SearchUsersHandler(w http.ResponseWriter, r *http.Request) {
	log.Println("[SearchUsersHandler] Début de la recherche d'utilisateurs")

	// Récupérer l'ID utilisateur depuis le contexte JWT
	userID, ok := r.Context().Value(middleware.ContextUserIDKey).(int64)
	if !ok {
		log.Println("[SearchUsersHandler][ERREUR] ID utilisateur manquant")
		response.RespondWithError(w, http.StatusUnauthorized, "User ID required")
		return
	}

	// Récupérer les paramètres de recherche
	query := r.URL.Query().Get("q")
	if query == "" {
		response.RespondWithError(w, http.StatusBadRequest, "Search query required")
		return
	}

	// Validation longueur minimum
	if len(strings.TrimSpace(query)) < 2 {
		response.RespondWithError(w, http.StatusBadRequest, "Query must be at least 2 characters")
		return
	}

	limitStr := r.URL.Query().Get("limit")
	limit := 20 // valeur par défaut
	if limitStr != "" {
		if l, err := strconv.Atoi(limitStr); err == nil && l > 0 && l <= 100 {
			limit = l
		}
	}

	offsetStr := r.URL.Query().Get("offset")
	offset := 0
	if offsetStr != "" {
		if o, err := strconv.Atoi(offsetStr); err == nil && o >= 0 {
			offset = o
		}
	}

	log.Printf("[SearchUsersHandler] Recherche: query='%s', limit=%d, offset=%d", query, limit, offset)

	// Effectuer la recherche
	users, total, err := repository.SearchUsers(query, userID, limit, offset)
	if err != nil {
		log.Printf("[SearchUsersHandler][ERREUR] Erreur recherche utilisateurs : %v", err)
		response.RespondWithError(w, http.StatusInternalServerError, "Search failed")
		return
	}

	// Construire la réponse
	result := map[string]interface{}{
		"users":    users,
		"total":    total,
		"has_more": total > offset+len(users),
		"limit":    limit,
		"offset":   offset,
	}

	log.Printf("[SearchUsersHandler] ✅ Recherche réussie : %d utilisateurs trouvés pour '%s' (total: %d)", 
		len(users), query, total)
	response.RespondWithJSON(w, http.StatusOK, result)
}

// ===== TRACKING DES INTERACTIONS (SIMPLIFIÉ) =====

// TrackInteractionHandler enregistre une interaction utilisateur (version simplifiée)
func TrackInteractionHandler(w http.ResponseWriter, r *http.Request) {
	log.Println("[TrackInteractionHandler] Enregistrement d'une interaction (simplifié)")

	userID, ok := r.Context().Value(middleware.ContextUserIDKey).(int64)
	if !ok {
		log.Println("[TrackInteractionHandler][ERREUR] ID utilisateur manquant")
		response.RespondWithError(w, http.StatusUnauthorized, "User ID required")
		return
	}

	// Pour l'instant, on accepte la requête mais on ne fait que logger
	// (évite les erreurs côté client en attendant l'implémentation complète)
	
	log.Printf("[TrackInteractionHandler] ✅ Interaction reçue pour user %d (tracking désactivé temporairement)", userID)

	response.RespondWithJSON(w, http.StatusOK, map[string]string{
		"message": "Interaction received",
		"status":  "disabled", // Indique que le tracking est temporairement désactivé
	})
}

// ===== SUGGESTIONS DE RECHERCHE (BASIQUE) =====

// GetSearchSuggestionsHandler retourne des suggestions de recherche simplifiées
func GetSearchSuggestionsHandler(w http.ResponseWriter, r *http.Request) {
	log.Println("[GetSearchSuggestionsHandler] Génération de suggestions")

	query := r.URL.Query().Get("q")
	if len(query) < 2 {
		response.RespondWithJSON(w, http.StatusOK, map[string]interface{}{
			"suggestions": []string{},
			"query":       query,
		})
		return
	}

	userID, ok := r.Context().Value(middleware.ContextUserIDKey).(int64)
	if !ok {
		log.Println("[GetSearchSuggestionsHandler][ERREUR] ID utilisateur manquant")
		response.RespondWithError(w, http.StatusUnauthorized, "User ID required")
		return
	}

	// Rechercher des utilisateurs qui matchent (maximum 5 pour les suggestions)
	users, _, err := repository.SearchUsers(query, userID, 5, 0)
	if err != nil {
		log.Printf("[GetSearchSuggestionsHandler][ERREUR] Erreur suggestions users : %v", err)
		// Ne pas faire échouer la requête, juste retourner une liste vide
		response.RespondWithJSON(w, http.StatusOK, map[string]interface{}{
			"suggestions": []string{},
			"query":       query,
		})
		return
	}

	suggestions := make([]map[string]interface{}, 0)

	// Ajouter les suggestions d'utilisateurs
	for _, user := range users {
		suggestion := map[string]interface{}{
			"type":     "user",
			"text":     user.Username,
			"user_id":  user.ID,
		}

		// Ajouter le nom d'affichage si disponible
		if user.FullName != "" {
			suggestion["display"] = user.FullName + " (@" + user.Username + ")"
		} else {
			suggestion["display"] = "@" + user.Username
		}

		// Ajouter l'avatar si disponible
		if user.AvatarURL != "" {
			suggestion["avatar_url"] = user.AvatarURL
		}

		suggestions = append(suggestions, suggestion)
	}

	result := map[string]interface{}{
		"suggestions": suggestions,
		"query":       query,
		"total":       len(suggestions),
	}

	log.Printf("[GetSearchSuggestionsHandler] ✅ %d suggestions générées pour '%s'", len(suggestions), query)
	response.RespondWithJSON(w, http.StatusOK, result)
}

// ===== STATISTIQUES DE RECHERCHE (BASIQUE) =====

// GetSearchStatsHandler retourne des statistiques simplifiées (version placeholder)
func GetSearchStatsHandler(w http.ResponseWriter, r *http.Request) {
	log.Println("[GetSearchStatsHandler] Récupération des statistiques de recherche")

	userID, ok := r.Context().Value(middleware.ContextUserIDKey).(int64)
	if !ok {
		log.Println("[GetSearchStatsHandler][ERREUR] ID utilisateur manquant")
		response.RespondWithError(w, http.StatusUnauthorized, "User ID required")
		return
	}

	// Pour l'instant, retourner des stats vides (évite les erreurs)
	result := map[string]interface{}{
		"recent_searches":    map[string]int{},
		"total_searches":     0,
		"total_interactions": 0,
		"status":            "disabled", // Indique que les stats sont temporairement désactivées
	}

	log.Printf("[GetSearchStatsHandler] ✅ Statistiques placeholder pour user %d", userID)
	response.RespondWithJSON(w, http.StatusOK, result)
}