// Package domain contient les structures principales du domaine métier.
package domain

import (
	"time"
)

// Report représente un signalement effectué par un utilisateur sur un contenu.
type Report struct {
	ID          int64      `json:"id"`                   // Identifiant unique du signalement
	UserID      int64      `json:"user_id"`              // Identifiant de l'utilisateur ayant signalé
	ContentType string     `json:"content_type"`         // Type de contenu signalé (ex: "post", "commentaire")
	ContentID   int64      `json:"content_id"`           // Identifiant du contenu signalé
	Reason      string     `json:"reason"`               // Raison du signalement
	Status      string     `json:"status"`               // Statut du signalement (ex: "en attente", "traité")
	CreatedAt   time.Time  `json:"created_at"`           // Date de création du signalement
	ProcessedAt *time.Time `json:"updated_at,omitempty"` // Date de traitement du signalement (optionnelle)
}
