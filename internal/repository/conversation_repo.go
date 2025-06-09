package repository

import (
	"database/sql"
	"fmt"
	"log"
	"onlyflick/internal/database"
)

func CreateConversation(creatorID, subscriberID int64) (int64, error) {
	log.Printf("[CreateConversation] Création d'une conversation entre %d et %d", creatorID, subscriberID)

	var convID int64
	err := database.DB.QueryRow(`
        INSERT INTO conversations (creator_id, subscriber_id, created_at)
        VALUES ($1, $2, NOW())
        RETURNING id
    `, creatorID, subscriberID).Scan(&convID)
	if err != nil {
		log.Printf("[CreateConversation][ERREUR] Échec de la création de conversation entre %d et %d : %v", creatorID, subscriberID, err)
		return 0, fmt.Errorf("failed to create conversation: %w", err)
	}

	log.Printf("[CreateConversation] Conversation créée avec succès, ID: %d", convID)
	return convID, nil
}

func GetConversationByParticipants(creatorID, subscriberID int64) (int64, error) {
	log.Printf("[GetConversationByParticipants] Recherche conversation entre %d et %d", creatorID, subscriberID)

	var convID int64
	err := database.DB.QueryRow(`
        SELECT id FROM conversations
        WHERE creator_id = $1 AND subscriber_id = $2
    `, creatorID, subscriberID).Scan(&convID)
	if err == sql.ErrNoRows {
		log.Printf("[GetConversationByParticipants] Aucune conversation trouvée entre %d et %d", creatorID, subscriberID)
		return 0, nil
	}
	if err != nil {
		log.Printf("[GetConversationByParticipants][ERREUR] Échec de la sélection de conversation entre %d et %d : %v", creatorID, subscriberID, err)
		return 0, fmt.Errorf("failed to select conversation: %w", err)
	}

	log.Printf("[GetConversationByParticipants] Conversation trouvée, ID: %d", convID)
	return convID, nil
}

func IsUserInConversation(conversationID, userID int64) (bool, error) {
	log.Printf("[IsUserInConversation] Vérification de la participation de l'utilisateur %d à la conversation %d", userID, conversationID)

	var count int
	err := database.DB.QueryRow(`
        SELECT COUNT(*) FROM conversations
        WHERE id = $1 AND (creator_id = $2 OR subscriber_id = $2)
    `, conversationID, userID).Scan(&count)
	if err != nil {
		log.Printf("[IsUserInConversation][ERREUR] Échec de la vérification de la participation de l'utilisateur %d à la conversation %d : %v", userID, conversationID, err)
		return false, fmt.Errorf("failed to check participant: %w", err)
	}

	log.Printf("[IsUserInConversation] L'utilisateur %d est dans la conversation %d : %t", userID, conversationID, count > 0)
	return count > 0, nil
}
