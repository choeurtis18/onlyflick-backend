// internal/handler/subscription_handler.go
package handler

import (
	"fmt"
	"log"
	"net/http"
	"onlyflick/internal/middleware"
	"onlyflick/internal/repository"
	"onlyflick/internal/utils"
	"onlyflick/pkg/response"
	"os"
	"strconv"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/stripe/stripe-go"
	"github.com/stripe/stripe-go/paymentintent"
)

// ===== STRUCTURES POUR LES RÉPONSES =====

// FollowerProfile représente le profil d'un abonné
type FollowerProfile struct {
	ID        int64  `json:"id"`
	Username  string `json:"username"`
	FirstName string `json:"first_name"`
	LastName  string `json:"last_name"`
	FullName  string `json:"full_name"`
	Role      string `json:"role"`
	AvatarURL string `json:"avatar_url"`
	Bio       string `json:"bio"`
	CreatedAt string `json:"created_at"`
}

// FollowingProfile représente le profil d'un créateur suivi
type FollowingProfile struct {
	ID               int64  `json:"id"`
	Username         string `json:"username"`
	FirstName        string `json:"first_name"`
	LastName         string `json:"last_name"`
	FullName         string `json:"full_name"`
	Role             string `json:"role"`
	AvatarURL        string `json:"avatar_url"`
	Bio              string `json:"bio"`
	SubscriptionPrice string `json:"subscription_price"`
	CreatedAt        string `json:"created_at"`
}

// SubscriptionWithProfile représente un abonnement avec les infos du profil
type SubscriptionWithProfile struct {
	ID               int64             `json:"id"`
	SubscriberID     int64             `json:"subscriber_id"`
	CreatorID        int64             `json:"creator_id"`
	Status           bool              `json:"status"`
	CreatedAt        string            `json:"created_at"`
	SubscriberProfile *FollowerProfile  `json:"subscriber_profile,omitempty"`
	CreatorProfile   *FollowingProfile `json:"creator_profile,omitempty"`
}

// ===== HANDLERS POUR LES LISTES D'ABONNEMENTS =====

// GetUserFollowersHandler récupère la liste des abonnés d'un utilisateur (créateur)
// Route: GET /users/{user_id}/followers
func GetUserFollowersHandler(w http.ResponseWriter, r *http.Request) {
	log.Println("[GetUserFollowersHandler] Récupération des abonnés d'un utilisateur")

	// Récupération de l'ID de l'utilisateur connecté (pour vérification des permissions)
	currentUserVal := r.Context().Value(middleware.ContextUserIDKey)
	currentUserID, ok := currentUserVal.(int64)
	if !ok {
		log.Println("[GetUserFollowersHandler] Utilisateur non authentifié")
		response.RespondWithError(w, http.StatusUnauthorized, "Utilisateur non authentifié")
		return
	}

	// Récupération de l'ID de l'utilisateur cible depuis l'URL
	userIDStr := chi.URLParam(r, "user_id")
	targetUserID, err := strconv.ParseInt(userIDStr, 10, 64)
	if err != nil || targetUserID <= 0 {
		log.Printf("[GetUserFollowersHandler] ID utilisateur invalide: %s", userIDStr)
		response.RespondWithError(w, http.StatusBadRequest, "ID utilisateur invalide")
		return
	}

	log.Printf("[GetUserFollowersHandler] Utilisateur %d demande les abonnés de %d", currentUserID, targetUserID)

	// Vérifier que l'utilisateur cible existe
	targetUser, err := repository.GetUserByID(targetUserID)
	if err != nil || targetUser == nil {
		log.Printf("[GetUserFollowersHandler] Utilisateur cible %d non trouvé", targetUserID)
		response.RespondWithError(w, http.StatusNotFound, "Utilisateur non trouvé")
		return
	}

	// Récupérer la liste des abonnements où cet utilisateur est le créateur
	subscriptions, err := repository.GetUserFollowers(targetUserID)
	if err != nil {
		log.Printf("[GetUserFollowersHandler] Erreur récupération abonnés: %v", err)
		response.RespondWithError(w, http.StatusInternalServerError, "Erreur lors de la récupération des abonnés")
		return
	}

	// Construire la réponse avec les profils des abonnés
	var followersWithProfile []SubscriptionWithProfile
	for _, sub := range subscriptions {
		// Récupérer le profil de l'abonné
		subscriberProfile, err := getFollowerProfile(sub.SubscriberID)
		if err != nil {
			log.Printf("[GetUserFollowersHandler] Erreur récupération profil abonné %d: %v", sub.SubscriberID, err)
			continue // Ignorer cet abonné en cas d'erreur
		}

		subscriptionWithProfile := SubscriptionWithProfile{
			ID:           sub.ID,
			SubscriberID: sub.SubscriberID,
			CreatorID:    sub.CreatorID,
			Status:       sub.Status,
			CreatedAt:    sub.CreatedAt.Format("2006-01-02T15:04:05Z"),
			SubscriberProfile: subscriberProfile,
		}

		followersWithProfile = append(followersWithProfile, subscriptionWithProfile)
	}

	// Réponse
	responseData := map[string]interface{}{
		"followers": followersWithProfile,
		"total":     len(followersWithProfile),
		"user_id":   targetUserID,
	}

	log.Printf("[GetUserFollowersHandler] %d abonnés récupérés pour l'utilisateur %d", len(followersWithProfile), targetUserID)
	response.RespondWithJSON(w, http.StatusOK, responseData)
}

