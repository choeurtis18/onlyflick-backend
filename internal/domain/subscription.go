package domain

import "time"

// Subscription représente un abonnement d'un utilisateur (Subscriber) à un créateur (Creator).
type Subscription struct {
	ID              int64     `json:"id"`                // Identifiant unique de l'abonnement
	SubscriberID    int64     `json:"subscriber_id"`     // Identifiant de l'utilisateur qui s'abonne
	CreatorID       int64     `json:"creator_id"`        // Identifiant du créateur auquel on s'abonne
	CreatedAt       time.Time `json:"created_at"`        // Date de création de l'abonnement
	EndAt           time.Time `json:"end_at"`            // Date de fin de l'abonnement
	Status          bool      `json:"status"`            // Statut du paiement (true = actif, false = inactif)
	PaymentIntentID string    `json:"payment_intent_id"` // Stripe Payment Intent ID
}
