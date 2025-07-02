package handler

import (
	"encoding/json"
	"log"
	"net/http"
	"onlyflick/internal/middleware"
	"onlyflick/internal/repository"
	"onlyflick/internal/utils"
	"onlyflick/pkg/response"
	"strconv"

	"github.com/go-chi/chi/v5"
)

// UserStats représente les statistiques d'un utilisateur
type UserStats struct {
	PostsCount     int `json:"posts_count"`
	FollowersCount int `json:"followers_count"`
	FollowingCount int `json:"following_count"`
}

// GetUserProfileHandler récupère le profil public d'un utilisateur avec statistiques
// Route: GET /users/{user_id}
func GetUserProfileHandler(w http.ResponseWriter, r *http.Request) {
	log.Println("[GetUserProfileHandler] Récupération du profil public d'un utilisateur")

	// Récupération de l'ID de l'utilisateur connecté (pour les logs et permissions)
	currentUserVal := r.Context().Value(middleware.ContextUserIDKey)
	currentUserID, ok := currentUserVal.(int64)
	if !ok {
		log.Println("[GetUserProfileHandler] Utilisateur non authentifié")
		response.RespondWithError(w, http.StatusUnauthorized, "Utilisateur non authentifié")
		return
	}

	// Récupération de l'ID du profil demandé depuis l'URL
	userIDStr := chi.URLParam(r, "user_id")
	targetUserID, err := strconv.ParseInt(userIDStr, 10, 64)
	if err != nil || targetUserID <= 0 {
		log.Printf("[GetUserProfileHandler] ID utilisateur invalide: %s, erreur: %v", userIDStr, err)
		response.RespondWithError(w, http.StatusBadRequest, "ID utilisateur invalide")
		return
	}

	log.Printf("[GetUserProfileHandler] Utilisateur %d demande le profil de %d", currentUserID, targetUserID)

	// Récupération des données utilisateur
	user, err := repository.GetUserByID(targetUserID)
	if err != nil || user == nil {
		log.Printf("[GetUserProfileHandler] Utilisateur %d non trouvé: %v", targetUserID, err)
		response.RespondWithError(w, http.StatusNotFound, "Utilisateur non trouvé")
		return
	}

	// Décryptage des champs chiffrés (sécurité supplémentaire)
	firstName, _ := utils.DecryptAES(user.FirstName)
	lastName, _ := utils.DecryptAES(user.LastName)
	// Note: email n'est pas décrypté car non retourné dans le profil public (sécurité)

	// ===== NOUVEAU : Récupération des statistiques utilisateur =====
	userStats, err := getUserStatistics(targetUserID)
	if err != nil {
		log.Printf("[GetUserProfileHandler] Erreur récupération statistiques pour %d: %v", targetUserID, err)
		// On continue avec des stats vides plutôt que de bloquer
		userStats = &UserStats{
			PostsCount:     0,
			FollowersCount: 0,
			FollowingCount: 0,
		}
	}

	// Vérifier l'état d'abonnement de l'utilisateur connecté à ce profil (si c'est un créateur)
	var isSubscribed bool
	var subscriptionStatus string
	
	if user.Role == "creator" && currentUserID != targetUserID {
		// Vérifier si l'utilisateur connecté est abonné à ce créateur
		subscription, err := repository.GetActiveSubscription(currentUserID, targetUserID)
		if err != nil {
			log.Printf("[GetUserProfileHandler] Erreur vérification abonnement: %v", err)
			// On continue sans bloquer pour l'erreur d'abonnement
		} else if subscription != nil {
			isSubscribed = subscription.Status
			if subscription.Status {
				subscriptionStatus = "active"
			} else {
				subscriptionStatus = "inactive"
			}
		} else {
			subscriptionStatus = "none"
		}
	}

	// Construire la réponse du profil public avec statistiques
	publicProfile := map[string]interface{}{
		"id":                  user.ID,
		"username":           user.Username,
		"first_name":         firstName,
		"last_name":          lastName,
		"full_name":          firstName + " " + lastName,
		"role":               user.Role,
		"avatar_url":         user.AvatarURL,
		"bio":                user.Bio,
		"created_at":         user.CreatedAt,
		"is_creator":         user.Role == "creator",
		"subscription_price": nil, // Sera ajouté si c'est un créateur
		// ===== NOUVEAU : Ajout des statistiques =====
		"stats": map[string]interface{}{
			"posts_count":     userStats.PostsCount,
			"followers_count": userStats.FollowersCount,
			"following_count": userStats.FollowingCount,
		},
	}

	// Informations spécifiques aux créateurs
	if user.Role == "creator" {
		publicProfile["subscription_price"] = "4.99"  // Prix fixe pour l'abonnement
		publicProfile["currency"] = "EUR"
		
		// Informations d'abonnement pour l'utilisateur connecté
		if currentUserID != targetUserID {
			publicProfile["viewer_subscription"] = map[string]interface{}{
				"is_subscribed": isSubscribed,
				"status":        subscriptionStatus,
			}
		}
	}

	// Ne pas retourner l'email dans le profil public (sécurité)
	// Le champ email est disponible seulement via ProfileHandler pour l'utilisateur lui-même

	log.Printf("[GetUserProfileHandler] Profil public récupéré pour utilisateur %d (%s %s) - Stats: %d posts, %d followers, %d following", 
		targetUserID, firstName, lastName, userStats.PostsCount, userStats.FollowersCount, userStats.FollowingCount)

	response.RespondWithJSON(w, http.StatusOK, publicProfile)
}

