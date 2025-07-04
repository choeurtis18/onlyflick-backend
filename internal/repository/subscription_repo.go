// internal/repository/subscription_repo.go
package repository

import (
	"database/sql"
	"fmt"
	"log"
	"onlyflick/internal/database"
	"onlyflick/internal/domain"
	"os"
	"time"

	"github.com/stripe/stripe-go"
	"github.com/stripe/stripe-go/paymentintent"
)

// ===== STRUCTURES POUR LES ABONNEMENTS =====

// Subscription représente un abonnement (compatible avec domain.Subscription)
type Subscription struct {
	ID           int64     `json:"id"`
	SubscriberID int64     `json:"subscriber_id"`
	CreatorID    int64     `json:"creator_id"`
	Status       bool      `json:"status"`
	CreatedAt    time.Time `json:"created_at"`
	EndAt        time.Time `json:"end_at"`
	UpdatedAt    time.Time `json:"updated_at"`
}

// ===== MÉTHODES POUR LES LISTES D'ABONNEMENTS =====

// GetUserFollowers récupère la liste des abonnés d'un utilisateur (créateur)
func GetUserFollowers(creatorID int64) ([]Subscription, error) {
	log.Printf("[GetUserFollowers] Récupération des abonnés pour le créateur %d", creatorID)

	var subscriptions []Subscription

	query := `
		SELECT id, subscriber_id, creator_id, status, created_at, end_at, created_at as updated_at
		FROM subscriptions 
		WHERE creator_id = $1 AND status = true
		ORDER BY created_at DESC
	`

	rows, err := database.DB.Query(query, creatorID)
	if err != nil {
		log.Printf("[GetUserFollowers][ERROR] Erreur requête: %v", err)
		return nil, err
	}
	defer rows.Close()

	for rows.Next() {
		var sub Subscription
		err := rows.Scan(
			&sub.ID,
			&sub.SubscriberID,
			&sub.CreatorID,
			&sub.Status,
			&sub.CreatedAt,
			&sub.EndAt,
			&sub.UpdatedAt,
		)
		if err != nil {
			log.Printf("[GetUserFollowers][ERROR] Erreur scan: %v", err)
			continue
		}
		subscriptions = append(subscriptions, sub)
	}

	if err = rows.Err(); err != nil {
		log.Printf("[GetUserFollowers][ERROR] Erreur rows: %v", err)
		return nil, err
	}

	log.Printf("[GetUserFollowers] %d abonnés trouvés pour le créateur %d", len(subscriptions), creatorID)
	return subscriptions, nil
}

// GetUserFollowing récupère la liste des abonnements d'un utilisateur
func GetUserFollowing(subscriberID int64) ([]Subscription, error) {
	log.Printf("[GetUserFollowing] Récupération des abonnements pour l'utilisateur %d", subscriberID)

	var subscriptions []Subscription

	query := `
		SELECT id, subscriber_id, creator_id, status, created_at, end_at, created_at as updated_at
		FROM subscriptions 
		WHERE subscriber_id = $1 AND status = true
		ORDER BY created_at DESC
	`

	rows, err := database.DB.Query(query, subscriberID)
	if err != nil {
		log.Printf("[GetUserFollowing][ERROR] Erreur requête: %v", err)
		return nil, err
	}
	defer rows.Close()

	for rows.Next() {
		var sub Subscription
		err := rows.Scan(
			&sub.ID,
			&sub.SubscriberID,
			&sub.CreatorID,
			&sub.Status,
			&sub.CreatedAt,
			&sub.EndAt,
			&sub.UpdatedAt,
		)
		if err != nil {
			log.Printf("[GetUserFollowing][ERROR] Erreur scan: %v", err)
			continue
		}
		subscriptions = append(subscriptions, sub)
	}

	if err = rows.Err(); err != nil {
		log.Printf("[GetUserFollowing][ERROR] Erreur rows: %v", err)
		return nil, err
	}

	log.Printf("[GetUserFollowing] %d abonnements trouvés pour l'utilisateur %d", len(subscriptions), subscriberID)
	return subscriptions, nil
}