// GetUserFollowingHandler récupère la liste des abonnements d'un utilisateur
// Route: GET /users/{user_id}/following
func GetUserFollowingHandler(w http.ResponseWriter, r *http.Request) {
	log.Println("[GetUserFollowingHandler] Récupération des abonnements d'un utilisateur")

	// Récupération de l'ID de l'utilisateur connecté (pour vérification des permissions)
	currentUserVal := r.Context().Value(middleware.ContextUserIDKey)
	currentUserID, ok := currentUserVal.(int64)
	if !ok {
		log.Println("[GetUserFollowingHandler] Utilisateur non authentifié")
		response.RespondWithError(w, http.StatusUnauthorized, "Utilisateur non authentifié")
		return
	}

	// Récupération de l'ID de l'utilisateur cible depuis l'URL
	userIDStr := chi.URLParam(r, "user_id")
	targetUserID, err := strconv.ParseInt(userIDStr, 10, 64)
	if err != nil || targetUserID <= 0 {
		log.Printf("[GetUserFollowingHandler] ID utilisateur invalide: %s", userIDStr)
		response.RespondWithError(w, http.StatusBadRequest, "ID utilisateur invalide")
		return
	}

	log.Printf("[GetUserFollowingHandler] Utilisateur %d demande les abonnements de %d", currentUserID, targetUserID)

	// Vérifier que l'utilisateur cible existe
	targetUser, err := repository.GetUserByID(targetUserID)
	if err != nil || targetUser == nil {
		log.Printf("[GetUserFollowingHandler] Utilisateur cible %d non trouvé", targetUserID)
		response.RespondWithError(w, http.StatusNotFound, "Utilisateur non trouvé")
		return
	}

	// Récupérer la liste des abonnements de cet utilisateur
	subscriptions, err := repository.GetUserFollowing(targetUserID)
	if err != nil {
		log.Printf("[GetUserFollowingHandler] Erreur récupération abonnements: %v", err)
		response.RespondWithError(w, http.StatusInternalServerError, "Erreur lors de la récupération des abonnements")
		return
	}

	// Construire la réponse avec les profils des créateurs suivis
	var followingWithProfile []SubscriptionWithProfile
	for _, sub := range subscriptions {
		// Récupérer le profil du créateur
		creatorProfile, err := getFollowingProfile(sub.CreatorID)
		if err != nil {
			log.Printf("[GetUserFollowingHandler] Erreur récupération profil créateur %d: %v", sub.CreatorID, err)
			continue // Ignorer ce créateur en cas d'erreur
		}

		subscriptionWithProfile := SubscriptionWithProfile{
			ID:           sub.ID,
			SubscriberID: sub.SubscriberID,
			CreatorID:    sub.CreatorID,
			Status:       sub.Status,
			CreatedAt:    sub.CreatedAt.Format("2006-01-02T15:04:05Z"),
			CreatorProfile: creatorProfile,
		}

		followingWithProfile = append(followingWithProfile, subscriptionWithProfile)
	}

	// Réponse
	responseData := map[string]interface{}{
		"following": followingWithProfile,
		"total":     len(followingWithProfile),
		"user_id":   targetUserID,
	}

	log.Printf("[GetUserFollowingHandler] %d abonnements récupérés pour l'utilisateur %d", len(followingWithProfile), targetUserID)
	response.RespondWithJSON(w, http.StatusOK, responseData)
}

