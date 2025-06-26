package handler

import (
	"encoding/json"
	"log"
	"net/http"
	"onlyflick/internal/domain"
	"onlyflick/internal/middleware"
	"onlyflick/internal/repository"
	"onlyflick/pkg/response"
	"strconv"
	"strings"

	"github.com/go-chi/chi/v5"
)

// ===== RECHERCHE D'UTILISATEURS =====

// SearchUsersHandler recherche des utilisateurs par nom/username
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

	log.Printf("[SearchUsersHandler] Recherche réussie : %d utilisateurs trouvés pour '%s'", len(users), query)
	response.RespondWithJSON(w, http.StatusOK, result)
}

// ===== RECHERCHE DE POSTS =====

// SearchPostsHandler recherche des posts avec filtres et tri
func SearchPostsHandler(w http.ResponseWriter, r *http.Request) {
	log.Println("[SearchPostsHandler] Début de la recherche de posts")

	userID, ok := r.Context().Value(middleware.ContextUserIDKey).(int64)
	if !ok {
		log.Println("[SearchPostsHandler][ERREUR] ID utilisateur manquant")
		response.RespondWithError(w, http.StatusUnauthorized, "User ID required")
		return
	}

	// Construction de la requête de recherche
	searchRequest := domain.SearchRequest{
		UserID:     userID,
		Query:      r.URL.Query().Get("q"),
		SearchType: "posts",
		Limit:      20,
		Offset:     0,
		SortBy:     domain.SortRecent,
	}

	// Paramètres optionnels
	if limitStr := r.URL.Query().Get("limit"); limitStr != "" {
		if l, err := strconv.Atoi(limitStr); err == nil && l > 0 && l <= 100 {
			searchRequest.Limit = l
		}
	}

	if offsetStr := r.URL.Query().Get("offset"); offsetStr != "" {
		if o, err := strconv.Atoi(offsetStr); err == nil && o >= 0 {
			searchRequest.Offset = o
		}
	}

	// Parsing des tags
	if tagsStr := r.URL.Query().Get("tags"); tagsStr != "" {
		tagsList := strings.Split(tagsStr, ",")
		for _, tagStr := range tagsList {
			tag := strings.TrimSpace(tagStr)
			if tag != "" {
				searchRequest.Tags = append(searchRequest.Tags, domain.TagCategory(tag))
			}
		}
	}

	// Type de tri
	if sortStr := r.URL.Query().Get("sort"); sortStr != "" {
		switch sortStr {
		case "relevance":
			searchRequest.SortBy = domain.SortRelevance
		case "popular_24h":
			searchRequest.SortBy = domain.SortPopular24h
		case "popular_week":
			searchRequest.SortBy = domain.SortPopularWeek
		case "popular_month":
			searchRequest.SortBy = domain.SortPopularMonth
		case "recent":
			searchRequest.SortBy = domain.SortRecent
		}
	}

	// Enregistrer l'interaction de recherche
	if searchRequest.Query != "" {
		interaction := domain.NewUserInteraction(
			userID,
			domain.InteractionSearch,
			"search",
			0,
			searchRequest.Query,
			1.0,
		)
		repository.CreateUserInteraction(interaction)
	}

	// Effectuer la recherche
	posts, total, err := repository.SearchPosts(searchRequest)
	if err != nil {
		log.Printf("[SearchPostsHandler][ERREUR] Erreur recherche posts : %v", err)
		response.RespondWithError(w, http.StatusInternalServerError, "Search failed")
		return
	}

	// Construire la réponse
	result := domain.SearchResult{
		Posts:   posts,
		Total:   total,
		HasMore: total > searchRequest.Offset+len(posts),
	}

	log.Printf("[SearchPostsHandler] Recherche réussie : %d posts trouvés", len(posts))
	response.RespondWithJSON(w, http.StatusOK, result)
}

// ===== FEED DE DÉCOUVERTE =====

