// Package domain contient les structures de données principales du domaine.
package domain

import (
	"log"
	"time"
)

// Like représente un "like" d'un utilisateur sur un post.
// UserID : identifiant de l'utilisateur ayant liké.
// PostID : identifiant du post liké.
// CreatedAt : date et heure du like.
type Like struct {
	UserID    int64     `json:"user_id"`
	PostID    int64     `json:"post_id"`
	CreatedAt time.Time `json:"created_at"`
}

// NewLike crée une nouvelle instance de Like et log l'opération.
func NewLike(userID, postID int64) *Like {
	like := &Like{
		UserID:    userID,
		PostID:    postID,
		CreatedAt: time.Now(),
	}
	log.Printf("Nouveau like créé : utilisateur %d a liké le post %d à %s", userID, postID, like.CreatedAt.Format(time.RFC3339))
	return like
}