// ===== HANDLERS POUR LA GESTION DES ABONNEMENTS =====

// SubscribeWithPayment permet à un utilisateur de s'abonner à un créateur et de procéder au paiement.
func SubscribeWithPayment(w http.ResponseWriter, r *http.Request) {
	userVal := r.Context().Value(middleware.ContextUserIDKey)
	subscriberID, ok := userVal.(int64)
	if !ok {
		log.Println("[SubscribeWithPayment] Utilisateur non authentifié")
		response.RespondWithError(w, http.StatusUnauthorized, "Utilisateur non authentifié")
		return
	}

	creatorID, err := strconv.ParseInt(chi.URLParam(r, "creator_id"), 10, 64)
	if err != nil {
		log.Printf("[SubscribeWithPayment] ID du créateur invalide : %v", err)
		response.RespondWithError(w, http.StatusBadRequest, "ID du créateur invalide")
		return
	}

	if subscriberID == creatorID {
		log.Printf("[SubscribeWithPayment] Tentative d'auto-abonnement utilisateur %d", subscriberID)
		response.RespondWithError(w, http.StatusBadRequest, "Impossible de s'abonner à soi-même")
		return
	}

	// Vérifier si l'utilisateur est déjà abonné au créateur
	subscription, err := repository.GetActiveSubscription(subscriberID, creatorID)
	if err != nil {
		log.Printf("[SubscribeWithPayment] Erreur lors de la vérification de l'abonnement : %v", err)
		response.RespondWithError(w, http.StatusInternalServerError, "Erreur de vérification d'abonnement")
		return
	}

	// Si l'abonnement est inactif, réactiver et procéder au paiement
	if subscription != nil && !subscription.Status {
		log.Printf("[SubscribeWithPayment] Abonnement inactif trouvé, réactivation et paiement pour l'utilisateur %d au créateur %d", subscriberID, creatorID)
		err := repository.ReactivateSubscription(subscription.ID, time.Now())
		if err != nil {
			log.Printf("[SubscribeWithPayment] Erreur lors de la réactivation de l'abonnement : %v", err)
			response.RespondWithError(w, http.StatusInternalServerError, "Erreur de réactivation d'abonnement")
			return
		}
		log.Printf("[SubscribeWithPayment] Abonnement réactivé pour l'utilisateur %d au créateur %d", subscriberID, creatorID)
		response.RespondWithJSON(w, http.StatusOK, map[string]string{"message": "Abonnement réactivé avec succès"})
		return
	}

	// Si l'abonnement existe déjà et est actif, retourner une erreur
	if subscription != nil && subscription.Status {
		log.Printf("[SubscribeWithPayment] Abonnement déjà actif pour l'utilisateur %d au créateur %d", subscriberID, creatorID)
		response.RespondWithError(w, http.StatusBadRequest, "Vous êtes déjà abonné à ce créateur")
		return
	}

	// Si l'abonnement n'existe pas, créer un nouvel abonnement
	newSubscription, err := repository.Subscribe(subscriberID, creatorID)
	if err != nil {
		log.Printf("[SubscribeWithPayment] Erreur lors de l'abonnement : %v", err)
		response.RespondWithError(w, http.StatusInternalServerError, "Erreur d'abonnement")
		return
	}

	// Créer un PaymentIntent via Stripe
	stripe.Key = os.Getenv("STRIPE_SECRET_KEY")

	intentParams := &stripe.PaymentIntentParams{
		Amount:   stripe.Int64(499), // Montant en centimes (499 = 4.99€)
		Currency: stripe.String(string(stripe.CurrencyEUR)),
	}

	intent, err := paymentintent.New(intentParams)
	if err != nil {
		log.Printf("[SubscribeWithPayment] Erreur Stripe lors de la création du PaymentIntent : %v", err)
		response.RespondWithError(w, http.StatusInternalServerError, "Erreur de paiement")
		return
	}

	// Ajouter Metadata après la création du PaymentIntent
	intent.Metadata = map[string]string{"subscription_id": fmt.Sprintf("%d", newSubscription.ID)}

	// Enregistrer le paiement dans la base de données
	_, err = repository.CreatePayment(newSubscription.ID, intent.ID, fmt.Sprintf("%d", subscriberID), time.Now(), time.Now().AddDate(0, 1, 0), 499, "succeeded")
	if err != nil {
		log.Printf("[SubscribeWithPayment] Erreur d'enregistrement du paiement : %v", err)
		response.RespondWithError(w, http.StatusInternalServerError, "Erreur d'enregistrement du paiement")
		return
	}

	// Prolonger l'abonnement de 1 mois
	_, err = repository.UpdateSubscriptionEndDate(newSubscription.ID, time.Now().AddDate(0, 1, 0))
	if err != nil {
		log.Printf("[SubscribeWithPayment] Erreur lors de la mise à jour de l'abonnement %d : %v", newSubscription.ID, err)
		response.RespondWithError(w, http.StatusInternalServerError, "Erreur lors de la mise à jour de l'abonnement")
		return
	}

	log.Printf("[SubscribeWithPayment] Paiement réussi pour l'utilisateur %d et créateur %d", subscriberID, creatorID)
	response.RespondWithJSON(w, http.StatusOK, map[string]string{
		"message":       "Abonnement et paiement réussis",
		"client_secret": intent.ClientSecret,
	})
}