// ===== MÉTHODES DE GESTION DES ABONNEMENTS =====

// Subscribe permet à un utilisateur de s'abonner à un créateur.
// Retourne l'abonnement créé ou une erreur.
func Subscribe(subscriberID, creatorID int64) (*Subscription, error) {
	if subscriberID == creatorID {
		log.Printf("[Subscribe] L'utilisateur %d a tenté de s'abonner à lui-même.", subscriberID)
		return nil, fmt.Errorf("vous ne pouvez pas vous abonner à vous-même")
	}

	// Vérifier qu'il n'y a pas déjà un abonnement actif
	existingSubscription, err := GetActiveSubscription(subscriberID, creatorID)
	if err != nil {
		return nil, err
	}
	if existingSubscription != nil && existingSubscription.Status {
		log.Printf("[Subscribe] Abonnement déjà existant et actif: %d", existingSubscription.ID)
		// Convertir domain.Subscription vers notre structure
		return &Subscription{
			ID:           existingSubscription.ID,
			SubscriberID: existingSubscription.SubscriberID,
			CreatorID:    existingSubscription.CreatorID,
			Status:       existingSubscription.Status,
			CreatedAt:    existingSubscription.CreatedAt,
			EndAt:        existingSubscription.EndAt,
			UpdatedAt:    existingSubscription.CreatedAt,
		}, nil
	}

	// Créer un nouvel abonnement
	var subscription Subscription
	query := `
		INSERT INTO subscriptions (subscriber_id, creator_id, created_at, end_at, status)
		VALUES ($1, $2, NOW(), NOW() + INTERVAL '1 month', TRUE)
		RETURNING id, subscriber_id, creator_id, status, created_at, end_at, created_at
	`
	
	err = database.DB.QueryRow(query, subscriberID, creatorID).Scan(
		&subscription.ID,
		&subscription.SubscriberID,
		&subscription.CreatorID,
		&subscription.Status,
		&subscription.CreatedAt,
		&subscription.EndAt,
		&subscription.UpdatedAt,
	)
	if err != nil {
		log.Printf("[Subscribe] erreur lors de l'abonnement de %d à %d : %v", subscriberID, creatorID, err)
		return nil, err
	}

	log.Printf("[Subscribe] L'utilisateur %d s'est abonné à %d, abonnement ID: %d", subscriberID, creatorID, subscription.ID)
	return &subscription, nil
}

// Unsubscribe permet à un utilisateur de se désabonner d'un créateur.
func Unsubscribe(subscriberID, creatorID int64) error {
	log.Printf("[Unsubscribe] Désabonnement %d -> %d", subscriberID, creatorID)

	query := `
		UPDATE subscriptions
		SET status = FALSE
		WHERE subscriber_id = $1 AND creator_id = $2 AND status = TRUE
	`

	result, err := database.DB.Exec(query, subscriberID, creatorID)
	if err != nil {
		log.Printf("[Unsubscribe][ERROR] Erreur désabonnement: %v", err)
		return err
	}

	rowsAffected, err := result.RowsAffected()
	if err != nil {
		log.Printf("[Unsubscribe][ERROR] Erreur vérification: %v", err)
		return err
	}

	if rowsAffected == 0 {
		log.Printf("[Unsubscribe] Aucun abonnement actif trouvé pour désactiver")
		return nil // Pas d'erreur, mais rien n'a été modifié
	}

	log.Printf("[Unsubscribe] Désabonnement réussi: %d lignes modifiées", rowsAffected)
	return nil
}

