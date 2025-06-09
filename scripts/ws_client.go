package main

import (
	"log"
	"net/http"
	"net/url"

	"github.com/gorilla/websocket"
)

func main() {
	userJWT := "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjE3NDk1OTEwMDgsImlhdCI6MTc0OTUwNDYwOCwicm9sZSI6InN1YnNjcmliZXIiLCJzdWIiOjR9.vPvFhP3kZ6vshQZ7AmPiIOu4lxIlAG9HUIW2LdnQ2B4"
	conversationID := "1"

	u := url.URL{
		Scheme: "ws",
		Host:   "localhost:8080",
		Path:   "/ws/messages/" + conversationID,
	}

	header := http.Header{}
	header.Set("Authorization", "Bearer "+userJWT)

	log.Printf("Connexion à %s", u.String())
	conn, _, err := websocket.DefaultDialer.Dial(u.String(), header)
	if err != nil {
		log.Fatalf("Erreur de connexion WebSocket : %v", err)
	}
	defer conn.Close()

	// Exemple d'envoi de message
	err = conn.WriteJSON(map[string]string{
		"content": "Hello via WebSocket",
	})
	if err != nil {
		log.Printf("Erreur d'envoi de message : %v", err)
	}

	// Lecture d'une réponse
	_, message, err := conn.ReadMessage()
	if err != nil {
		log.Printf("Erreur de réception : %v", err)
	} else {
		log.Printf("Message reçu : %s", message)
	}
}
