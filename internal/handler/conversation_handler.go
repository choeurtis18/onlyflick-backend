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

// StartConversation ou récupère une conversation existante
func StartConversation(w http.ResponseWriter, r *http.Request) {
	log.Println("[StartConversation] Démarrage ou récupération d'une conversation")

	userID := r.Context().Value(middleware.ContextUserIDKey).(int64)
	receiverIDStr := chi.URLParam(r, "receiverId")
	receiverID, err := strconv.ParseInt(receiverIDStr, 10, 64)
	if err != nil || receiverID <= 0 {
		log.Printf("[StartConversation] ID créateur invalide: %v", err)
		response.RespondWithError(w, http.StatusBadRequest, "ID de créateur invalide")
		return
	}
	log.Printf("[StartConversation] ID utilisateur: %d, ID créateur: %d", userID, receiverID)

	// 1. Empêcher de parler à soi-même
	if userID == receiverID {
		response.RespondWithError(w, http.StatusBadRequest, "Impossible d’envoyer un message à vous-même")
		return
	}

	// 2. Vérification que le receiver est bien un créateur
	receiver, err := repository.GetUserByID(receiverID)
	if err != nil || receiver == nil || receiver.Role != "creator" {
		log.Printf("[StartConversation] Utilisateur cible %d n’est pas un créateur", receiverID)
		response.RespondWithError(w, http.StatusForbidden, "Vous ne pouvez discuter qu’avec des créateurs")
		return
	}

	// 3. Vérifier si l'utilisateur est abonné à ce créateur
	isSub, err := repository.IsSubscribed(userID, receiverID)
	if err != nil {
		log.Printf("[StartConversation] Erreur vérification abonnement: %v", err)
		response.RespondWithError(w, http.StatusInternalServerError, "Erreur interne")
		return
	}
	if !isSub {
		log.Printf("[StartConversation] Utilisateur %d NON abonné à %d", userID, receiverID)
		response.RespondWithError(w, http.StatusForbidden, "Vous devez être abonné pour démarrer la discussion")
		return
	}

	// 4. Démarrer ou récupérer la conversation
	convID, err := repository.GetConversationByParticipants(userID, receiverID)
	if err != nil {
		log.Printf("[StartConversation] Erreur DB: %v", err)
		response.RespondWithError(w, http.StatusInternalServerError, "Erreur interne")
		return
	}
	if convID == 0 {
		convID, err = repository.CreateConversation(userID, receiverID)
		if err != nil {
			log.Printf("[StartConversation] Erreur création conversation: %v", err)
			response.RespondWithError(w, http.StatusInternalServerError, "Erreur création conversation")
			return
		}
	}

	log.Printf("[StartConversation] Conversation ID %d", convID)
	response.RespondWithJSON(w, http.StatusOK, map[string]int64{"conversation_id": convID})
}
