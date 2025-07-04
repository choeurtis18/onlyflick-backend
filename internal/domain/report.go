// Package domain contient les structures principales du domaine métier.
package domain

import (
	"time"
)

// Report représente un signalement effectué par un utilisateur sur un contenu.
type Report struct {
	ID               int       `json:"id"`
	UserID           int       `json:"user_id"`
	ReporterUsername string    `json:"reporter_username"`
	ContentType      string    `json:"content_type"` // "post" ou "comment"
	ContentID        int       `json:"content_id"`
	Reason           string    `json:"reason"`
	Status           string    `json:"status"`
	CreatedAt        time.Time `json:"created_at"`
	ProcessedAt      time.Time `json:"updated_at"`

	// Enrichi dynamiquement selon le type
	ContentText     string  `json:"text"`
	ContentMediaURL *string `json:"image_url"`
}