// DiscoveryFeedHandler retourne le feed de découverte personnalisé
func DiscoveryFeedHandler(w http.ResponseWriter, r *http.Request) {
	log.Println("[DiscoveryFeedHandler] Génération du feed de découverte")

	userID, ok := r.Context().Value(middleware.ContextUserIDKey).(int64)
	if !ok {
		log.Println("[DiscoveryFeedHandler][ERREUR] ID utilisateur manquant")
		response.RespondWithError(w, http.StatusUnauthorized, "User ID required")
		return
	}

	// Construction de la requête de découverte
	discoveryRequest := domain.DiscoveryRequest{
		UserID: userID,
		Limit:  20,
		Offset: 0,
		SortBy: domain.SortRelevance,
	}

	// Paramètres optionnels
	if limitStr := r.URL.Query().Get("limit"); limitStr != "" {
		if l, err := strconv.Atoi(limitStr); err == nil && l > 0 && l <= 100 {
			discoveryRequest.Limit = l
		}
	}

	if offsetStr := r.URL.Query().Get("offset"); offsetStr != "" {
		if o, err := strconv.Atoi(offsetStr); err == nil && o >= 0 {
			discoveryRequest.Offset = o
		}
	}

	// Filtres par tags
	if tagsStr := r.URL.Query().Get("tags"); tagsStr != "" {
		tagsList := strings.Split(tagsStr, ",")
		for _, tagStr := range tagsList {
			tag := strings.TrimSpace(tagStr)
			if tag != "" {
				discoveryRequest.Tags = append(discoveryRequest.Tags, domain.TagCategory(tag))
			}
		}
	}

	// Type de tri
	if sortStr := r.URL.Query().Get("sort"); sortStr != "" {
		switch sortStr {
		case "relevance":
			discoveryRequest.SortBy = domain.SortRelevance
		case "popular_24h":
			discoveryRequest.SortBy = domain.SortPopular24h
		case "popular_week":
			discoveryRequest.SortBy = domain.SortPopularWeek
		case "popular_month":
			discoveryRequest.SortBy = domain.SortPopularMonth
		case "recent":
			discoveryRequest.SortBy = domain.SortRecent
		}
	}

	// Récupérer les posts de découverte
	posts, err := repository.GetDiscoveryPosts(discoveryRequest)
	if err != nil {
		log.Printf("[DiscoveryFeedHandler][ERREUR] Erreur génération feed découverte : %v", err)
		response.RespondWithError(w, http.StatusInternalServerError, "Discovery feed generation failed")
		return
	}

	// Construire la réponse
	result := map[string]interface{}{
		"posts":    posts,
		"has_more": len(posts) == discoveryRequest.Limit,
		"limit":    discoveryRequest.Limit,
		"offset":   discoveryRequest.Offset,
	}

	log.Printf("[DiscoveryFeedHandler] Feed découverte généré : %d posts", len(posts))
	response.RespondWithJSON(w, http.StatusOK, result)
}

// ===== GESTION DES TAGS =====

