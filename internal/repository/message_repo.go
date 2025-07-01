package repository

import (
	"fmt"
	"log"
	"onlyflick/internal/database"
	"onlyflick/internal/domain"
)

// CreateMessage insère un nouveau message dans la base de données et retourne le message créé.
func CreateMessage(conversationID, senderID int64, content string) (*domain.Message, error) {
	msg := &domain.Message{
		ConversationID: conversationID,
		SenderID:       senderID,
		Content:        content,
	}

	err := database.DB.QueryRow(`
		INSERT INTO messages (conversation_id, sender_id, content, created_at)
		VALUES ($1, $2, $3, NOW())
		RETURNING id, created_at
	`, msg.ConversationID, msg.SenderID, msg.Content).Scan(&msg.ID, &msg.CreatedAt)

	if err != nil {
		log.Printf("[CreateMessage][ERREUR] Échec de l'insertion du message : %v", err)
		return nil, fmt.Errorf("[CreateMessage] Erreur insertion message : %w", err)
	}

	log.Printf("[CreateMessage] Message créé avec succès, ID: %d", msg.ID)
	return msg, nil
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

// ConversationWithDetails représente une conversation enrichie avec les détails utilisateur et message
type ConversationWithDetails struct {
	ID        int64  `json:"id"`
	User1ID   int64  `json:"user1_id"`
	User2ID   int64  `json:"user2_id"`
	CreatedAt string `json:"created_at"`
	UpdatedAt string `json:"updated_at"`
	
	// Informations sur l'autre utilisateur
	OtherUserUsername  *string `json:"other_user_username"`
	OtherUserFirstName *string `json:"other_user_first_name"`
	OtherUserLastName  *string `json:"other_user_last_name"`
	OtherUserAvatar    *string `json:"other_user_avatar"`
	
	// Dernier message
	LastMessage *MessageWithSender `json:"last_message"`
	UnreadCount int                `json:"unread_count"`
}

// MessageWithSender représente un message avec les infos de l'expéditeur
type MessageWithSender struct {
	ID             int64  `json:"id"`
	ConversationID int64  `json:"conversation_id"`
	SenderID       int64  `json:"sender_id"`
	Content        string `json:"content"`
	CreatedAt      string `json:"created_at"`
	UpdatedAt      string `json:"updated_at"`
	
	// Informations sur l'expéditeur
	SenderUsername  *string `json:"sender_username"`
	SenderFirstName *string `json:"sender_first_name"`
	SenderLastName  *string `json:"sender_last_name"`
	SenderAvatar    *string `json:"sender_avatar"`
}

// GetConversationsForUser récupère toutes les conversations d'un utilisateur avec détails complets
func GetConversationsForUser(userID int64) ([]ConversationWithDetails, error) {
	log.Printf("[GetConversationsForUser] Récupération des conversations pour l'utilisateur %d", userID)

	// Requête corrigée avec les vrais noms de colonnes de votre table users
	query := `
		SELECT 
			c.id,
			c.creator_id as user1_id,
			c.subscriber_id as user2_id,
			c.created_at,
			c.created_at as updated_at,  -- Utilise created_at comme updated_at pour la compatibilité
			
			-- Informations sur l'autre utilisateur (avec les vrais noms de colonnes)
			CASE 
				WHEN c.creator_id = $1 THEN u_subscriber.username
				ELSE u_creator.username
			END as other_user_username,
			CASE 
				WHEN c.creator_id = $1 THEN u_subscriber.first_name
				ELSE u_creator.first_name
			END as other_user_first_name,
			CASE 
				WHEN c.creator_id = $1 THEN u_subscriber.last_name
				ELSE u_creator.last_name
			END as other_user_last_name,
			CASE 
				WHEN c.creator_id = $1 THEN u_subscriber.avatar_url
				ELSE u_creator.avatar_url
			END as other_user_avatar,
			
			-- Dernier message (si il existe)
			lm.id as last_message_id,
			lm.sender_id as last_message_sender_id,
			lm.content as last_message_content,
			lm.created_at as last_message_created_at,
			lm.created_at as last_message_updated_at,  -- Utilise created_at comme updated_at
			
			-- Informations sur l'expéditeur du dernier message (avec les vrais noms de colonnes)
			u_sender.username as last_message_sender_username,
			u_sender.first_name as last_message_sender_first_name,
			u_sender.last_name as last_message_sender_last_name,
			u_sender.avatar_url as last_message_sender_avatar,
			
			-- Nombre de messages (simplifié)
			COALESCE(msg_count.count, 0) as unread_count
			
		FROM conversations c
		
		-- Jointure avec les utilisateurs créateurs
		LEFT JOIN users u_creator ON c.creator_id = u_creator.id
		
		-- Jointure avec les utilisateurs abonnés
		LEFT JOIN users u_subscriber ON c.subscriber_id = u_subscriber.id
		
		-- Jointure avec le dernier message (requête simplifiée)
		LEFT JOIN LATERAL (
			SELECT id, sender_id, content, created_at
			FROM messages 
			WHERE conversation_id = c.id
			ORDER BY created_at DESC
			LIMIT 1
		) lm ON true
		
		-- Jointure avec l'expéditeur du dernier message
		LEFT JOIN users u_sender ON lm.sender_id = u_sender.id
		
		-- Jointure pour compter les messages
		LEFT JOIN (
			SELECT conversation_id, COUNT(*) as count
			FROM messages 
			GROUP BY conversation_id
		) msg_count ON c.id = msg_count.conversation_id
		
		WHERE c.creator_id = $1 OR c.subscriber_id = $1
		ORDER BY COALESCE(lm.created_at, c.created_at) DESC
	`

	rows, err := database.DB.Query(query, userID)
	if err != nil {
		log.Printf("[GetConversationsForUser][ERREUR] Échec de la requête : %v", err)
		return nil, fmt.Errorf("failed to query conversations: %w", err)
	}
	defer rows.Close()

	var conversations []ConversationWithDetails
	for rows.Next() {
		var conv ConversationWithDetails
		var lastMsg *MessageWithSender
		
		// Variables pour scanner le dernier message (optionnel)
		var lastMsgID, lastMsgSenderID *int64
		var lastMsgContent, lastMsgCreatedAt, lastMsgUpdatedAt *string
		var lastMsgSenderUsername, lastMsgSenderFirstName, lastMsgSenderLastName, lastMsgSenderAvatar *string

		err := rows.Scan(
			&conv.ID,
			&conv.User1ID,
			&conv.User2ID,
			&conv.CreatedAt,
			&conv.UpdatedAt,
			&conv.OtherUserUsername,
			&conv.OtherUserFirstName,
			&conv.OtherUserLastName,
			&conv.OtherUserAvatar,
			&lastMsgID,
			&lastMsgSenderID,
			&lastMsgContent,
			&lastMsgCreatedAt,
			&lastMsgUpdatedAt,
			&lastMsgSenderUsername,
			&lastMsgSenderFirstName,
			&lastMsgSenderLastName,
			&lastMsgSenderAvatar,
			&conv.UnreadCount,
		)
		if err != nil {
			log.Printf("[GetConversationsForUser][ERREUR] Échec du scan : %v", err)
			continue
		}

		// Construire le dernier message s'il existe
		if lastMsgID != nil && lastMsgSenderID != nil && lastMsgContent != nil && lastMsgCreatedAt != nil {
			lastMsg = &MessageWithSender{
				ID:             *lastMsgID,
				ConversationID: conv.ID,
				SenderID:       *lastMsgSenderID,
				Content:        *lastMsgContent,
				CreatedAt:      *lastMsgCreatedAt,
				UpdatedAt:      *lastMsgUpdatedAt,
				SenderUsername:  lastMsgSenderUsername,
				SenderFirstName: lastMsgSenderFirstName,
				SenderLastName:  lastMsgSenderLastName,
				SenderAvatar:    lastMsgSenderAvatar,
			}
		}
		
		conv.LastMessage = lastMsg
		conversations = append(conversations, conv)
		
		// Debug pour voir ce qu'on récupère
		log.Printf("[GetConversationsForUser] Conversation %d : autre utilisateur = %v %v", 
			conv.ID, 
			conv.OtherUserUsername, 
			conv.OtherUserFirstName)
		if lastMsg != nil {
			log.Printf("[GetConversationsForUser] Dernier message : %s", lastMsg.Content)
		}
	}

	if err = rows.Err(); err != nil {
		log.Printf("[GetConversationsForUser][ERREUR] Erreur lors de l'itération : %v", err)
		return nil, fmt.Errorf("failed to iterate conversations: %w", err)
	}

	log.Printf("[GetConversationsForUser] %d conversations récupérées pour l'utilisateur %d", len(conversations), userID)
	return conversations, nil
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