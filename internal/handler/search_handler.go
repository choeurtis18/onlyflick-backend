// internal/handler/search_handler.go

package handler

import (
	"encoding/json"
	"log"
	"net/http"
	"strconv"
	"strings"
	"fmt"
	"time"

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

	// ✅ Parser les paramètres de découverte avec tags simplifiés
	discoveryRequest, err := parseDiscoveryParams(r, userID)
	if err != nil {
		log.Printf("[GetDiscoveryPostsHandler][ERREUR] Parsing paramètres : %v", err)
		response.RespondWithError(w, http.StatusBadRequest, err.Error())
		return
	}

	log.Printf("[GetDiscoveryPostsHandler] 📊 Requête: tags=%v, sort=%s, limit=%d, offset=%d", 
		discoveryRequest.Tags, discoveryRequest.SortBy, discoveryRequest.Limit, discoveryRequest.Offset)

	// ✅ Utiliser la méthode recommandée avec tags string
	posts, total, err := repository.ListPostsRecommendedForUserWithTags(
		userID,
		discoveryRequest.Tags, // Maintenant []string
		discoveryRequest.Limit,
		discoveryRequest.Offset,
	)
	if err != nil {
		log.Printf("[GetDiscoveryPostsHandler][ERREUR] Erreur posts recommandés : %v", err)
		response.RespondWithError(w, http.StatusInternalServerError, "Discovery failed")
		return
	}

	// Construire la réponse
	result := buildDiscoveryResponse(posts, total, *discoveryRequest)

	log.Printf("[GetDiscoveryPostsHandler] ✅ %d posts découverte trouvés (total: %d)", len(posts), total)
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

	// ✅ Retourner des stats avec les vrais tags
	result := map[string]interface{}{
		"recent_searches":    []string{},
		"popular_tags":       []string{"art", "musique", "tech", "cuisine", "mode"},
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

// ===== FONCTIONS UTILITAIRES CORRIGÉES =====

// parsePostSearchParams parse les paramètres de recherche de posts
func parsePostSearchParams(r *http.Request, userID int64) (*domain.SearchRequest, error) {
	query := strings.TrimSpace(r.URL.Query().Get("q"))
	
	// ✅ Parser les tags directement en string
	tags := parseTagsFromSlice(r.URL.Query()["tags"])

	// Parser le type de tri
	sortBy := parseSortParam(r.URL.Query().Get("sort_by"))
	
	// Pagination
	limit, offset := parsePaginationParams(r)

	return &domain.SearchRequest{
		Query:      query,
		UserID:     userID,
		Tags:       tags, // ✅ Maintenant []string
		SortBy:     sortBy,
		Limit:      limit,
		Offset:     offset,
		SearchType: "posts",
	}, nil
}

// ✅ parseDiscoveryParams parse les paramètres de découverte avec tags simplifiés
func parseDiscoveryParams(r *http.Request, userID int64) (*domain.DiscoveryRequest, error) {
	// Parser les tags directement en string
	tags := parseTagsFromSlice(r.URL.Query()["tags"])

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
		Tags:   tags, // ✅ Maintenant []string
		SortBy: sortBy,
		Limit:  limit,
		Offset: offset,
	}, nil
}

// ✅ parseTagsFromSlice convertit les tags frontend en liste de strings backend
func parseTagsFromSlice(tagsParam []string) []string {
	var tags []string

	for _, raw := range tagsParam {
		splitTags := strings.Split(raw, ",")
		for _, tagStr := range splitTags {
			tagStr = strings.TrimSpace(strings.ToLower(tagStr))
			if tagStr == "" || tagStr == "tous" {
				continue
			}

			// ✅ Mapper et valider avec les vrais tags backend
			backendTag := mapToBackendTag(tagStr)
			if backendTag != "" {
				tags = append(tags, backendTag)
			} else {
				log.Printf("[parseTagsFromSlice] Tag invalide ignoré: %s", tagStr)
			}
		}
	}

	return tags
}

// ✅ mapToBackendTag convertit un tag frontend vers le tag backend correspondant
func mapToBackendTag(frontendTag string) string {
	// Tags backend valides (ceux qui existent réellement)
	mapping := map[string]string{
		// Tags directs
		"wellness":    "wellness",
		"beaute":      "beaute",
		"art":         "art",
		"musique":     "musique",
		"cuisine":     "cuisine",
		"football":    "football",
		"basket":      "basket",
		"mode":        "mode",
		"cinema":      "cinema",
		"actualites":  "actualites",
		"mangas":      "mangas",
		"memes":       "memes",
		"tech":        "tech",
		
		// Aliases pour compatibilité
		"beauté":      "beaute",
		"cinéma":      "cinema",
		"actualités":  "actualites",
		"mêmes":       "memes",
		"technology":  "tech",
		"technologie": "tech",
		"music":       "musique",
		"cooking":     "cuisine",
		"fashion":     "mode",
		"movies":      "cinema",
		"news":        "actualites",
	}
	
	return mapping[strings.ToLower(frontendTag)]
}

// ✅ isValidBackendTag vérifie si un tag est valide côté backend
func isValidBackendTag(tag string) bool {
	validTags := map[string]bool{
		"wellness":    true,
		"beaute":      true,
		"art":         true,
		"musique":     true,
		"cuisine":     true,
		"football":    true,
		"basket":      true,
		"mode":        true,
		"cinema":      true,
		"actualites":  true,
		"mangas":      true,
		"memes":       true,
		"tech":        true,
	}
	
	return validTags[strings.ToLower(tag)]
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

// ===== CONSTRUCTION DES RÉPONSES =====

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

// ✅ buildDiscoveryResponse construit la réponse de découverte
func buildDiscoveryResponse(posts []interface{}, total int, discoveryRequest domain.DiscoveryRequest) map[string]interface{} {
	return map[string]interface{}{
		"posts":       posts,
		"total":       total,
		"has_more":    total > discoveryRequest.Offset+len(posts),
		"limit":       discoveryRequest.Limit,
		"offset":      discoveryRequest.Offset,
		"tags":        discoveryRequest.Tags,
		"sort_by":     discoveryRequest.SortBy,
		"search_type": "discovery",
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

// ===== GESTION DES TAGS =====

// GetAvailableTagsHandler retourne la liste des tags disponibles
func GetAvailableTagsHandler(w http.ResponseWriter, r *http.Request) {
	log.Println("[GetAvailableTagsHandler] 🏷️ Récupération des tags disponibles")

	// ✅ Récupérer les vrais tags du backend
	tags := getAllAvailableBackendTags()
	
	// Construire la réponse avec les noms d'affichage
	var tagResponse []map[string]interface{}
	
	// Ajouter "Tous" en premier
	tagResponse = append(tagResponse, map[string]interface{}{
		"key":         "tous",
		"displayName": "Tous",
		"emoji":       "🏷️",
	})

	// Ajouter tous les autres tags
	for _, tag := range tags {
		tagResponse = append(tagResponse, map[string]interface{}{
			"key":         tag,
			"displayName": getTagDisplayName(tag),
			"emoji":       getTagEmoji(tag),
		})
	}

	result := map[string]interface{}{
		"tags":       tagResponse,
		"total":      len(tagResponse),
		"categories": len(tags), // Nombre de catégories sans "Tous"
	}

	log.Printf("[GetAvailableTagsHandler] ✅ %d tags retournés", len(tagResponse))
	response.RespondWithJSON(w, http.StatusOK, result)
}

// ✅ getAllAvailableBackendTags retourne tous les tags disponibles dans le backend
func getAllAvailableBackendTags() []string {
	return []string{
		"wellness",
		"beaute",
		"art",
		"musique",
		"cuisine",
		"football",
		"basket",
		"mode",
		"cinema",
		"actualites",
		"mangas",
		"memes",
		"tech",
	}
}

// ✅ getTagDisplayName retourne le nom d'affichage d'un tag
func getTagDisplayName(tag string) string {
	displayNames := map[string]string{
		"wellness":    "Wellness",
		"beaute":      "Beauté",
		"art":         "Art",
		"musique":     "Musique",
		"cuisine":     "Cuisine",
		"football":    "Football",
		"basket":      "Basketball",
		"mode":        "Mode",
		"cinema":      "Cinéma",
		"actualites":  "Actualités",
		"mangas":      "Mangas",
		"memes":       "Memes",
		"tech":        "Tech",
	}
	
	if displayName, exists := displayNames[tag]; exists {
		return displayName
	}
	return strings.Title(tag)
}

// ✅ getTagEmoji retourne l'emoji d'un tag
func getTagEmoji(tag string) string {
	emojis := map[string]string{
		"wellness":    "🧘",
		"beaute":      "💄",
		"art":         "🎨",
		"musique":     "🎵",
		"cuisine":     "🍳",
		"football":    "⚽",
		"basket":      "🏀",
		"mode":        "👗",
		"cinema":      "🎬",
		"actualites":  "📰",
		"mangas":      "📚",
		"memes":       "😂",
		"tech":        "💻",
	}
	
	if emoji, exists := emojis[tag]; exists {
		return emoji
	}
	return "🏷️"
}

// GetTagsStatsHandler retourne les statistiques des tags
func GetTagsStatsHandler(w http.ResponseWriter, r *http.Request) {
	log.Println("[GetTagsStatsHandler] 📊 Récupération des statistiques de tags")

	// Récupérer les statistiques depuis le repository
	tagStats, err := repository.GetTagsStatistics()
	if err != nil {
		log.Printf("[GetTagsStatsHandler] Erreur lors de la récupération des stats : %v", err)
		response.RespondWithError(w, http.StatusInternalServerError, "Impossible de récupérer les statistiques des tags")
		return
	}

	// ✅ Utiliser les vrais tags backend
	allTags := getAllAvailableBackendTags()
	
	// Construire la réponse avec les statistiques
	var statsResponse []map[string]interface{}
	
	// Ajouter "Tous" avec le total de tous les posts publics
	totalPosts, err := repository.GetTotalPublicPosts()
	if err != nil {
		log.Printf("[GetTagsStatsHandler] Erreur récupération total posts : %v", err)
		totalPosts = 0
	}
	
	statsResponse = append(statsResponse, map[string]interface{}{
		"key":         "tous",
		"displayName": "Tous",
		"emoji":       "🏷️",
		"count":       totalPosts,
	})

	// Ajouter les stats pour chaque tag existant
	for _, tag := range allTags {
		count := tagStats[tag] // 0 si le tag n'existe pas dans la map
		
		statsResponse = append(statsResponse, map[string]interface{}{
			"key":         tag,
			"displayName": getTagDisplayName(tag),
			"emoji":       getTagEmoji(tag),
			"count":       count,
		})
	}

	result := map[string]interface{}{
		"tags":        statsResponse,
		"total":       len(statsResponse),
		"last_update": time.Now().Format(time.RFC3339),
	}

	log.Printf("[GetTagsStatsHandler] ✅ Statistiques retournées pour %d tags", len(statsResponse))
	response.RespondWithJSON(w, http.StatusOK, result)
}

// ✅ trackSearchInteractions enregistre les interactions de recherche en arrière-plan
func trackSearchInteractions(userID int64, query string, tags []string) {
	// Enregistrer l'interaction de recherche
	if query != "" {
		if err := repository.TrackInteraction(userID, domain.InteractionSearch, "search", 0, query); err != nil {
			log.Printf("[trackSearchInteractions] Erreur tracking search: %v", err)
		}
	}

	// Enregistrer les clics sur tags
	for _, tag := range tags {
		if err := repository.TrackInteraction(userID, domain.InteractionTagClick, "tag", 0, tag); err != nil {
			log.Printf("[trackSearchInteractions] Erreur tracking tag click: %v", err)
		}
	}
}