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
	FirstName string    `json:"first_name"` // Prénom de l'utilisateur
	LastName  string    `json:"last_name"`  // Nom de famille de l'utilisateur
	Email     string    `json:"email"`      // Adresse email de l'utilisateur
	Password  string    `json:"-"`          // Mot de passe hashé (non exposé en JSON)
	Role      Role      `json:"role"`       // Rôle de l'utilisateur
	CreatedAt time.Time `json:"created_at"` // Date de création du compte
	AvatarURL string    `json:"avatar_url"`      // URL de l'avatar
	Bio       string    `json:"bio"`             // Bio du profil  
	Username  string    `json:"username"`        // Username unique
	UpdatedAt time.Time `json:"updated_at"` 	// Date de la dernière mise à jour du profil
}