// ===== NOUVEAU : GetUserPostsHandler récupère les posts d'un utilisateur =====
// Route: GET /users/{user_id}/posts
func GetUserPostsHandler(w http.ResponseWriter, r *http.Request) {
	log.Println("[GetUserPostsHandler] Récupération des posts d'un utilisateur")

	// Récupération de l'ID de l'utilisateur connecté
	currentUserVal := r.Context().Value(middleware.ContextUserIDKey)
	currentUserID, ok := currentUserVal.(int64)
	if !ok {
		log.Println("[GetUserPostsHandler] Utilisateur non authentifié")
		response.RespondWithError(w, http.StatusUnauthorized, "Utilisateur non authentifié")
		return
	}

	// Récupération de l'ID du profil dont on veut les posts
	userIDStr := chi.URLParam(r, "user_id")
	targetUserID, err := strconv.ParseInt(userIDStr, 10, 64)
	if err != nil || targetUserID <= 0 {
		log.Printf("[GetUserPostsHandler] ID utilisateur invalide: %s, erreur: %v", userIDStr, err)
		response.RespondWithError(w, http.StatusBadRequest, "ID utilisateur invalide")
		return
	}

	// Paramètres de pagination
	page := 1
	limit := 20
	
	if pageStr := r.URL.Query().Get("page"); pageStr != "" {
		if p, err := strconv.Atoi(pageStr); err == nil && p > 0 {
			page = p
		}
	}
	
	if limitStr := r.URL.Query().Get("limit"); limitStr != "" {
		if l, err := strconv.Atoi(limitStr); err == nil && l > 0 && l <= 50 {
			limit = l
		}
	}

	log.Printf("[GetUserPostsHandler] Utilisateur %d demande les posts de %d (page=%d, limit=%d)", 
		currentUserID, targetUserID, page, limit)

	// Vérifier que l'utilisateur cible existe
	targetUser, err := repository.GetUserByID(targetUserID)
	if err != nil || targetUser == nil {
		log.Printf("[GetUserPostsHandler] Utilisateur %d non trouvé: %v", targetUserID, err)
		response.RespondWithError(w, http.StatusNotFound, "Utilisateur non trouvé")
		return
	}

	// Déterminer quel type de posts on peut voir
	postType := "public" // Par défaut, seuls les posts publics
	
	if currentUserID == targetUserID {
		// L'utilisateur regarde ses propres posts
		postType = "all"
	} else if targetUser.Role == "creator" {
		// Vérifier si l'utilisateur connecté est abonné à ce créateur
		subscription, err := repository.GetActiveSubscription(currentUserID, targetUserID)
		if err == nil && subscription != nil && subscription.Status {
			// L'utilisateur est abonné, il peut voir tous les posts
			postType = "all"
		}
		// Sinon, postType reste "public"
	}

	log.Printf("[GetUserPostsHandler] Type de posts visibles: %s", postType)

	// Récupérer les posts
	posts, err := repository.GetUserPosts(targetUserID, page, limit, postType)
	if err != nil {
		log.Printf("[GetUserPostsHandler] Erreur récupération posts: %v", err)
		response.RespondWithError(w, http.StatusInternalServerError, "Erreur récupération des posts")
		return
	}

	// Compter le total de posts visibles
	totalPosts, err := repository.GetUserPostsCountByType(targetUserID, postType)
	if err != nil {
		log.Printf("[GetUserPostsHandler] Erreur récupération nombre total posts: %v", err)
		totalPosts = 0
	}

	// Construire la réponse
	responseData := map[string]interface{}{
		"posts":      posts,
		"total":      totalPosts,
		"page":       page,
		"limit":      limit,
		"has_more":   len(posts) == limit,
		"post_type":  postType,
		"user_id":    targetUserID,
	}

	log.Printf("[GetUserPostsHandler] %d posts récupérés pour utilisateur %d (total: %d, type: %s)", 
		len(posts), targetUserID, totalPosts, postType)

	// Réponse avec format standard
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	finalResponse := map[string]interface{}{"data": responseData}
	if err := json.NewEncoder(w).Encode(finalResponse); err != nil {
		log.Printf("[GetUserPostsHandler] Erreur encoding JSON: %v", err)
	}
}

