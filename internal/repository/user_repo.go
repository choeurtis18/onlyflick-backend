package repository

import (
	"fmt"
	"log"
	"onlyflick/internal/database"
	"onlyflick/internal/domain"
	"onlyflick/pkg/utils"
)

// =========================
// Repository Utilisateur
// =========================

// Crée un nouvel utilisateur dans la base de données.
// Remplit également les champs ID et CreatedAt de l'utilisateur.
func CreateUser(user *domain.User) error {
	query := `
		INSERT INTO users (first_name, last_name, email, password, role)
		VALUES ($1, $2, $3, $4, $5)
		RETURNING id, created_at
	`
	log.Printf("[CreateUser] Création de l'utilisateur: %s %s, email: %s", user.FirstName, user.LastName, user.Email)
	err := database.DB.QueryRow(
		query,
		user.FirstName,
		user.LastName,
		user.Email,
		user.Password,
		user.Role,
	).Scan(&user.ID, &user.CreatedAt)

	if err != nil {
		log.Printf("[CreateUser][ERREUR] Impossible de créer l'utilisateur (%s): %v", user.Email, err)
	}
	return err
}

// Recherche un utilisateur par email (décrypté).
// Retourne l'utilisateur si trouvé, nil sinon.
func GetUserByEmail(email string) (*domain.User, error) {
	log.Printf("[GetUserByEmail] Recherche de l'utilisateur avec l'email: %s", email)
	rows, err := database.DB.Query(`SELECT id, first_name, last_name, email, password, role FROM users`)
	if err != nil {
		log.Printf("[GetUserByEmail][ERREUR] Erreur lors de la requête SQL: %v", err)
		return nil, fmt.Errorf("erreur lors de la requête des utilisateurs: %v", err)
	}
	defer rows.Close()

	for rows.Next() {
		var user domain.User
		if err := rows.Scan(&user.ID, &user.FirstName, &user.LastName, &user.Email, &user.Password, &user.Role); err != nil {
			log.Printf("[GetUserByEmail][ERREUR] Erreur lors du scan d'un utilisateur: %v", err)
			return nil, fmt.Errorf("erreur lors du scan d'un utilisateur: %v", err)
		}

		decryptedEmail, err := utils.Decrypt(user.Email)
		if err != nil {
			log.Printf("[GetUserByEmail][ERREUR] Erreur lors du décryptage de l'email: %v", err)
			return nil, fmt.Errorf("erreur lors du décryptage de l'email: %v", err)
		}

		if decryptedEmail == email {
			log.Printf("[GetUserByEmail] Utilisateur trouvé pour l'email: %s (ID: %d)", email, user.ID)
			return &user, nil
		}
	}

	if err := rows.Err(); err != nil {
		log.Printf("[GetUserByEmail][ERREUR] Erreur lors de l'itération des lignes: %v", err)
		return nil, fmt.Errorf("erreur lors de l'itération des lignes: %v", err)
	}

	log.Printf("[GetUserByEmail] Aucun utilisateur trouvé pour l'email: %s", email)
	return nil, nil
}

// Recherche un utilisateur par son ID.
// Retourne l'utilisateur si trouvé, une erreur sinon.
func GetUserByID(userID int64) (*domain.User, error) {
	log.Printf("[GetUserByID] Recherche de l'utilisateur avec l'ID: %d", userID)
	query := `
		SELECT id, first_name, last_name, email, password, role 
		FROM users 
		WHERE id = $1
	`

	var user domain.User
	err := database.DB.QueryRow(query, userID).Scan(
		&user.ID,
		&user.FirstName,
		&user.LastName,
		&user.Email,
		&user.Password,
		&user.Role,
	)

	if err != nil {
		log.Printf("[GetUserByID][ERREUR] Impossible de récupérer l'utilisateur (ID: %d): %v", userID, err)
		return nil, fmt.Errorf("erreur lors de la récupération de l'utilisateur par ID: %v", err)
	}

	log.Printf("[GetUserByID] Utilisateur trouvé: %s %s (ID: %d)", user.FirstName, user.LastName, user.ID)
	return &user, nil
}

// Payload pour la mise à jour d'un utilisateur.
// Les champs nil ne seront pas modifiés.
type UpdateUserPayload struct {
	FirstName *string
	LastName  *string
	Email     *string
	Password  *string
}

// Met à jour les champs non-nil du profil utilisateur.
// Retourne une erreur si la mise à jour échoue.
func UpdateUser(userID int64, payload UpdateUserPayload) error {
	log.Printf("[UpdateUser] Mise à jour de l'utilisateur (ID: %d)", userID)

	query := "UPDATE users SET"
	params := []interface{}{}
	paramIndex := 1

	if payload.FirstName != nil {
		query += fmt.Sprintf(" first_name = $%d,", paramIndex)
		params = append(params, *payload.FirstName)
		paramIndex++
	}
	if payload.LastName != nil {
		query += fmt.Sprintf(" last_name = $%d,", paramIndex)
		params = append(params, *payload.LastName)
		paramIndex++
	}
	if payload.Email != nil {
		query += fmt.Sprintf(" email = $%d,", paramIndex)
		params = append(params, *payload.Email)
		paramIndex++
	}
	if payload.Password != nil {
		query += fmt.Sprintf(" password = $%d,", paramIndex)
		params = append(params, *payload.Password)
		paramIndex++
	}

	if len(params) == 0 {
		log.Printf("[UpdateUser] Aucun champ à mettre à jour pour l'utilisateur (ID: %d)", userID)
		return nil
	}

	query = query[:len(query)-1] // Supprimer la dernière virgule
	query += fmt.Sprintf(" WHERE id = $%d", paramIndex)
	params = append(params, userID)

	log.Printf("[UpdateUser] Exécution de la requête: %s | Params: %v", query, params)
	_, err := database.DB.Exec(query, params...)
	if err != nil {
		log.Printf("[UpdateUser][ERREUR] Erreur lors de la mise à jour de l'utilisateur (ID: %d): %v", userID, err)
	}
	return err
}

// Supprime un utilisateur de la base de données.
// Retourne une erreur si la suppression échoue.
func DeleteUser(userID int64) error {
	log.Printf("[DeleteUser] Suppression de l'utilisateur (ID: %d)", userID)
	_, err := database.DB.Exec(`DELETE FROM users WHERE id = $1`, userID)
	if err != nil {
		log.Printf("[DeleteUser][ERREUR] Erreur lors de la suppression de l'utilisateur (ID: %d): %v", userID, err)
	}
	return err
}