// Subscribe permet à un utilisateur de s'abonner à un créateur sans paiement immédiat.
func Subscribe(w http.ResponseWriter, r *http.Request) {
	// Récupération de l'ID de l'utilisateur depuis le contexte
	userVal := r.Context().Value(middleware.ContextUserIDKey)
	subscriberID, ok := userVal.(int64)
	if !ok {
		log.Println("[Subscribe] Utilisateur non authentifié")
		response.RespondWithError(w, http.StatusUnauthorized, "Utilisateur non authentifié")
		return
	}

	// Récupération de l'ID du créateur depuis les paramètres de l'URL
	creatorID, err := strconv.ParseInt(chi.URLParam(r, "creator_id"), 10, 64)
	if err != nil {
		log.Printf("[Subscribe] ID du créateur invalide : %v", err)
		response.RespondWithError(w, http.StatusBadRequest, "ID du créateur invalide")
		return
	}

	// Vérification que l'utilisateur ne tente pas de s'abonner à lui-même
	if subscriberID == creatorID {
		log.Printf("[Subscribe] Tentative d'auto-abonnement utilisateur %d", subscriberID)
		response.RespondWithError(w, http.StatusBadRequest, "Impossible de s'abonner à soi-même")
		return
	}

	// Créer l'abonnement sans paiement immédiat
	_, err = repository.Subscribe(subscriberID, creatorID)
	if err != nil {
		log.Printf("[Subscribe] Erreur lors de l'abonnement (sub: %d -> creator: %d) : %v", subscriberID, creatorID, err)
		response.RespondWithError(w, http.StatusInternalServerError, "Erreur d'abonnement")
		return
	}

	// L'abonnement a été créé avec succès
	log.Printf("[Subscribe] Utilisateur %d abonné au créateur %d", subscriberID, creatorID)
	response.RespondWithJSON(w, http.StatusOK, map[string]string{"message": "Abonnement réussi, paiement en attente"})
}

