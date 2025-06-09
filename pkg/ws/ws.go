package ws

import (
	"encoding/json"
	"log"
	"onlyflick/internal/domain"
	"sync"

	"github.com/gorilla/websocket"
)

type Client struct {
	userID         int64
	conversationID int64
	conn           *websocket.Conn
}

var (
	clientsByConv = make(map[int64]map[int64]*Client)
	mu            sync.RWMutex
)

// RegisterClient ajoute un client à une conversation
func RegisterClient(convID, userID int64, conn *websocket.Conn) {
	mu.Lock()
	defer mu.Unlock()

	if _, exists := clientsByConv[convID]; !exists {
		clientsByConv[convID] = make(map[int64]*Client)
	}
	clientsByConv[convID][userID] = &Client{userID: userID, conversationID: convID, conn: conn}
	log.Printf("[ws] Client connecté, conv %d user %d", convID, userID)
}

// UnregisterClient retire un client d’une conversation
func UnregisterClient(convID, userID int64) {
	mu.Lock()
	defer mu.Unlock()

	if clients, exists := clientsByConv[convID]; exists {
		if _, ok := clients[userID]; ok {
			delete(clients, userID)
			if len(clients) == 0 {
				delete(clientsByConv, convID)
			}
		}
	}
	log.Printf("[ws] Client déconnecté, conv %d user %d", convID, userID)
}

// BroadcastMessage envoie un message à tous les participants connectés
func BroadcastMessage(convID int64, msg *domain.Message) {
	mu.RLock()
	defer mu.RUnlock()

	clients, exists := clientsByConv[convID]
	if !exists {
		return
	}

	data, err := json.Marshal(msg)
	if err != nil {
		log.Printf("[ws] Échec sérialisation message: %v", err)
		return
	}

	for uid, client := range clients {
		if err := client.conn.WriteMessage(websocket.TextMessage, data); err != nil {
			log.Printf("[ws] Échec envoi à user %d: %v", uid, err)
		}
	}
}
