package handler

import (
	"log"
	"net/http"
	"onlyflick/internal/middleware"
	"onlyflick/internal/repository"
	"onlyflick/pkg/response"
	"onlyflick/pkg/ws"
	"strconv"

	"github.com/go-chi/chi/v5"
	"github.com/gorilla/websocket"
)

var upgrader = websocket.Upgrader{
	CheckOrigin: func(r *http.Request) bool { return true }, // à adapter si besoin
}

// HandleMessagesWebSocket gère la connexion WebSocket pour la messagerie privée.
func HandleMessagesWebSocket(w http.ResponseWriter, r *http.Request) {
	log.Println("[HandleMessagesWebSocket] Connexion WebSocket reçue")

	conn, err := upgrader.Upgrade(w, r, nil)
	if err != nil {
		log.Printf("[WebSocket][ERREUR] Upgrade échoué : %v", err)
		return
	}
	defer conn.Close()

	userID, ok := r.Context().Value(middleware.ContextUserIDKey).(int64)
	if !ok {
		log.Println("[WebSocket] Utilisateur non authentifié")
		response.RespondWithError(w, http.StatusUnauthorized, "Non authentifié")
		return
	}

	convIDStr := chi.URLParam(r, "conversation_id")
	convID, err := strconv.ParseInt(convIDStr, 10, 64)
	if err != nil {
		log.Printf("[WebSocket] conversation_id invalide: %v", err)
		return
	}

	ok, err = repository.IsUserInConversation(convID, userID)
	if err != nil || !ok {
		log.Printf("[WebSocket] Accès interdit pour user %d à conv %d", userID, convID)
		return
	}

	ws.RegisterClient(convID, userID, conn)
	defer ws.UnregisterClient(convID, userID)

	for {
		var msg struct {
			Content string `json:"content"`
		}
		if err := conn.ReadJSON(&msg); err != nil {
			log.Printf("[WebSocket] Déconnexion de user %d: %v", userID, err)
			break
		}

		// Enregistrer le message dans la DB
		saved, err := repository.CreateMessage(convID, userID, msg.Content)
		if err != nil {
			log.Printf("[WebSocket] Erreur DB lors de l'enregistrement du message: %v", err)
			continue
		}

		ws.BroadcastMessage(convID, saved)
	}
}
