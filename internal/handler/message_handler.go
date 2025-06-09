package handler

import (
	"encoding/json"
	"log"
	"net/http"
	"onlyflick/internal/database"
	"onlyflick/internal/middleware"
	"onlyflick/internal/repository"
	"onlyflick/pkg/response"
	"strconv"

	"github.com/go-chi/chi/v5"
)

// GetConversationMessages retourne les messages d'une conversation donnée (paginé)
func GetConversationMessages(w http.ResponseWriter, r *http.Request) {
	log.Println("[GetConversationMessages] Récupération des messages de la conversation")
	userID := r.Context().Value(middleware.ContextUserIDKey).(int64)

	convID, err := strconv.ParseInt(chi.URLParam(r, "id"), 10, 64)
	if err != nil {
		log.Printf("[GetConversationMessages] ID de conversation invalide : %v", err)
		response.RespondWithError(w, http.StatusBadRequest, "ID de conversation invalide")
		return
	}

	// Vérifie que l'utilisateur participe à la conversation
	isParticipant, err := repository.IsUserInConversation(convID, userID)
	if err != nil {
		log.Printf("[GetConversationMessages] Erreur vérification participant : %v", err)
		response.RespondWithError(w, http.StatusInternalServerError, "Erreur interne")
		return
	}
	if !isParticipant {
		log.Printf("[GetConversationMessages] Accès refusé à la conversation %d", convID)
		response.RespondWithError(w, http.StatusForbidden, "Accès interdit à cette conversation")
		return
	}

	// Optionnel : pagination
	pageSize := 20
	page := 1
	if p := r.URL.Query().Get("page"); p != "" {
		if parsed, err := strconv.Atoi(p); err == nil && parsed > 0 {
			page = parsed
		}
	}
	offset := (page - 1) * pageSize

	// Récupération des messages
	messages, err := repository.GetMessages(convID, pageSize, offset)
	if err != nil {
		log.Printf("[GetConversationMessages] Erreur récupération messages : %v", err)
		response.RespondWithError(w, http.StatusInternalServerError, "Impossible de récupérer les messages")
		return
	}

	log.Printf("[GetConversationMessages] %d messages récupérés pour conv %d", len(messages), convID)
	response.RespondWithJSON(w, http.StatusOK, messages)
}

// SendMessage enregistre un message dans la conversation
func SendMessage(w http.ResponseWriter, r *http.Request) {
	log.Println("[SendMessage] Envoi d'un message dans la conversation")

	userID := r.Context().Value(middleware.ContextUserIDKey).(int64)
	convID, err := strconv.ParseInt(chi.URLParam(r, "id"), 10, 64)
	if err != nil {
		log.Printf("[SendMessage] Conversation invalide: %v", err)
		response.RespondWithError(w, http.StatusBadRequest, "ID conversation invalide")
		return
	}

	isIn, err := repository.IsUserInConversation(convID, userID)
	if err != nil {
		log.Printf("[SendMessage] Erreur vérification: %v", err)
		response.RespondWithError(w, http.StatusInternalServerError, "Erreur interne")
		return
	}
	if !isIn {
		log.Printf("[SendMessage] Utilisateur non autorisé à envoyer dans convers %d", convID)
		response.RespondWithError(w, http.StatusForbidden, "Accès interdit")
		return
	}

	var payload struct {
		Content string `json:"content"`
	}
	if err := json.NewDecoder(r.Body).Decode(&payload); err != nil {
		log.Printf("[SendMessage] JSON invalide: %v", err)
		response.RespondWithError(w, http.StatusBadRequest, "JSON invalide")
		return
	}

	msg, err := repository.CreateMessage(convID, userID, payload.Content)
	if err != nil {
		log.Printf("[SendMessage] Échec DB: %v", err)
		response.RespondWithError(w, http.StatusInternalServerError, "Impossible d'envoyer le message")
		return
	}
	response.RespondWithJSON(w, http.StatusCreated, msg)

	// TODO: notifier via WebSocket ou pub/sub
}

