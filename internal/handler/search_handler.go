// internal/handler/search_handler.go

package handler

import (
	"encoding/json"
	"log"
	"net/http"
	"strconv"
	"strings"
	"fmt"

	"onlyflick/internal/domain"
	"onlyflick/internal/middleware"
	"onlyflick/internal/repository"
	"onlyflick/pkg/response"
)

// ===== RECHERCHE DE POSTS AVEC TAGS =====

// SearchPostsHandler recherche des posts par texte et/ou tags
func SearchPostsHandler(w http.ResponseWriter, r *http.Request) {
	log.Println("[SearchPostsHandler] 🔍 Début de la recherche de posts")

	// Récupérer l'ID utilisateur depuis le contexte JWT
	userID, ok := r.Context().Value(middleware.ContextUserIDKey).(int64)
	if !ok {
		log.Println("[SearchPostsHandler][ERREUR] ID utilisateur manquant")
		response.RespondWithError(w, http.StatusUnauthorized, "User ID required")
		return
	}

	// Parser les paramètres de recherche
	searchRequest, err := parsePostSearchParams(r, userID)
	if err != nil {
		log.Printf("[SearchPostsHandler][ERREUR] Parsing paramètres : %v", err)
		response.RespondWithError(w, http.StatusBadRequest, err.Error())
		return
	}

	log.Printf("[SearchPostsHandler] 📊 Requête: query='%s', tags=%v, sort=%s, limit=%d, offset=%d", 
		searchRequest.Query, searchRequest.Tags, searchRequest.SortBy, searchRequest.Limit, searchRequest.Offset)

	// Effectuer la recherche via le repository
	posts, total, err := repository.SearchPosts(*searchRequest)
	if err != nil {
		log.Printf("[SearchPostsHandler][ERREUR] Erreur recherche posts : %v", err)
		response.RespondWithError(w, http.StatusInternalServerError, "Search failed")
		return
	}

	// Tracking des interactions en arrière-plan
	go trackSearchInteractions(userID, searchRequest.Query, searchRequest.Tags)

	// Construire la réponse
	result := buildPostSearchResponse(posts, total, *searchRequest)

	log.Printf("[SearchPostsHandler] ✅ Recherche réussie : %d posts trouvés (total: %d)", len(posts), total)
	response.RespondWithJSON(w, http.StatusOK, result)
}

// ===== DÉCOUVERTE DE POSTS =====

// GetDiscoveryPostsHandler retourne des posts pour la découverte (basé sur les intérêts utilisateur)
func GetDiscoveryPostsHandler(w http.ResponseWriter, r *http.Request) {
	log.Println("[GetDiscoveryPostsHandler] 🎯 Récupération posts découverte")

	userID, ok := r.Context().Value(middleware.ContextUserIDKey).(int64)
	if !ok {
		log.Println("[GetDiscoveryPostsHandler][ERREUR] ID utilisateur manquant")
		response.RespondWithError(w, http.StatusUnauthorized, "User ID required")
		return
	}

	// Parser les paramètres de découverte
	discoveryRequest, err := parseDiscoveryParams(r, userID)
	if err != nil {
		log.Printf("[GetDiscoveryPostsHandler][ERREUR] Parsing paramètres : %v", err)
		response.RespondWithError(w, http.StatusBadRequest, err.Error())
		return
	}

	log.Printf("[GetDiscoveryPostsHandler] 📊 Requête: tags=%v, sort=%s, limit=%d, offset=%d", 
		discoveryRequest.Tags, discoveryRequest.SortBy, discoveryRequest.Limit, discoveryRequest.Offset)

	// Effectuer la recherche discovery via repository
	posts, err := repository.GetDiscoveryPosts(*discoveryRequest)
	if err != nil {
		log.Printf("[GetDiscoveryPostsHandler][ERREUR] : %v", err)
		response.RespondWithError(w, http.StatusInternalServerError, "Discovery failed")
		return
	}

	// Construire la réponse
	result := map[string]interface{}{
		"posts":      posts,
		"total":      len(posts),
		"has_more":   len(posts) == discoveryRequest.Limit, // Estimation simple
		"limit":      discoveryRequest.Limit,
		"offset":     discoveryRequest.Offset,
		"tags":       discoveryRequest.Tags,
		"sort_by":    discoveryRequest.SortBy,
		"type":       "discovery",
	}

	log.Printf("[GetDiscoveryPostsHandler] ✅ %d posts découverte trouvés", len(posts))
	response.RespondWithJSON(w, http.StatusOK, result)
}

// ===== RECHERCHE D'UTILISATEURS =====

