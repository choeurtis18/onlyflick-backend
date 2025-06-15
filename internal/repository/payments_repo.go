package repository

import (
	"fmt"
	"log"
	"onlyflick/internal/database"
	"onlyflick/internal/domain"
	"time"
)

// CreatePayment enregistre un paiement effectué pour un abonnement.
func CreatePayment(subscriptionID int64, stripePaymentID, payerID string, startAt, endAt time.Time, amount int, status string) (*domain.Payment, error) {
	payment := &domain.Payment{
		SubscriptionID:  subscriptionID,
		StripePaymentID: stripePaymentID,
		PayerID:         payerID,
		StartAt:         startAt,
		EndAt:           endAt,
		Amount:          amount,
		Status:          status,
	}

	// Insertion du paiement dans la base de données
	err := database.DB.QueryRow(`
		INSERT INTO payments (subscription_id, stripe_payment_id, payer_id, start_at, end_at, amount, status, created_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7, NOW())
		RETURNING id, created_at
	`, payment.SubscriptionID, payment.StripePaymentID, payment.PayerID, payment.StartAt, payment.EndAt, payment.Amount, payment.Status).Scan(&payment.ID, &payment.CreatedAt)
	if err != nil {
		log.Printf("[CreatePayment] Erreur lors de l'enregistrement du paiement : %v", err)
		return nil, fmt.Errorf("[CreatePayment] Erreur d'enregistrement du paiement : %w", err)
	}

	log.Printf("[CreatePayment] Paiement enregistré avec succès pour l'abonnement %d, montant %d", subscriptionID, amount)
	return payment, nil
}

// GetPaymentsBySubscriptionID récupère tous les paiements associés à un abonnement donné.
func GetPaymentsBySubscriptionID(subscriptionID int64) ([]domain.Payment, error) {
	rows, err := database.DB.Query(`
		SELECT id, subscription_id, stripe_payment_id, payer_id, start_at, end_at, amount, status, created_at
		FROM payments
		WHERE subscription_id = $1
		ORDER BY created_at DESC
	`, subscriptionID)
	if err != nil {
		log.Printf("[GetPaymentsBySubscriptionID] Erreur lors de la récupération des paiements pour l'abonnement %d : %v", subscriptionID, err)
		return nil, err
	}
	defer rows.Close()

	var payments []domain.Payment
	for rows.Next() {
		var p domain.Payment
		if err := rows.Scan(&p.ID, &p.SubscriptionID, &p.StripePaymentID, &p.PayerID, &p.StartAt, &p.EndAt, &p.Amount, &p.Status, &p.CreatedAt); err != nil {
			log.Printf("[GetPaymentsBySubscriptionID] Erreur lors du scan d'un paiement : %v", err)
			return nil, err
		}
		payments = append(payments, p)
	}

	return payments, nil
}
