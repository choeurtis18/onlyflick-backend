package handler

import (
	"fmt"
	"log"
	"net/http"
	"onlyflick/internal/middleware"
	"onlyflick/internal/repository"
	"onlyflick/pkg/response"
	"os"
	"strconv"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/stripe/stripe-go"
	"github.com/stripe/stripe-go/paymentintent"
)

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
		// Le paiement est déjà effectué lors de la réactivation
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
	// Créer une nouvelle subscription et obtenir l'ID
	subscriptionID, err := repository.Subscribe(subscriberID, creatorID)
	if err != nil {
		log.Printf("[SubscribeWithPayment] Erreur lors de l'abonnement : %v", err)
		response.RespondWithError(w, http.StatusInternalServerError, "Erreur d'abonnement")
		return
	}

	// Créer un PaymentIntent via Stripe
	stripe.Key = os.Getenv("STRIPE_SECRET_KEY") // Mettre votre clé secrète Stripe ici

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
	intent.Metadata = map[string]string{"subscription_id": fmt.Sprintf("%d", subscriptionID)}

	// Enregistrer le paiement dans la base de données
	_, err = repository.CreatePayment(subscriptionID, intent.ID, fmt.Sprintf("%d", subscriberID), time.Now(), time.Now().AddDate(0, 1, 0), 499, "succeeded")
	if err != nil {
		log.Printf("[SubscribeWithPayment] Erreur d'enregistrement du paiement : %v", err)
		response.RespondWithError(w, http.StatusInternalServerError, "Erreur d'enregistrement du paiement")
		return
	}

	// Prolonger l'abonnement de 1 mois
	_, err = repository.UpdateSubscriptionEndDate(subscriptionID, time.Now().AddDate(0, 1, 0)) // Mettre à jour la date de fin
	if err != nil {
		log.Printf("[SubscribeWithPayment] Erreur lors de la mise à jour de l'abonnement %d : %v", subscriptionID, err)
		response.RespondWithError(w, http.StatusInternalServerError, "Erreur lors de la mise à jour de l'abonnement")
		return
	}

	log.Printf("[SubscribeWithPayment] Paiement réussi pour l'utilisateur %d et créateur %d", subscriberID, creatorID)
	response.RespondWithJSON(w, http.StatusOK, map[string]string{
		"message":       "Abonnement et paiement réussis",
		"client_secret": intent.ClientSecret, // Retourner le client secret pour le front-end
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
