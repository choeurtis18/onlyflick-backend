package handler

import (
	"log"
	"net/http"
	"onlyflick/internal/middleware"
	"onlyflick/internal/repository"
	"onlyflick/internal/utils"
	"onlyflick/pkg/response"
	"strconv"

	"github.com/go-chi/chi/v5"
)

// GetUserProfileHandler récupère le profil public d'un utilisateur
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

	// Construire la réponse du profil public
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

	log.Printf("[GetUserProfileHandler] Profil public récupéré pour utilisateur %d (%s %s)", 
		targetUserID, firstName, lastName)

	response.RespondWithJSON(w, http.StatusOK, publicProfile)
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