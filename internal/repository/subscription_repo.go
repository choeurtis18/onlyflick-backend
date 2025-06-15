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

// Subscribe permet à un utilisateur de s'abonner à un créateur.
// Retourne l'ID de l'abonnement ou une erreur.
func Subscribe(subscriberID, creatorID int64) (int64, error) {
	if subscriberID == creatorID {
		log.Printf("[Subscribe] L'utilisateur %d a tenté de s'abonner à lui-même.", subscriberID)
		return 0, fmt.Errorf("vous ne pouvez pas vous abonner à vous-même")
	}

	// Créer un abonnement
	var subscriptionID int64
	query := `
		INSERT INTO subscriptions (subscriber_id, creator_id, created_at, end_at, status)
		VALUES ($1, $2, NOW(), NOW() + INTERVAL '1 month', TRUE)
		RETURNING id;
	`
	err := database.DB.QueryRow(query, subscriberID, creatorID).Scan(&subscriptionID)
	if err != nil {
		log.Printf("[Subscribe] erreur lors de l'abonnement de %d à %d : %v", subscriberID, creatorID, err)
		return 0, err
	}

	log.Printf("[Subscribe] L'utilisateur %d s'est abonné à %d, abonnement ID: %d", subscriberID, creatorID, subscriptionID)
	return subscriptionID, nil
}

// Unsubscribe permet à un utilisateur de se désabonner d'un créateur.
// Retourne une erreur si la requête échoue.
func Unsubscribe(subscriberID, creatorID int64) error {
	// Mise à jour du statut de l'abonnement à "canceled" au lieu de supprimer l'abonnement.
	query := `
		UPDATE subscriptions
		SET status = FALSE
		WHERE subscriber_id = $1 AND creator_id = $2 AND status = TRUE;
	`

	// Exécution de la mise à jour
	_, err := database.DB.Exec(query, subscriberID, creatorID)
	if err != nil {
		log.Printf("[Unsubscribe] erreur lors du désabonnement de %d à %d : %v", subscriberID, creatorID, err)
		return err
	}

	log.Printf("[Unsubscribe] L'utilisateur %d s'est désabonné du créateur %d.", subscriberID, creatorID)
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
		log.Printf("[IsSubscribed] erreur lors de la vérification de l'abonnement de %d à %d : %v", subscriberID, creatorID, err)
		return false, err
	}
	log.Printf("[IsSubscribed] L'utilisateur %d est-il abonné à %d ? %v", subscriberID, creatorID, exists)
	return exists, nil
}

// GetActiveSubscription récupère l'abonnement actif ou inactif d'un utilisateur pour un créateur donné.
func GetActiveSubscription(subscriberID, creatorID int64) (*domain.Subscription, error) {
	var subscription domain.Subscription
	query := `
		SELECT id, subscriber_id, creator_id, created_at, end_at, status
		FROM subscriptions
		WHERE subscriber_id = $1 AND creator_id = $2;
	`

	err := database.DB.QueryRow(query, subscriberID, creatorID).Scan(&subscription.ID, &subscription.SubscriberID, &subscription.CreatorID, &subscription.CreatedAt, &subscription.EndAt, &subscription.Status)
	if err != nil {
		if err == sql.ErrNoRows {
			// Pas d'abonnement trouvé
			return nil, nil
		}
		// Autre erreur de base de données
		log.Printf("[GetActiveSubscription] erreur lors de la récupération de l'abonnement : %v", err)
		return nil, err
	}

	return &subscription, nil
}

// ReactivateSubscription réactive un abonnement si la date de fin est supérieure à la date actuelle
// Sinon, elle procède à un paiement et prolonge l'abonnement d'un mois.
func ReactivateSubscription(subscriptionID int64, today time.Time) error {
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
	stripe.Key = os.Getenv("STRIPE_SECRET_KEY") // Mettre votre clé secrète Stripe ici

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

func UpdateSubscriptionEndDate(subscriptionID int64, newEndDate time.Time) (int64, error) {
	// Mettre à jour la date de fin de l'abonnement
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
// Retourne une slice de Subscription ou une erreur.
func ListMySubscriptions(subscriberID int64) ([]domain.Subscription, error) {
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
	log.Printf("[ListMySubscriptions] %d abonnements trouvés pour l'utilisateur %d.", len(subscriptions), subscriberID)
	return subscriptions, nil
}