// AddPostTagsHandler ajoute des tags à un post
func AddPostTagsHandler(w http.ResponseWriter, r *http.Request) {
	log.Println("[AddPostTagsHandler] Ajout de tags à un post")

	userID, ok := r.Context().Value(middleware.ContextUserIDKey).(int64)
	if !ok {
		response.RespondWithError(w, http.StatusUnauthorized, "User ID required")
		return
	}

	postIDStr := chi.URLParam(r, "postId")
	if postIDStr == "" {
		response.RespondWithError(w, http.StatusBadRequest, "Post ID required")
		return
	}

	postID, err := strconv.ParseInt(postIDStr, 10, 64)
	if err != nil {
		response.RespondWithError(w, http.StatusBadRequest, "Invalid post ID")
		return
	}

	// Vérifier que l'utilisateur est propriétaire du post
	post, err := repository.GetPostByID(postID)
	if err != nil {
		response.RespondWithError(w, http.StatusNotFound, "Post not found")
		return
	}

	if post.UserID != userID {
		response.RespondWithError(w, http.StatusForbidden, "Not authorized to modify this post")
		return
	}

	// Decoder la requête
	var request struct {
		Tags []domain.TagCategory `json:"tags"`
	}

	if err := json.NewDecoder(r.Body).Decode(&request); err != nil {
		log.Printf("[AddPostTagsHandler][ERREUR] Erreur décodage JSON : %v", err)
		response.RespondWithError(w, http.StatusBadRequest, "Invalid JSON")
		return
	}

	// Supprimer les anciens tags
	repository.DeletePostTags(postID)

	// Ajouter les nouveaux tags
	for _, tagCategory := range request.Tags {
		tag := domain.NewPostTag(postID, tagCategory)
		if err := repository.CreatePostTag(tag); err != nil {
			log.Printf("[AddPostTagsHandler][ERREUR] Erreur ajout tag %s : %v", tagCategory, err)
			continue
		}

		// Enregistrer l'interaction tag pour l'utilisateur
		interaction := domain.NewUserInteraction(
			userID,
			domain.InteractionTagClick,
			"tag",
			postID,
			string(tagCategory),
			0.5,
		)
		repository.CreateUserInteraction(interaction)
	}

	// Mettre à jour les métriques du post
	repository.UpdatePostMetrics(postID)

	log.Printf("[AddPostTagsHandler] Tags ajoutés au post %d : %d tags", postID, len(request.Tags))
	response.RespondWithJSON(w, http.StatusOK, map[string]string{"message": "Tags added successfully"})
}

// GetPostTagsHandler récupère les tags d'un post
func GetPostTagsHandler(w http.ResponseWriter, r *http.Request) {
	postIDStr := chi.URLParam(r, "postId")
	if postIDStr == "" {
		response.RespondWithError(w, http.StatusBadRequest, "Post ID required")
		return
	}

	postID, err := strconv.ParseInt(postIDStr, 10, 64)
	if err != nil {
		response.RespondWithError(w, http.StatusBadRequest, "Invalid post ID")
		return
	}

	tags, err := repository.GetPostTags(postID)
	if err != nil {
		log.Printf("[GetPostTagsHandler][ERREUR] Erreur récupération tags : %v", err)
		response.RespondWithError(w, http.StatusInternalServerError, "Failed to get tags")
		return
	}

	// Formater les tags avec leurs détails
	tagsWithDetails := make([]map[string]interface{}, len(tags))
	for i, tag := range tags {
		tagsWithDetails[i] = map[string]interface{}{
			"category":     tag,
			"display_name": tag.GetTagDisplayName(),
			"emoji":        tag.GetTagEmoji(),
		}
	}

	response.RespondWithJSON(w, http.StatusOK, map[string]interface{}{
		"tags": tagsWithDetails,
	})
}

// ===== TRENDING TAGS =====

// GetTrendingTagsHandler retourne les tags en tendance
func GetTrendingTagsHandler(w http.ResponseWriter, r *http.Request) {
	log.Println("[GetTrendingTagsHandler] Récupération des tags trending")

	period := r.URL.Query().Get("period")
	if period == "" {
		period = "week"
	}

	limitStr := r.URL.Query().Get("limit")
	limit := 10
	if limitStr != "" {
		if l, err := strconv.Atoi(limitStr); err == nil && l > 0 && l <= 50 {
			limit = l
		}
	}

	trendingTags, err := repository.GetTrendingTags(period, limit)
	if err != nil {
		log.Printf("[GetTrendingTagsHandler][ERREUR] Erreur récupération trending tags : %v", err)
		response.RespondWithError(w, http.StatusInternalServerError, "Failed to get trending tags")
		return
	}

	// Enrichir avec les détails des tags
	enrichedTags := make([]map[string]interface{}, len(trendingTags))
	for i, tag := range trendingTags {
		enrichedTags[i] = map[string]interface{}{
			"category":       tag.Category,
			"display_name":   tag.Category.GetTagDisplayName(),
			"emoji":          tag.Category.GetTagEmoji(),
			"posts_count":    tag.PostsCount,
			"growth_rate":    tag.GrowthRate,
			"trending_score": tag.TrendingScore,
			"period":         tag.Period,
		}
	}

	result := map[string]interface{}{
		"trending_tags": enrichedTags,
		"period":        period,
		"total":         len(enrichedTags),
	}

	log.Printf("[GetTrendingTagsHandler] %d tags trending récupérés pour période %s", len(trendingTags), period)
	response.RespondWithJSON(w, http.StatusOK, result)
}