// IsSubscribed vérifie si un utilisateur est abonné à un créateur.
func IsSubscribed(subscriberID, creatorID int64) (bool, error) {
	query := `
		SELECT EXISTS (
			SELECT 1 FROM subscriptions
			WHERE subscriber_id = $1 AND creator_id = $2 AND status = TRUE
		);
	`
	var exists bool
	err := database.DB.QueryRow(query, subscriberID, creatorID).Scan(&exists)
	if err != nil {
		log.Printf("[IsSubscribed] erreur lors de la vérification de l'abonnement de %d à %d : %v", subscriberID, creatorID, err)
		return false, err
	}
	log.Printf("[IsSubscribed] L'utilisateur %d est-il abonné à %d ? %v", subscriberID, creatorID, exists)
	return exists, nil
}

// GetActiveSubscription récupère l'abonnement actif ou inactif d'un utilisateur pour un créateur donné.
func GetActiveSubscription(subscriberID, creatorID int64) (*domain.Subscription, error) {
	log.Printf("[GetActiveSubscription] Vérification abonnement %d -> %d", subscriberID, creatorID)

	var subscription domain.Subscription
	query := `
		SELECT id, subscriber_id, creator_id, created_at, end_at, status
		FROM subscriptions
		WHERE subscriber_id = $1 AND creator_id = $2
		ORDER BY created_at DESC
		LIMIT 1
	`

	err := database.DB.QueryRow(query, subscriberID, creatorID).Scan(
		&subscription.ID, 
		&subscription.SubscriberID, 
		&subscription.CreatorID, 
		&subscription.CreatedAt, 
		&subscription.EndAt, 
		&subscription.Status,
	)
	if err != nil {
		if err == sql.ErrNoRows {
			log.Printf("[GetActiveSubscription] Aucun abonnement trouvé %d -> %d", subscriberID, creatorID)
			return nil, nil
		}
		log.Printf("[GetActiveSubscription][ERROR] Erreur: %v", err)
		return nil, err
	}

	log.Printf("[GetActiveSubscription] Abonnement trouvé: %d (status: %v)", subscription.ID, subscription.Status)
	return &subscription, nil
}

// ReactivateSubscription réactive un abonnement si la date de fin est supérieure à la date actuelle
func ReactivateSubscription(subscriptionID int64, today time.Time) error {
	log.Printf("[ReactivateSubscription] Réactivation abonnement %d", subscriptionID)

	// Récupérer l'abonnement
	var subscription domain.Subscription
	err := database.DB.QueryRow(`
		SELECT id, subscriber_id, creator_id, end_at, status
		FROM subscriptions
		WHERE id = $1
	`, subscriptionID).Scan(&subscription.ID, &subscription.SubscriberID, &subscription.CreatorID, &subscription.EndAt, &subscription.Status)
	if err != nil {
		log.Printf("[ReactivateSubscription] erreur lors de la récupération de l'abonnement %d : %v", subscriptionID, err)
		return fmt.Errorf("erreur lors de la récupération de l'abonnement")
	}

	// Si l'abonnement est déjà actif et que la date de fin est dans le futur, aucune action n'est nécessaire
	if subscription.Status && subscription.EndAt.After(today) {
		log.Printf("[ReactivateSubscription] Abonnement %d déjà actif, aucune action requise", subscriptionID)
		return nil
	}

	// Si l'abonnement est inactif mais que la date de fin est dans le futur, on réactive l'abonnement
	if !subscription.Status && subscription.EndAt.After(today) {
		_, err = database.DB.Exec(`
			UPDATE subscriptions
			SET status = true
			WHERE id = $1
		`, subscriptionID)
		if err != nil {
			log.Printf("[ReactivateSubscription] erreur lors de la réactivation de l'abonnement %d : %v", subscriptionID, err)
			return fmt.Errorf("erreur lors de la réactivation de l'abonnement")
		}

		log.Printf("[ReactivateSubscription] Abonnement %d réactivé avec succès", subscriptionID)
		return nil
	}

	// Si l'abonnement est inactif et que la date de fin est dans le passé, on doit procéder à un paiement
	stripe.Key = os.Getenv("STRIPE_SECRET_KEY")

	// Créer un PaymentIntent via Stripe
	intentParams := &stripe.PaymentIntentParams{
		Amount:   stripe.Int64(499), // Montant en centimes (499 = 4.99€)
		Currency: stripe.String(string(stripe.CurrencyEUR)),
	}

	intent, err := paymentintent.New(intentParams)
	if err != nil {
		log.Printf("[ReactivateSubscription] Erreur Stripe lors de la création du PaymentIntent : %v", err)
		return fmt.Errorf("erreur de paiement Stripe")
	}

	// Ajouter Metadata après la création du PaymentIntent
	intent.Metadata = map[string]string{"subscription_id": fmt.Sprintf("%d", subscriptionID)}

	// Enregistrer le paiement dans la base de données
	_, err = CreatePayment(subscriptionID, intent.ID, fmt.Sprintf("%d", subscription.SubscriberID), today, today.AddDate(0, 1, 0), 499, "succeeded")
	if err != nil {
		log.Printf("[ReactivateSubscription] erreur d'enregistrement du paiement : %v", err)
		return fmt.Errorf("erreur d'enregistrement du paiement")
	}

	// Prolonger l'abonnement de 1 mois
	_, err = database.DB.Exec(`
		UPDATE subscriptions
		SET end_at = $1, status = true
		WHERE id = $2
	`, today.AddDate(0, 1, 0), subscriptionID)
	if err != nil {
		log.Printf("[ReactivateSubscription] erreur lors de la mise à jour de l'abonnement %d : %v", subscriptionID, err)
		return fmt.Errorf("erreur lors de la mise à jour de l'abonnement")
	}

	log.Printf("[ReactivateSubscription] Abonnement %d réactivé avec succès et payé", subscriptionID)
	return nil
}

