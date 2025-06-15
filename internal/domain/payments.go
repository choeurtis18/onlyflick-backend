package domain

import "time"

// Payment représente un paiement effectué pour un abonnement.
type Payment struct {
	ID              int64     `json:"id"`                // Identifiant unique du paiement
	SubscriptionID  int64     `json:"subscription_id"`   // Identifiant de l'abonnement
	StripePaymentID string    `json:"stripe_payment_id"` // ID de paiement Stripe
	PayerID         string    `json:"payer_id"`          // Identifiant de l'utilisateur qui a payé
	StartAt         time.Time `json:"start_at"`          // Date de début de l'abonnement
	EndAt           time.Time `json:"end_at"`            // Date de fin de l'abonnement
	Amount          int       `json:"amount"`            // Montant payé (en centimes)
	Status          string    `json:"status"`            // Statut du paiement (succeeded, failed, etc.)
	CreatedAt       time.Time `json:"created_at"`        // Date de création du paiement
}