// UnSubscribe permet à un utilisateur de se désabonner d'un créateur.
func UnSubscribe(w http.ResponseWriter, r *http.Request) {
	// Récupération de l'ID de l'utilisateur depuis le contexte
	userVal := r.Context().Value(middleware.ContextUserIDKey)
	subscriberID, ok := userVal.(int64)
	if !ok {
		log.Println("[UnSubscribe] Utilisateur non authentifié")
		response.RespondWithError(w, http.StatusUnauthorized, "Utilisateur non authentifié")
		return
	}

	// Récupération de l'ID du créateur depuis les paramètres de l'URL
	creatorID, err := strconv.ParseInt(chi.URLParam(r, "creator_id"), 10, 64)
	if err != nil {
		log.Printf("[UnSubscribe] ID du créateur invalide : %v", err)
		response.RespondWithError(w, http.StatusBadRequest, "ID du créateur invalide")
		return
	}

	// Effectuer le désabonnement
	if err := repository.Unsubscribe(subscriberID, creatorID); err != nil {
		log.Printf("[UnSubscribe] Erreur désabonnement (sub: %d -> creator: %d) : %v", subscriberID, creatorID, err)
		response.RespondWithError(w, http.StatusInternalServerError, "Erreur de désabonnement")
		return
	}

	log.Printf("[UnSubscribe] Utilisateur %d désabonné du créateur %d", subscriberID, creatorID)
	response.RespondWithJSON(w, http.StatusOK, map[string]string{"message": "Désabonnement réussi"})
}

// ListMySubscriptions retourne la liste des abonnements de l'utilisateur.
func ListMySubscriptions(w http.ResponseWriter, r *http.Request) {
	// Récupération de l'ID de l'utilisateur depuis le contexte
	userVal := r.Context().Value(middleware.ContextUserIDKey)
	subscriberID, ok := userVal.(int64)
	if !ok {
		log.Println("[ListMySubscriptions] Utilisateur non authentifié")
		response.RespondWithError(w, http.StatusUnauthorized, "Utilisateur non authentifié")
		return
	}

	// Récupérer la liste des abonnements
	subscriptions, err := repository.ListMySubscriptions(subscriberID)
	if err != nil {
		log.Printf("[ListMySubscriptions] Erreur récupération abonnements pour %d : %v", subscriberID, err)
		response.RespondWithError(w, http.StatusInternalServerError, "Erreur récupération abonnements")
		return
	}

	log.Printf("[ListMySubscriptions] %d abonnements récupérés pour utilisateur %d", len(subscriptions), subscriberID)
	response.RespondWithJSON(w, http.StatusOK, subscriptions)
}

// ===== FONCTIONS UTILITAIRES =====

// getFollowerProfile récupère le profil d'un abonné
func getFollowerProfile(userID int64) (*FollowerProfile, error) {
	user, err := repository.GetUserByID(userID)
	if err != nil {
		return nil, err
	}

	// Décryptage des données (ajustez selon votre logique)
	firstName, _ := utils.DecryptAES(user.FirstName)
	lastName, _ := utils.DecryptAES(user.LastName)

	profile := &FollowerProfile{
		ID:        user.ID,
		Username:  user.Username,
		FirstName: firstName,
		LastName:  lastName,
		FullName:  firstName + " " + lastName,
		Role:      string(user.Role), // Conversion de domain.Role vers string
		AvatarURL: user.AvatarURL,
		Bio:       user.Bio,
		CreatedAt: user.CreatedAt.Format("2006-01-02T15:04:05Z"),
	}

	return profile, nil
}

// getFollowingProfile récupère le profil d'un créateur suivi
func getFollowingProfile(userID int64) (*FollowingProfile, error) {
	user, err := repository.GetUserByID(userID)
	if err != nil {
		return nil, err
	}

	// Décryptage des données (ajustez selon votre logique)
	firstName, _ := utils.DecryptAES(user.FirstName)
	lastName, _ := utils.DecryptAES(user.LastName)

	profile := &FollowingProfile{
		ID:        user.ID,
		Username:  user.Username,
		FirstName: firstName,
		LastName:  lastName,
		FullName:  firstName + " " + lastName,
		Role:      string(user.Role), // Conversion de domain.Role vers string
		AvatarURL: user.AvatarURL,
		Bio:       user.Bio,
		SubscriptionPrice: "4.99", // Prix fixe ou récupéré depuis la DB
		CreatedAt: user.CreatedAt.Format("2006-01-02T15:04:05Z"),
	}

	return profile, nil
}