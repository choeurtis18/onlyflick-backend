package repository

import (
	"fmt"
	"log"
	"onlyflick/internal/database"
	"onlyflick/internal/domain"
)

// Subscribe permet à un utilisateur de s'abonner à un créateur.
// Retourne une erreur si l'utilisateur tente de s'abonner à lui-même ou si la requête échoue.
func Subscribe(subscriberID, creatorID int64) error {
	if subscriberID == creatorID {
		log.Printf("[Subscribe] L'utilisateur %d a tenté de s'abonner à lui-même.", subscriberID)
		return fmt.Errorf("vous ne pouvez pas vous abonner à vous-même")
	}

	query := `
		INSERT INTO subscriptions (subscriber_id, creator_id)
		VALUES ($1, $2)
		ON CONFLICT (subscriber_id, creator_id) DO NOTHING;
	`
	_, err := database.DB.Exec(query, subscriberID, creatorID)
	if err != nil {
		log.Printf("[Subscribe] Erreur lors de l'abonnement de %d à %d : %v", subscriberID, creatorID, err)
		return err
	}
	log.Printf("[Subscribe] L'utilisateur %d s'est abonné à %d.", subscriberID, creatorID)
	return nil
}

// Unsubscribe permet à un utilisateur de se désabonner d'un créateur.
// Retourne une erreur si la requête échoue.
func Unsubscribe(subscriberID, creatorID int64) error {
	query := `
		DELETE FROM subscriptions
		WHERE subscriber_id = $1 AND creator_id = $2;
	`
	_, err := database.DB.Exec(query, subscriberID, creatorID)
	if err != nil {
		log.Printf("[Unsubscribe] Erreur lors du désabonnement de %d à %d : %v", subscriberID, creatorID, err)
		return err
	}
	log.Printf("[Unsubscribe] L'utilisateur %d s'est désabonné de %d.", subscriberID, creatorID)
	return nil
}

// IsSubscribed vérifie si un utilisateur est abonné à un créateur.
// Retourne true si l'abonnement existe, false sinon.
func IsSubscribed(subscriberID, creatorID int64) (bool, error) {
	query := `
		SELECT EXISTS (
			SELECT 1 FROM subscriptions
			WHERE subscriber_id = $1 AND creator_id = $2
		);
	`
	var exists bool
	err := database.DB.QueryRow(query, subscriberID, creatorID).Scan(&exists)
	if err != nil {
		log.Printf("[IsSubscribed] Erreur lors de la vérification de l'abonnement de %d à %d : %v", subscriberID, creatorID, err)
		return false, err
	}
	log.Printf("[IsSubscribed] L'utilisateur %d est-il abonné à %d ? %v", subscriberID, creatorID, exists)
	return exists, nil
}

// ListMySubscriptions retourne la liste des abonnements d'un utilisateur.
// Retourne une slice de Subscription ou une erreur.
func ListMySubscriptions(subscriberID int64) ([]domain.Subscription, error) {
	query := `
		SELECT id, subscriber_id, creator_id, created_at
		FROM subscriptions
		WHERE subscriber_id = $1
		ORDER BY created_at DESC;
	`
	rows, err := database.DB.Query(query, subscriberID)
	if err != nil {
		log.Printf("[ListMySubscriptions] Erreur lors de la récupération des abonnements pour %d : %v", subscriberID, err)
		return nil, err
	}
	defer rows.Close()

	var subscriptions []domain.Subscription
	for rows.Next() {
		var s domain.Subscription
		if err := rows.Scan(&s.ID, &s.SubscriberID, &s.CreatorID, &s.CreatedAt); err != nil {
			log.Printf("[ListMySubscriptions] Erreur lors du scan d'un abonnement : %v", err)
			return nil, err
		}
		subscriptions = append(subscriptions, s)
	}
	log.Printf("[ListMySubscriptions] %d abonnements trouvés pour l'utilisateur %d.", len(subscriptions), subscriberID)
	return subscriptions, nil
}