// getUserStatistics récupère les statistiques d'un utilisateur
func getUserStatistics(userID int64) (*UserStats, error) {
	log.Printf("[getUserStatistics] Récupération des statistiques pour utilisateur %d", userID)

	// Récupérer le nombre de posts de l'utilisateur
	postsCount, err := repository.GetUserPostsCount(userID)
	if err != nil {
		log.Printf("[getUserStatistics] Erreur récupération nombre de posts: %v", err)
		return nil, err
	}

	// Récupérer le nombre de followers (abonnés à cet utilisateur si c'est un créateur)
	followersCount, err := repository.GetUserFollowersCount(userID)
	if err != nil {
		log.Printf("[getUserStatistics] Erreur récupération nombre de followers: %v", err)
		return nil, err
	}

	// Récupérer le nombre de following (abonnements de cet utilisateur)
	followingCount, err := repository.GetUserFollowingCount(userID)
	if err != nil {
		log.Printf("[getUserStatistics] Erreur récupération nombre de following: %v", err)
		return nil, err
	}

	stats := &UserStats{
		PostsCount:     postsCount,
		FollowersCount: followersCount,
		FollowingCount: followingCount,
	}

	log.Printf("[getUserStatistics] Statistiques récupérées: %+v", stats)
	return stats, nil
}

// CheckSubscriptionStatusHandler vérifie l'état d'abonnement entre l'utilisateur connecté et un créateur
// Route: GET /subscriptions/{creator_id}/status
func CheckSubscriptionStatusHandler(w http.ResponseWriter, r *http.Request) {
	log.Println("[CheckSubscriptionStatusHandler] Vérification du statut d'abonnement")

	// Récupération de l'ID de l'utilisateur connecté
	userVal := r.Context().Value(middleware.ContextUserIDKey)
	subscriberID, ok := userVal.(int64)
	if !ok {
		log.Println("[CheckSubscriptionStatusHandler] Utilisateur non authentifié")
		response.RespondWithError(w, http.StatusUnauthorized, "Utilisateur non authentifié")
		return
	}

	// Récupération de l'ID du créateur depuis l'URL
	creatorIDStr := chi.URLParam(r, "creator_id")
	creatorID, err := strconv.ParseInt(creatorIDStr, 10, 64)
	if err != nil || creatorID <= 0 {
		log.Printf("[CheckSubscriptionStatusHandler] ID créateur invalide: %s, erreur: %v", creatorIDStr, err)
		response.RespondWithError(w, http.StatusBadRequest, "ID créateur invalide")
		return
	}

	// Empêcher de vérifier l'abonnement à soi-même
	if subscriberID == creatorID {
		log.Printf("[CheckSubscriptionStatusHandler] L'utilisateur %d tente de vérifier son abonnement à lui-même", subscriberID)
		response.RespondWithError(w, http.StatusBadRequest, "Impossible de vérifier l'abonnement à soi-même")
		return
	}

	log.Printf("[CheckSubscriptionStatusHandler] Vérification abonnement utilisateur %d -> créateur %d", subscriberID, creatorID)

	// Vérifier que l'utilisateur cible est bien un créateur
	creator, err := repository.GetUserByID(creatorID)
	if err != nil || creator == nil {
		log.Printf("[CheckSubscriptionStatusHandler] Créateur %d non trouvé: %v", creatorID, err)
		response.RespondWithError(w, http.StatusNotFound, "Créateur non trouvé")
		return
	}

	if creator.Role != "creator" {
		log.Printf("[CheckSubscriptionStatusHandler] L'utilisateur %d n'est pas un créateur (rôle: %s)", creatorID, creator.Role)
		response.RespondWithError(w, http.StatusBadRequest, "L'utilisateur spécifié n'est pas un créateur")
		return
	}

	// Récupération de l'abonnement actuel
	subscription, err := repository.GetActiveSubscription(subscriberID, creatorID)
	if err != nil {
		log.Printf("[CheckSubscriptionStatusHandler] Erreur récupération abonnement: %v", err)
		response.RespondWithError(w, http.StatusInternalServerError, "Erreur lors de la vérification de l'abonnement")
		return
	}

	// Construire la réponse du statut
	subscriptionStatus := map[string]interface{}{
		"creator_id":     creatorID,
		"creator_name":   creator.Username,
		"is_subscribed":  false,
		"status":         "none",
		"subscription":   nil,
	}

	if subscription != nil {
		subscriptionStatus["is_subscribed"] = subscription.Status
		subscriptionStatus["subscription"] = map[string]interface{}{
			"id":         subscription.ID,
			"created_at": subscription.CreatedAt,
			"end_at":     subscription.EndAt,
			"status":     subscription.Status,
		}

		if subscription.Status {
			subscriptionStatus["status"] = "active"
		} else {
			subscriptionStatus["status"] = "inactive"
		}
	}

	log.Printf("[CheckSubscriptionStatusHandler] Statut abonnement utilisateur %d -> créateur %d: %v", 
		subscriberID, creatorID, subscriptionStatus["is_subscribed"])

	response.RespondWithJSON(w, http.StatusOK, subscriptionStatus)
}