// UpdateSubscriptionEndDate met à jour la date de fin d'un abonnement
func UpdateSubscriptionEndDate(subscriptionID int64, newEndDate time.Time) (int64, error) {
	log.Printf("[UpdateSubscriptionEndDate] Mise à jour date fin abonnement %d", subscriptionID)

	query := `
		UPDATE subscriptions
		SET end_at = $1
		WHERE id = $2
		RETURNING id;
	`
	var updatedID int64
	err := database.DB.QueryRow(query, newEndDate, subscriptionID).Scan(&updatedID)
	if err != nil {
		log.Printf("[UpdateSubscriptionEndDate] erreur lors de la mise à jour de l'abonnement %d : %v", subscriptionID, err)
		return 0, err
	}

	log.Printf("[UpdateSubscriptionEndDate] Date de fin de l'abonnement %d mise à jour avec succès", updatedID)
	return updatedID, nil
}

// ListMySubscriptions retourne la liste des abonnements d'un utilisateur.
func ListMySubscriptions(subscriberID int64) ([]domain.Subscription, error) {
	log.Printf("[ListMySubscriptions] Récupération abonnements pour utilisateur %d", subscriberID)

	query := `
		SELECT id, subscriber_id, creator_id, created_at, end_at, status
		FROM subscriptions
		WHERE subscriber_id = $1
		ORDER BY created_at DESC;
	`
	rows, err := database.DB.Query(query, subscriberID)
	if err != nil {
		log.Printf("[ListMySubscriptions] erreur lors de la récupération des abonnements pour %d : %v", subscriberID, err)
		return nil, err
	}
	defer rows.Close()

	var subscriptions []domain.Subscription
	for rows.Next() {
		var s domain.Subscription
		if err := rows.Scan(&s.ID, &s.SubscriberID, &s.CreatorID, &s.CreatedAt, &s.EndAt, &s.Status); err != nil {
			log.Printf("[ListMySubscriptions] erreur lors du scan d'un abonnement : %v", err)
			return nil, err
		}
		subscriptions = append(subscriptions, s)
	}
	
	if err = rows.Err(); err != nil {
		log.Printf("[ListMySubscriptions] erreur rows: %v", err)
		return nil, err
	}

	log.Printf("[ListMySubscriptions] %d abonnements trouvés pour l'utilisateur %d.", len(subscriptions), subscriberID)
	return subscriptions, nil
}