// ===== TRACKING DES INTERACTIONS =====

// TrackInteractionHandler enregistre une interaction utilisateur
func TrackInteractionHandler(w http.ResponseWriter, r *http.Request) {
	userID, ok := r.Context().Value(middleware.ContextUserIDKey).(int64)
	if !ok {
		response.RespondWithError(w, http.StatusUnauthorized, "User ID required")
		return
	}

	var request struct {
		InteractionType domain.InteractionType `json:"interaction_type"`
		ContentType     string                 `json:"content_type"`
		ContentID       int64                  `json:"content_id"`
		ContentMeta     string                 `json:"content_meta,omitempty"`
	}

	if err := json.NewDecoder(r.Body).Decode(&request); err != nil {
		response.RespondWithError(w, http.StatusBadRequest, "Invalid JSON")
		return
	}

	// Déterminer le score selon le type d'interaction
	var score float64
	switch request.InteractionType {
	case domain.InteractionView:
		score = 0.1
	case domain.InteractionLike:
		score = 1.0
	case domain.InteractionComment:
		score = 2.0
	case domain.InteractionShare:
		score = 3.0
	case domain.InteractionProfileView:
		score = 0.5
	case domain.InteractionSearch:
		score = 1.0
	case domain.InteractionTagClick:
		score = 0.5
	default:
		score = 1.0
	}

	// Créer l'interaction
	interaction := domain.NewUserInteraction(
		userID,
		request.InteractionType,
		request.ContentType,
		request.ContentID,
		request.ContentMeta,
		score,
	)

	if err := repository.CreateUserInteraction(interaction); err != nil {
		log.Printf("[TrackInteractionHandler][ERREUR] Erreur création interaction : %v", err)
		response.RespondWithError(w, http.StatusInternalServerError, "Failed to track interaction")
		return
	}

	// Mettre à jour les métriques du post si c'est une interaction sur un post
	if request.ContentType == "post" {
		repository.UpdatePostMetrics(request.ContentID)
	}

	response.RespondWithJSON(w, http.StatusOK, map[string]string{"message": "Interaction tracked"})
}

// ===== PRÉFÉRENCES UTILISATEUR =====

// GetUserPreferencesHandler retourne les préférences calculées de l'utilisateur
func GetUserPreferencesHandler(w http.ResponseWriter, r *http.Request) {
	userID, ok := r.Context().Value(middleware.ContextUserIDKey).(int64)
	if !ok {
		response.RespondWithError(w, http.StatusUnauthorized, "User ID required")
		return
	}

	preferences, err := repository.GetUserPreferences(userID)
	if err != nil {
		log.Printf("[GetUserPreferencesHandler][ERREUR] Erreur récupération préférences : %v", err)
		response.RespondWithError(w, http.StatusInternalServerError, "Failed to get preferences")
		return
	}

	// Enrichir les tags préférés avec leurs détails
	enrichedTags := make(map[string]interface{})
	for tag, score := range preferences.PreferredTags {
		enrichedTags[string(tag)] = map[string]interface{}{
			"score":        score,
			"display_name": tag.GetTagDisplayName(),
			"emoji":        tag.GetTagEmoji(),
		}
	}

	result := map[string]interface{}{
		"user_id":           preferences.UserID,
		"preferred_tags":    enrichedTags,
		"preferred_creators": preferences.PreferredCreators,
		"last_updated":      preferences.LastUpdated,
	}

	log.Printf("[GetUserPreferencesHandler] Préférences récupérées pour user %d", userID)
	response.RespondWithJSON(w, http.StatusOK, result)
}

