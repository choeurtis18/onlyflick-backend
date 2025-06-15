package main

import (
	"log"
	"net/http"
	"time"

	"github.com/gorilla/websocket"
)

func main() {
	conversationID := "1"
	jwt := "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjE3NTAxMDM5MjQsImlhdCI6MTc1MDAxNzUyNCwicm9sZSI6InN1YnNjcmliZXIiLCJzdWIiOjR9.sDzXgrqplMwDNl46C3_lZluZbD0IQkY_pzbRTHCeZO4"

	url := "ws://localhost:8080/ws/messages/" + conversationID
	log.Println("Connexion à", url)

	header := http.Header{}
	header.Set("Authorization", jwt)

	conn, _, err := websocket.DefaultDialer.Dial(url, header)
	if err != nil {
		log.Fatal("Erreur de connexion WebSocket :", err)
	}
	defer conn.Close()

	go func() {
		for {
			_, message, err := conn.ReadMessage()
			if err != nil {
				log.Println("Erreur lecture message:", err)
				return
			}
			log.Println("Message reçu :", string(message))
		}
	}()

	err = conn.WriteJSON(map[string]string{"content": "Coucou, ici B 👋"})
	if err != nil {
		log.Println("Erreur d'envoi:", err)
	}

	time.Sleep(10 * time.Second)
}
