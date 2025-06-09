package repository

import (
	"fmt"
	"log"
	"onlyflick/internal/database"
	"onlyflick/internal/domain"
)

// CreateMessage insère un nouveau message dans la base de données.
func CreateMessage(msg *domain.Message) error {
	log.Printf("[CreateMessage] Création d'un message pour la conversation %d par l'utilisateur %d", msg.ConversationID, msg.SenderID)

	err := database.DB.QueryRow(`
		INSERT INTO messages (conversation_id, sender_id, content, created_at)
		VALUES ($1, $2, $3, NOW())
		RETURNING id, created_at
	`, msg.ConversationID, msg.SenderID, msg.Content).Scan(&msg.ID, &msg.CreatedAt)

	if err != nil {
		log.Printf("[CreateMessage][ERREUR] Échec de l'insertion du message : %v", err)
		return fmt.Errorf("[CreateMessage] Erreur insertion message : %w", err)
	}

	log.Printf("[CreateMessage] Message créé avec succès, ID: %d", msg.ID)
	return nil
}

// GetMessages récupère les messages avec pagination.
func GetMessages(conversationID int64, limit, offset int) ([]domain.Message, error) {
	log.Printf("[GetMessages] Récupération des messages pour la conversation %d avec limite %d et offset %d", conversationID, limit, offset)

	rows, err := database.DB.Query(`
		SELECT id, conversation_id, sender_id, content, created_at
		FROM messages
		WHERE conversation_id = $1
		ORDER BY created_at ASC
		LIMIT $2 OFFSET $3
	`, conversationID, limit, offset)
	if err != nil {
		log.Printf("[GetMessages][ERREUR] Échec de la requête pour récupérer les messages : %v", err)
		return nil, fmt.Errorf("failed to query messages: %w", err)
	}
	defer rows.Close()

	var messages []domain.Message
	for rows.Next() {
		var m domain.Message
		if err := rows.Scan(&m.ID, &m.ConversationID, &m.SenderID, &m.Content, &m.CreatedAt); err != nil {
			log.Printf("[GetMessages][ERREUR] Échec de la lecture d'un message : %v", err)
			return nil, fmt.Errorf("failed to scan message: %w", err)
		}
		messages = append(messages, m)
	}

	log.Printf("[GetMessages] %d messages récupérés pour la conversation %d", len(messages), conversationID)
	return messages, nil
}

// GetConversationsForUser récupère toutes les conversations d'un utilisateur.
func GetConversationsForUser(userID int64) ([]domain.Conversation, error) {
	log.Printf("[GetConversationsForUser] Récupération des conversations pour l'utilisateur %d", userID)

	rows, err := database.DB.Query(`
		SELECT id, creator_id, subscriber_id, created_at
		FROM conversations
		WHERE creator_id = $1 OR subscriber_id = $1
		ORDER BY created_at DESC
	`, userID)
	if err != nil {
		log.Printf("[GetConversationsForUser][ERREUR] Échec de la requête pour récupérer les conversations : %v", err)
		return nil, fmt.Errorf("[GetConversationsForUser] Erreur requête : %w", err)
	}
	defer rows.Close()

	var convs []domain.Conversation
	for rows.Next() {
		var c domain.Conversation
		if err := rows.Scan(&c.ID, &c.User1ID, &c.User2ID, &c.CreatedAt); err != nil {
			log.Printf("[GetConversationsForUser][ERREUR] Échec de la lecture d'une conversation : %v", err)
			return nil, fmt.Errorf("[GetConversationsForUser] Scan erreur : %w", err)
		}
		convs = append(convs, c)
	}

	log.Printf("[GetConversationsForUser] %d conversations récupérées pour l'utilisateur %d", len(convs), userID)
	return convs, nil
}

// GetMessagesForConversation retourne tous les messages d'une conversation accessible à l'utilisateur.
func GetMessagesForConversation(conversationID, userID int64) ([]domain.Message, error) {
	log.Printf("[GetMessagesForConversation] Récupération des messages pour la conversation %d pour l'utilisateur %d", conversationID, userID)

	var exists bool
	err := database.DB.QueryRow(`
		SELECT EXISTS (
			SELECT 1 FROM conversations
			WHERE id = $1 AND (creator_id = $2 OR subscriber_id = $2)
		)
	`, conversationID, userID).Scan(&exists)
	if err != nil || !exists {
		log.Printf("[GetMessagesForConversation][ERREUR] Conversation %d non trouvée pour l'utilisateur %d : %v", conversationID, userID, err)
		return nil, fmt.Errorf("[GetMessagesForConversation] Conversation non trouvée pour user %d : %w", userID, err)
	}

	rows, err := database.DB.Query(`
		SELECT id, conversation_id, sender_id, content, created_at
		FROM messages
		WHERE conversation_id = $1
		ORDER BY created_at ASC
	`, conversationID)
	if err != nil {
		log.Printf("[GetMessagesForConversation][ERREUR] Échec de la requête pour récupérer les messages : %v", err)
		return nil, fmt.Errorf("[GetMessagesForConversation] Requête échouée : %w", err)
	}
	defer rows.Close()

	var messages []domain.Message
	for rows.Next() {
		var m domain.Message
		if err := rows.Scan(&m.ID, &m.ConversationID, &m.SenderID, &m.Content, &m.CreatedAt); err != nil {
			log.Printf("[GetMessagesForConversation][ERREUR] Échec de la lecture d'un message : %v", err)
			return nil, fmt.Errorf("[GetMessagesForConversation] Scan échoué : %w", err)
		}
		messages = append(messages, m)
	}

	log.Printf("[GetMessagesForConversation] %d messages récupérés pour la conversation %d", len(messages), conversationID)
	return messages, nil
}