// SearchUsersHandler recherche des utilisateurs par username uniquement
func SearchUsersHandler(w http.ResponseWriter, r *http.Request) {
	log.Println("[SearchUsersHandler] 👥 Début de la recherche d'utilisateurs")

	userID, ok := r.Context().Value(middleware.ContextUserIDKey).(int64)
	if !ok {
		log.Println("[SearchUsersHandler][ERREUR] ID utilisateur manquant")
		response.RespondWithError(w, http.StatusUnauthorized, "User ID required")
		return
	}

	// Validation de la requête
	query := strings.TrimSpace(r.URL.Query().Get("q"))
	if query == "" {
		response.RespondWithError(w, http.StatusBadRequest, "Search query required")
		return
	}

	if len(query) < 2 {
		response.RespondWithError(w, http.StatusBadRequest, "Query must be at least 2 characters")
		return
	}

	// Pagination
	limit, offset := parsePaginationParams(r)

	log.Printf("[SearchUsersHandler] 📊 Recherche: query='%s', limit=%d, offset=%d", query, limit, offset)

	// Effectuer la recherche
	users, total, err := repository.SearchUsers(query, userID, limit, offset)
	if err != nil {
		log.Printf("[SearchUsersHandler][ERREUR] Erreur recherche utilisateurs : %v", err)
		response.RespondWithError(w, http.StatusInternalServerError, "Search failed")
		return
	}

	// Construire la réponse
	result := map[string]interface{}{
		"users":      users,
		"total":      total,
		"has_more":   total > offset+len(users),
		"limit":      limit,
		"offset":     offset,
		"query":      query,
	}

	log.Printf("[SearchUsersHandler] ✅ Recherche réussie : %d utilisateurs trouvés pour '%s' (total: %d)", 
		len(users), query, total)
	response.RespondWithJSON(w, http.StatusOK, result)
}

// ===== SUGGESTIONS DE RECHERCHE =====

