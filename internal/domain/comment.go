package domain

import (
	"log"
	"time"
)

// Comment représente un commentaire laissé par un utilisateur sur un post.
type Comment struct {
	ID        int64     `json:"id"`         // Identifiant unique du commentaire
	UserID    int64     `json:"user_id"`    // Identifiant de l'utilisateur ayant posté le commentaire
	PostID    int64     `json:"post_id"`    // Identifiant du post associé
	Content   string    `json:"content"`    // Contenu du commentaire
	CreatedAt time.Time `json:"created_at"` // Date de création du commentaire
	UpdatedAt time.Time `json:"updated_at"` // Date de dernière modification
}

// LogCommentInfo affiche les informations du commentaire dans les logs (en français).
func (c *Comment) LogCommentInfo() {
	log.Printf("Commentaire ID: %d | Utilisateur ID: %d | Post ID: %d | Créé le: %s | Modifié le: %s | Contenu: %s",
		c.ID, c.UserID, c.PostID, c.CreatedAt.Format(time.RFC3339), c.UpdatedAt.Format(time.RFC3339), c.Content)
}
