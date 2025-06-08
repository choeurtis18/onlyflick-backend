// Package domain contient les structures et types liés au domaine métier de l'application.
package domain

import (
	"time"
)

// CreatorRequestStatus représente le statut d'une demande de créateur.
type CreatorRequestStatus string

const (
	// CreatorRequestStatusPending indique que la demande est en attente de traitement.
	CreatorRequestStatusPending CreatorRequestStatus = "pending"
	// CreatorRequestStatusApproved indique que la demande a été approuvée.
	CreatorRequestStatusApproved CreatorRequestStatus = "approved"
	// CreatorRequestStatusRejected indique que la demande a été rejetée.
	CreatorRequestStatusRejected CreatorRequestStatus = "rejected"
)

// CreatorRequest représente une demande pour devenir créateur sur la plateforme.
type CreatorRequest struct {
	ID        int64                `json:"id"`         // Identifiant unique de la demande
	UserID    int64                `json:"user_id"`    // Identifiant de l'utilisateur ayant fait la demande
	Status    CreatorRequestStatus `json:"status"`     // Statut actuel de la demande
	CreatedAt time.Time            `json:"created_at"` // Date de création de la demande
	UpdatedAt time.Time            `json:"updated_at"` // Date de dernière mise à jour de la demande
}