// ===== STATISTIQUES DE RECHERCHE =====

// GetSearchStatsHandler retourne des statistiques sur les recherches
func GetSearchStatsHandler(w http.ResponseWriter, r *http.Request) {
	userID, ok := r.Context().Value(middleware.ContextUserIDKey).(int64)
	if !ok {
		response.RespondWithError(w, http.StatusUnauthorized, "User ID required")
		return
	}

	// Récupérer les interactions de recherche récentes
	interactions, err := repository.GetUserInteractions(userID, 50)
	if err != nil {
		log.Printf("[GetSearchStatsHandler][ERREUR] Erreur récupération interactions : %v", err)
		response.RespondWithError(w, http.StatusInternalServerError, "Failed to get search stats")
		return
	}

	// Analyser les recherches récentes
	searchTerms := make(map[string]int)
	tagInteractions := make(map[string]int)

	for _, interaction := range interactions {
		if interaction.InteractionType == domain.InteractionSearch {
			searchTerms[interaction.ContentMeta]++
		} else if interaction.InteractionType == domain.InteractionTagClick {
			tagInteractions[interaction.ContentMeta]++
		}
	}

	result := map[string]interface{}{
		"recent_searches":    searchTerms,
		"popular_tags":       tagInteractions,
		"total_interactions": len(interactions),
	}

	response.RespondWithJSON(w, http.StatusOK, result)
}

// ===== SUGGESTIONS DE RECHERCHE =====

// GetSearchSuggestionsHandler retourne des suggestions de recherche
func GetSearchSuggestionsHandler(w http.ResponseWriter, r *http.Request) {
	query := r.URL.Query().Get("q")
	if len(query) < 2 {
		response.RespondWithJSON(w, http.StatusOK, map[string]interface{}{
			"suggestions": []string{},
		})
		return
	}

	userID, _ := r.Context().Value(middleware.ContextUserIDKey).(int64)

	// Suggestions basiques : utilisateurs populaires qui matchent
	users, _, err := repository.SearchUsers(query, userID, 5, 0)
	if err != nil {
		log.Printf("[GetSearchSuggestionsHandler][ERREUR] Erreur suggestions users : %v", err)
	}

	suggestions := make([]map[string]interface{}, 0)

	// Ajouter les suggestions d'utilisateurs
	for _, user := range users {
		suggestions = append(suggestions, map[string]interface{}{
			"type":        "user",
			"text":        user.Username,
			"display":     user.FirstName + " " + user.LastName + " (@" + user.Username + ")",
			"avatar_url":  user.AvatarURL,
			"user_id":     user.ID,
		})
	}

	// Ajouter les suggestions de tags qui matchent
	allTags := []domain.TagCategory{
		domain.TagArt, domain.TagMusic, domain.TagSport, domain.TagCinema,
		domain.TagTech, domain.TagFashion, domain.TagFood, domain.TagTravel,
		domain.TagGaming, domain.TagLifestyle,
	}

	queryLower := strings.ToLower(query)
	for _, tag := range allTags {
		tagName := strings.ToLower(tag.GetTagDisplayName())
		if strings.Contains(tagName, queryLower) || strings.Contains(string(tag), queryLower) {
			suggestions = append(suggestions, map[string]interface{}{
				"type":         "tag",
				"text":         string(tag),
				"display":      tag.GetTagEmoji() + " " + tag.GetTagDisplayName(),
				"category":     tag,
			})
		}
	}

	result := map[string]interface{}{
		"suggestions": suggestions,
		"query":       query,
	}

	response.RespondWithJSON(w, http.StatusOK, result)
}