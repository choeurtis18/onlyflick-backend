package handler

import (
	"log"
	"net/http"
	"onlyflick/internal/middleware"
	"onlyflick/internal/repository"
	"onlyflick/pkg/response"
	"strconv"

	"github.com/go-chi/chi/v5"
)

// Subscribe permet à un utilisateur de s'abonner à un créateur.
func Subscribe(w http.ResponseWriter, r *http.Request) {
	userVal := r.Context().Value(middleware.ContextUserIDKey)
	subscriberID, ok := userVal.(int64)
	if !ok {
		log.Println("[Subscribe] Utilisateur non authentifié")
		response.RespondWithError(w, http.StatusUnauthorized, "Utilisateur non authentifié")
		return
	}

	creatorID, err := strconv.ParseInt(chi.URLParam(r, "creator_id"), 10, 64)
	if err != nil {
		log.Printf("[Subscribe] ID du créateur invalide : %v", err)
		response.RespondWithError(w, http.StatusBadRequest, "ID du créateur invalide")
		return
	}

	if subscriberID == creatorID {
		log.Printf("[Subscribe] Tentative d'auto-abonnement utilisateur %d", subscriberID)
		response.RespondWithError(w, http.StatusBadRequest, "Impossible de s'abonner à soi-même")
		return
	}

	if err := repository.Subscribe(subscriberID, creatorID); err != nil {
		log.Printf("[Subscribe] Erreur abonnement (sub: %d -> creator: %d) : %v", subscriberID, creatorID, err)
		response.RespondWithError(w, http.StatusInternalServerError, "Erreur d'abonnement")
		return
	}

	log.Printf("[Subscribe] Utilisateur %d abonné au créateur %d", subscriberID, creatorID)
	response.RespondWithJSON(w, http.StatusOK, map[string]string{"message": "Abonnement réussi"})
}

// UnSubscribe permet à un utilisateur de se désabonner d'un créateur.
func UnSubscribe(w http.ResponseWriter, r *http.Request) {
	userVal := r.Context().Value(middleware.ContextUserIDKey)
	subscriberID, ok := userVal.(int64)
	if !ok {
		log.Println("[UnSubscribe] Utilisateur non authentifié")
		response.RespondWithError(w, http.StatusUnauthorized, "Utilisateur non authentifié")
		return
	}

	creatorID, err := strconv.ParseInt(chi.URLParam(r, "creator_id"), 10, 64)
	if err != nil {
		log.Printf("[UnSubscribe] ID du créateur invalide : %v", err)
		response.RespondWithError(w, http.StatusBadRequest, "ID du créateur invalide")
		return
	}

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
	userVal := r.Context().Value(middleware.ContextUserIDKey)
	subscriberID, ok := userVal.(int64)
	if !ok {
		log.Println("[ListMySubscriptions] Utilisateur non authentifié")
		response.RespondWithError(w, http.StatusUnauthorized, "Utilisateur non authentifié")
		return
	}

	subscriptions, err := repository.ListMySubscriptions(subscriberID)
	if err != nil {
		log.Printf("[ListMySubscriptions] Erreur récupération abonnements pour %d : %v", subscriberID, err)
		response.RespondWithError(w, http.StatusInternalServerError, "Erreur récupération abonnements")
		return
	}

	log.Printf("[ListMySubscriptions] %d abonnements récupérés pour utilisateur %d", len(subscriptions), subscriberID)
	response.RespondWithJSON(w, http.StatusOK, subscriptions)
}
