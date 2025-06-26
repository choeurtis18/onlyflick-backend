// internal/repository/search_repository.go

package repository

import (
	"log"
	"onlyflick/internal/database"
	"onlyflick/internal/domain"
	"strings"
)

// SearchUsers recherche des utilisateurs UNIQUEMENT par username
func SearchUsers(searchTerm string, currentUserID int64, limit, offset int) ([]domain.UserSearchResult, int, error) {
	log.Printf("[SearchUsers] Recherche par username: '%s', userID: %d, limit: %d, offset: %d", 
		searchTerm, currentUserID, limit, offset)
	
	// Pattern de recherche - seulement pour username
	searchPattern := "%" + strings.ToLower(searchTerm) + "%"
	
	// Requête ultra-simplifiée - seulement les colonnes de base qui existent
	query := `
		SELECT 
			u.id, 
			COALESCE(u.username, u.email) as username,
			COALESCE(u.first_name, '') as first_name, 
			COALESCE(u.last_name, '') as last_name, 
			COALESCE(u.email, '') as email,
			COALESCE(u.role, 'subscriber') as role
		FROM users u
		WHERE LOWER(COALESCE(u.username, u.email)) LIKE $1
			AND u.id != $2
		ORDER BY 
			CASE WHEN LOWER(COALESCE(u.username, u.email)) = LOWER($3) THEN 1 ELSE 2 END,
			u.id ASC
		LIMIT $4 OFFSET $5
	`
	
	log.Printf("[SearchUsers] Exécution requête avec pattern: %s", searchPattern)
	
	rows, err := database.DB.Query(query, searchPattern, currentUserID, searchTerm, limit, offset)
	if err != nil {
		log.Printf("[SearchUsers][ERREUR] Erreur requête recherche users : %v", err)
		return nil, 0, err
	}
	defer rows.Close()

	var users []domain.UserSearchResult
	for rows.Next() {
		var user domain.UserSearchResult
		var email string
		
		if err := rows.Scan(
			&user.ID,
			&user.Username,
			&user.FirstName,
			&user.LastName,
			&email,
			&user.Role,
		); err != nil {
			log.Printf("[SearchUsers][ERREUR] Erreur scan user : %v", err)
			continue // Ignorer cette ligne et continuer
		}

		// Calculer les valeurs dérivées
		if user.FirstName != "" && user.LastName != "" {
			user.FullName = user.FirstName + " " + user.LastName
		} else if user.FirstName != "" {
			user.FullName = user.FirstName
		} else {
			user.FullName = user.Username
		}
		
		// Marquer comme créateur si rôle = "creator"
		user.IsCreator = (user.Role == "creator")
		
		// Valeurs par défaut pour les champs optionnels
		user.AvatarURL = ""
		user.Bio = ""
		user.FollowersCount = 0
		user.PostsCount = 0
		user.IsFollowing = false
		user.MutualFollowers = 0
		
		users = append(users, user)
		log.Printf("[SearchUsers] Utilisateur trouvé: ID=%d, Username=%s, FullName=%s", 
			user.ID, user.Username, user.FullName)
	}

	// Compter le total - requête simplifiée
	countQuery := `
		SELECT COUNT(*)
		FROM users u
		WHERE LOWER(COALESCE(u.username, u.email)) LIKE $1
			AND u.id != $2
	`
	
	var total int
	err = database.DB.QueryRow(countQuery, searchPattern, currentUserID).Scan(&total)
	if err != nil {
		log.Printf("[SearchUsers][ERREUR] Erreur count users : %v", err)
		// Ne pas retourner d'erreur pour le count, juste loguer
		total = len(users)
	}

	log.Printf("[SearchUsers] ✅ Trouvé %d users pour username '%s' (total: %d)", len(users), searchTerm, total)
	return users, total, nil
}