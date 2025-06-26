package domain

import (
	"log"
	"time"
)

// Visibility définit la visibilité d'un post.
type Visibility string

const (
	// Public : le post est visible par tous.
	Public Visibility = "public"
	// SubscriberOnly : le post est réservé aux abonnés.
	SubscriberOnly Visibility = "subscriber"
)

// Post représente une publication effectuée par un utilisateur.
type Post struct {
	ID          int64      `json:"id"`
	UserID      int64      `json:"user_id"`
	Title       string     `json:"title"`
	Description string     `json:"description"`
	MediaURL    string     `json:"media_url"`
	FileID      string     `json:"file_id,omitempty"`
	Visibility  Visibility `json:"visibility"`
	CreatedAt   time.Time  `json:"created_at"`
	UpdatedAt   time.Time  `json:"updated_at"`
	ImageURL    string     `json:"image_url,omitempty"`
	VideoURL    string     `json:"video_url,omitempty"`
}


// NewPost crée un nouveau post et log l'opération.
func NewPost(userID int64, title, description, mediaURL, fileID string, visibility Visibility) *Post {
	post := &Post{
		UserID:      userID,
		Title:       title,
		Description: description,
		MediaURL:    mediaURL,
		FileID:      fileID,
		Visibility:  visibility,
		CreatedAt:   time.Now(),
		UpdatedAt:   time.Now(),
	}
	log.Printf("[INFO] Nouveau post créé par l'utilisateur %d : %s", userID, title)
	return post
}

// Update met à jour le post et log l'opération.
func (p *Post) Update(title, description string) {
	log.Printf("[INFO] Mise à jour du post %d : ancien titre='%s', nouveau titre='%s'", p.ID, p.Title, title)
	p.Title = title
	p.Description = description
	p.UpdatedAt = time.Now()
}
