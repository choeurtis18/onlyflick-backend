package domain

import "time"

// Role représente le rôle d'un utilisateur dans l'application.
type Role string

const (
	RoleSubscriber Role = "subscriber" // Utilisateur abonné
	RoleCreator    Role = "creator"    // Créateur de contenu
	RoleAdmin      Role = "admin"      // Administrateur
)

// User représente un utilisateur de la plateforme.
type User struct {
	ID        int64     `json:"id"`         // Identifiant unique de l'utilisateur
	FirstName string    `json:"first_name"` // Prénom de l'utilisateur (données privées)
	LastName  string    `json:"last_name"`  // Nom de famille de l'utilisateur (données privées)
	Username  string    `json:"username"`   // Pseudo public de l'utilisateur (ex: @johndoe)
	Email     string    `json:"email"`      // Adresse e-mail de l'utilisateur
	Password  string    `json:"-"`          // Mot de passe hashé (non exposé en JSON)
	Role      Role      `json:"role"`       // Rôle de l'utilisateur
	AvatarURL string    `json:"avatar_url"` // URL de l'avatar de l'utilisateur
	Bio       string    `json:"bio"`        // Biographie de l'utilisateur
	CreatedAt time.Time `json:"created_at"` // Date de création du compte
	UpdatedAt time.Time `json:"updated_at"` // Date de dernière mise à jour
}

// IsCreator vérifie si l'utilisateur est un créateur.
func (u *User) IsCreator() bool {
	return u.Role == RoleCreator
}

// IsAdmin vérifie si l'utilisateur est un administrateur.
func (u *User) IsAdmin() bool {
	return u.Role == RoleAdmin
}

// IsSubscriber vérifie si l'utilisateur est un abonné.
func (u *User) IsSubscriber() bool {
	return u.Role == RoleSubscriber
}

// GetDisplayName retourne le nom d'affichage public (username avec @)
func (u *User) GetDisplayName() string {
	if u.Username != "" {
		return "@" + u.Username
	}
	// Fallback si pas de username (ne devrait pas arriver)
	return u.FirstName + " " + u.LastName
}

// GetFullName retourne le nom complet (privé, pour administration)
func (u *User) GetFullName() string {
	return u.FirstName + " " + u.LastName
}