// GetMyConversations récupère les conversations de l'utilisateur connecté.
func GetMyConversations(w http.ResponseWriter, r *http.Request) {
	log.Println("[GetMyConversations] Récupération des conversations de l'utilisateur")

	userID := r.Context().Value(middleware.ContextUserIDKey).(int64)

	convs, err := repository.GetConversationsForUser(userID)
	if err != nil {
		log.Printf("[GetMyConversations] Erreur récupération conversations user %d : %v", userID, err)
		response.RespondWithError(w, http.StatusInternalServerError, "Erreur lors de la récupération des conversations")
		return
	}

	log.Printf("[GetMyConversations] %d conversations récupérées pour user %d", len(convs), userID)
	response.RespondWithJSON(w, http.StatusOK, convs)
}

// GetMessagesInConversation récupère les messages d'une conversation.
func GetMessagesInConversation(w http.ResponseWriter, r *http.Request) {
	log.Println("[GetMessagesInConversation] Récupération des messages dans la conversation")

	userID := r.Context().Value(middleware.ContextUserIDKey).(int64)
	convID, err := strconv.ParseInt(chi.URLParam(r, "id"), 10, 64)
	if err != nil {
		log.Printf("[GetMessagesInConversation] ID conversation invalide : %v", err)
		response.RespondWithError(w, http.StatusBadRequest, "ID de conversation invalide")
		return
	}

	messages, err := repository.GetMessagesForConversation(convID, userID)
	if err != nil {
		log.Printf("[GetMessagesInConversation] Erreur récupération messages pour conversation %d : %v", convID, err)
		response.RespondWithError(w, http.StatusInternalServerError, "Erreur lors de la récupération des messages")
		return
	}

	log.Printf("[GetMessagesInConversation] %d messages récupérés pour conv %d", len(messages), convID)
	response.RespondWithJSON(w, http.StatusOK, messages)
}

// SendMessageInConversation envoie un message dans une conversation spécifique
func SendMessageInConversation(w http.ResponseWriter, r *http.Request) {
	log.Println("[SendMessageInConversation] Envoi d’un message")

	userID := r.Context().Value(middleware.ContextUserIDKey).(int64)
	conversationIDStr := chi.URLParam(r, "id")
	conversationID, err := strconv.ParseInt(conversationIDStr, 10, 64)
	if err != nil {
		log.Printf("[SendMessageInConversation] ID conversation invalide : %v", err)
		response.RespondWithError(w, http.StatusBadRequest, "ID de conversation invalide")
		return
	}

	isInConv, err := repository.IsUserInConversation(conversationID, userID)
	if err != nil {
		log.Printf("[SendMessageInConversation] Erreur vérif participation : %v", err)
		response.RespondWithError(w, http.StatusInternalServerError, "Erreur participation")
		return
	}
	if !isInConv {
		log.Printf("[SendMessageInConversation] Utilisateur %d n’est pas dans la conversation %d", userID, conversationID)
		response.RespondWithError(w, http.StatusForbidden, "Accès non autorisé")
		return
	}

	// Ici tu peux rajouter une requête directe pour récupérer creator_id et subscriber_id
	var creatorID, subscriberID int64
	err = database.DB.QueryRow(`
		SELECT creator_id, subscriber_id FROM conversations WHERE id = $1
	`, conversationID).Scan(&creatorID, &subscriberID)
	if err != nil {
		log.Printf("[SendMessageInConversation] Conversation introuvable ou erreur SQL : %v", err)
		response.RespondWithError(w, http.StatusInternalServerError, "Conversation non trouvée")
		return
	}

	// Vérifie abonnement
	if userID == subscriberID {
		isSub, err := repository.IsSubscribed(subscriberID, creatorID)
		if err != nil || !isSub {
			log.Printf("[SendMessageInConversation] Utilisateur %d n’est pas abonné au créateur %d", subscriberID, creatorID)
			response.RespondWithError(w, http.StatusForbidden, "Vous devez être abonné pour discuter")
			return
		}
	}

	var req struct {
		Content string `json:"content"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil || req.Content == "" {
		log.Printf("[SendMessageInConversation] Corps invalide : %v", err)
		response.RespondWithError(w, http.StatusBadRequest, "Message vide")
		return
	}

	msg, err := repository.CreateMessage(conversationID, userID, req.Content)
	if err != nil {
		log.Printf("[SendMessageInConversation] Erreur insertion : %v", err)
		response.RespondWithError(w, http.StatusInternalServerError, "Erreur envoi")
		return
	}

	response.RespondWithJSON(w, http.StatusCreated, msg)
}
