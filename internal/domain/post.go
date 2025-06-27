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
	
	// ===== NOUVEAUX CHAMPS UTILISATEUR =====
	// Ces champs sont remplis lors du JOIN avec la table users
	Username    string `json:"author_username,omitempty"`     // Nom d'utilisateur de l'auteur
	FirstName   string `json:"author_first_name,omitempty"`   // Prénom de l'auteur
	LastName    string `json:"author_last_name,omitempty"`    // Nom de famille de l'auteur
	AvatarUrl   string `json:"author_avatar_url,omitempty"`   // URL de l'avatar de l'auteur
	Bio         string `json:"author_bio,omitempty"`          // Bio de l'auteur
	Role        string `json:"author_role,omitempty"`         // Rôle de l'auteur (creator, subscriber, etc.)
	
	// ===== COMPTEURS =====
	LikesCount    int `json:"likes_count,omitempty"`    // Nombre de likes sur ce post
	CommentsCount int `json:"comments_count,omitempty"` // Nombre de commentaires sur ce post
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
		
		// ===== INITIALISATION DES COMPTEURS =====
		LikesCount:    0,
		CommentsCount: 0,
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

// GetAuthorDisplayName retourne le nom d'affichage de l'auteur
func (p *Post) GetAuthorDisplayName() string {
	if p.Username != "" {
		return p.Username
	}
	fullName := p.FirstName + " " + p.LastName
	if fullName != " " {
		return fullName
	}
	return "Utilisateur " + string(rune(p.UserID))
}

// GetAuthorFullName retourne le nom complet de l'auteur
func (p *Post) GetAuthorFullName() string {
	return p.FirstName + " " + p.LastName
}

// IsFromCreator vérifie si le post vient d'un créateur
func (p *Post) IsFromCreator() bool {
	return p.Role == "creator"
}

// GetAvatarUrlWithFallback retourne l'URL de l'avatar avec un fallback
func (p *Post) GetAvatarUrlWithFallback() string {
	if p.AvatarUrl != "" {
		return p.AvatarUrl
	}
	// Fallback avec pravatar basé sur le username ou userID
	if p.Username != "" {
		return "https://i.pravatar.cc/150?u=" + p.Username
	}
	return "https://i.pravatar.cc/150?u=" + string(rune(p.UserID))
}