// GetSearchSuggestionsHandler génère des suggestions de recherche
func GetSearchSuggestionsHandler(w http.ResponseWriter, r *http.Request) {
	log.Println("[GetSearchSuggestionsHandler] 💡 Génération des suggestions")

	query := strings.TrimSpace(r.URL.Query().Get("q"))
	if query == "" {
		response.RespondWithJSON(w, http.StatusOK, map[string]interface{}{
			"suggestions": []string{},
			"query":       "",
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
		response.RespondWithJSON(w, http.StatusOK, map[string]interface{}{
			"suggestions": []string{},
			"query":       query,
		})
		return
	}

	suggestions := buildUserSuggestions(users)

	result := map[string]interface{}{
		"suggestions": suggestions,
		"query":       query,
		"total":       len(suggestions),
	}

	log.Printf("[GetSearchSuggestionsHandler] ✅ %d suggestions générées pour '%s'", len(suggestions), query)
	response.RespondWithJSON(w, http.StatusOK, result)
}

// ===== STATISTIQUES DE RECHERCHE =====

// GetSearchStatsHandler retourne des statistiques simplifiées
func GetSearchStatsHandler(w http.ResponseWriter, r *http.Request) {
	log.Println("[GetSearchStatsHandler] 📈 Récupération des statistiques de recherche")

	userID, ok := r.Context().Value(middleware.ContextUserIDKey).(int64)
	if !ok {
		log.Println("[GetSearchStatsHandler][ERREUR] ID utilisateur manquant")
		response.RespondWithError(w, http.StatusUnauthorized, "User ID required")
		return
	}

	// Pour l'instant, retourner des stats placeholder
	result := map[string]interface{}{
		"recent_searches":    []string{},
		"popular_tags":       []string{"art", "music", "tech", "travel"},
		"total_searches":     0,
		"total_interactions": 0,
		"status":            "placeholder",
	}

	log.Printf("[GetSearchStatsHandler] ✅ Statistiques placeholder pour user %d", userID)
	response.RespondWithJSON(w, http.StatusOK, result)
}

// ===== TRACKING DES INTERACTIONS =====

// TrackInteractionHandler enregistre une interaction utilisateur
func TrackInteractionHandler(w http.ResponseWriter, r *http.Request) {
	log.Println("[TrackInteractionHandler] 📊 Enregistrement d'une interaction")

	userID, ok := r.Context().Value(middleware.ContextUserIDKey).(int64)
	if !ok {
		response.RespondWithError(w, http.StatusUnauthorized, "User ID required")
		return
	}

	// Parser la requête
	var interaction struct {
		InteractionType string `json:"interaction_type"`
		ContentType     string `json:"content_type"`
		ContentID       int64  `json:"content_id"`
		ContentMeta     string `json:"content_meta,omitempty"`
	}

	if err := json.NewDecoder(r.Body).Decode(&interaction); err != nil {
		response.RespondWithError(w, http.StatusBadRequest, "Invalid JSON")
		return
	}

	// Valider et convertir le type d'interaction
	interactionType, err := parseInteractionType(interaction.InteractionType)
	if err != nil {
		response.RespondWithError(w, http.StatusBadRequest, err.Error())
		return
	}

	// Enregistrer l'interaction
	err = repository.TrackInteraction(userID, interactionType, interaction.ContentType, interaction.ContentID, interaction.ContentMeta)
	if err != nil {
		log.Printf("[TrackInteractionHandler][ERREUR] : %v", err)
		response.RespondWithError(w, http.StatusInternalServerError, "Failed to track interaction")
		return
	}

	log.Printf("[TrackInteractionHandler] ✅ Interaction enregistrée: user=%d, type=%s", userID, interaction.InteractionType)
	response.RespondWithJSON(w, http.StatusOK, map[string]string{"status": "tracked"})
}

// ===== FONCTIONS UTILITAIRES =====

// parsePostSearchParams parse les paramètres de recherche de posts
func parsePostSearchParams(r *http.Request, userID int64) (*domain.SearchRequest, error) {
	query := strings.TrimSpace(r.URL.Query().Get("q"))
	
	// Parser les tags
	tags, err := parseTagsParamFromSlice(r.URL.Query()["tags"])
	if err != nil {
		return nil, err
	}

	// Parser le type de tri
	sortBy := parseSortParam(r.URL.Query().Get("sort_by"))
	
	// Pagination
	limit, offset := parsePaginationParams(r)

	return &domain.SearchRequest{
		Query:      query,
		UserID:     userID,
		Tags:       tags,
		SortBy:     sortBy,
		Limit:      limit,
		Offset:     offset,
		SearchType: "posts",
	}, nil
}

// parseDiscoveryParams parse les paramètres de découverte
func parseDiscoveryParams(r *http.Request, userID int64) (*domain.DiscoveryRequest, error) {
	// Parser les tags
	tags, err := parseTagsParamFromSlice(r.URL.Query()["tags"])
	if err != nil {
		return nil, err
	}

	// Parser le type de tri (par défaut: pertinence pour la découverte)
	sortBy := domain.SortRelevance
	sortParam := r.URL.Query().Get("sort_by")
	if sortParam != "" {
		sortBy = parseSortParam(sortParam)
	}
	
	// Pagination
	limit, offset := parsePaginationParams(r)

	return &domain.DiscoveryRequest{
		UserID: userID,
		Tags:   tags,
		SortBy: sortBy,
		Limit:  limit,
		Offset: offset,
	}, nil
}

// parseTagsParam convertit les tags frontend en TagCategory backend
func parseTagsParam(tagsParam string) ([]domain.TagCategory, error) {
	var tags []domain.TagCategory
	
	if tagsParam == "" {
		return tags, nil
	}

	tagStrings := strings.Split(tagsParam, ",")
	for _, tagStr := range tagStrings {
		tagStr = strings.TrimSpace(tagStr)
		if tagStr == "" || strings.ToLower(tagStr) == "tous" {
			continue
		}

		// Mapping Frontend -> Backend
		var tagCategory domain.TagCategory
		switch strings.ToLower(tagStr) {
		case "yoga":
			tagCategory = domain.TagYoga
		case "wellness":
			tagCategory = domain.TagWellness
		case "beaute":
			tagCategory = domain.TagBeaute
		case "diy":
			tagCategory = domain.TagDiy
		case "art":
			tagCategory = domain.TagArt
		case "musique":
			tagCategory = domain.TagMusique
		case "cuisine":
			tagCategory = domain.TagCuisine
		case "musculation":
			tagCategory = domain.TagMusculation
		case "mode":
			tagCategory = domain.TagMode
		case "fitness":
			tagCategory = domain.TagFitness
		default:
			log.Printf("[parseTagsParamFromSlice] Tag invalide ignoré: %s", tagStr)
			continue
		}
		
		
		tags = append(tags, tagCategory)
	}

	return tags, nil
}

func parseTagsParamFromSlice(tagsParam []string) ([]domain.TagCategory, error) {
	var tags []domain.TagCategory

	for _, raw := range tagsParam {
		splitTags := strings.Split(raw, ",")
		for _, tagStr := range splitTags {
			tagStr = strings.TrimSpace(tagStr)
			if tagStr == "" || strings.ToLower(tagStr) == "tous" {
				continue
			}

			var tagCategory domain.TagCategory
			switch strings.ToLower(tagStr) {
			case "yoga":
				tagCategory = domain.TagYoga
			case "wellness":
				tagCategory = domain.TagWellness
			case "beaute":
				tagCategory = domain.TagBeaute
			case "diy":
				tagCategory = domain.TagDiy
			case "art":
				tagCategory = domain.TagArt
			case "musique":
				tagCategory = domain.TagMusique
			case "cuisine":
				tagCategory = domain.TagCuisine
			case "musculation":
				tagCategory = domain.TagMusculation
			case "mode":
				tagCategory = domain.TagMode
			case "fitness":
				tagCategory = domain.TagFitness
			default:
				log.Printf("[parseTagsParamFromSlice] Tag invalide ignoré: %s", tagStr)
				continue
			}
			
		

			tags = append(tags, tagCategory)
		}
	}

	return tags, nil
}


// parseSortParam convertit le paramètre de tri en SortType
func parseSortParam(sortParam string) domain.SortType {
	switch sortParam {
	case "relevance":
		return domain.SortRelevance
	case "popular_24h":
		return domain.SortPopular24h
	case "popular_week":
		return domain.SortPopularWeek
	case "popular_month":
		return domain.SortPopularMonth
	case "recent":
		return domain.SortRecent
	default:
		return domain.SortRecent // valeur par défaut
	}
}

// parsePaginationParams parse les paramètres de pagination
func parsePaginationParams(r *http.Request) (limit, offset int) {
	// Limit avec validation
	limit = 20 // valeur par défaut
	if limitParam := r.URL.Query().Get("limit"); limitParam != "" {
		if l, err := strconv.Atoi(limitParam); err == nil && l > 0 && l <= 100 {
			limit = l
		}
	}

	// Offset avec validation
	offset = 0 // valeur par défaut
	if offsetParam := r.URL.Query().Get("offset"); offsetParam != "" {
		if o, err := strconv.Atoi(offsetParam); err == nil && o >= 0 {
			offset = o
		}
	}

	return limit, offset
}

// parseInteractionType convertit et valide le type d'interaction
func parseInteractionType(interactionTypeStr string) (domain.InteractionType, error) {
	switch interactionTypeStr {
	case "view":
		return domain.InteractionView, nil
	case "like":
		return domain.InteractionLike, nil
	case "comment":
		return domain.InteractionComment, nil
	case "share":
		return domain.InteractionShare, nil
	case "profile_view":
		return domain.InteractionProfileView, nil
	case "search":
		return domain.InteractionSearch, nil
	case "tag_click":
		return domain.InteractionTagClick, nil
	default:
		return "", fmt.Errorf("invalid interaction type: %s", interactionTypeStr)
	}
}

// buildPostSearchResponse construit la réponse de recherche de posts
func buildPostSearchResponse(posts []interface{}, total int, searchRequest domain.SearchRequest) map[string]interface{} {
	return map[string]interface{}{
		"posts":       posts,
		"total":       total,
		"has_more":    total > searchRequest.Offset+len(posts),
		"limit":       searchRequest.Limit,
		"offset":      searchRequest.Offset,
		"query":       searchRequest.Query,
		"tags":        searchRequest.Tags,
		"sort_by":     searchRequest.SortBy,
		"search_type": searchRequest.SearchType,
	}
}

// buildUserSuggestions construit les suggestions d'utilisateurs
func buildUserSuggestions(users []domain.UserSearchResult) []map[string]interface{} {
	suggestions := make([]map[string]interface{}, 0, len(users))

	for _, user := range users {
		suggestion := map[string]interface{}{
			"type":     "user",
			"text":     user.Username,
			"user_id":  user.ID,
			"display":  user.FullName,
			"avatar_url": user.AvatarURL,
		}

		if user.FullName == "" {
			suggestion["display"] = "@" + user.Username
		} else {
			suggestion["display"] = user.FullName + " (@" + user.Username + ")"
		}

		suggestions = append(suggestions, suggestion)
	}

	return suggestions
}


// trackSearchInteractions enregistre les interactions de recherche en arrière-plan
func trackSearchInteractions(userID int64, query string, tags []domain.TagCategory) {
	// Enregistrer l'interaction de recherche
	if query != "" {
		if err := repository.TrackInteraction(userID, domain.InteractionSearch, "search", 0, query); err != nil {
			log.Printf("[trackSearchInteractions] Erreur tracking search: %v", err)
		}
	}

	// Enregistrer les clics sur tags
	for _, tag := range tags {
		if err := repository.TrackInteraction(userID, domain.InteractionTagClick, "tag", 0, string(tag)); err != nil {
			log.Printf("[trackSearchInteractions] Erreur tracking tag click: %v", err)
		}
	}
}