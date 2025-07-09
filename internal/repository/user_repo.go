package repository

import (
	"database/sql"
	"fmt"
	"log"
	"onlyflick/internal/database"
	"onlyflick/internal/domain"
	"onlyflick/internal/utils"
	"time"
)

// ===== STRUCTURES DE DONNÉES PROFIL =====

// ProfileStats représente les statistiques d'un profil utilisateur
type ProfileStats struct {
	PostsCount     int     `json:"posts_count"`
	FollowersCount int     `json:"followers_count"`
	FollowingCount int     `json:"following_count"`
	LikesReceived  int     `json:"likes_received"`
	TotalEarnings  float64 `json:"total_earnings"`
}

// UserPost représente un post utilisateur pour le profil
type UserPost struct {
	ID            int64  `json:"id"`
	Content       string `json:"content"`
	ImageURL      string `json:"image_url,omitempty"`
	VideoURL      string `json:"video_url,omitempty"`
	Visibility    string `json:"visibility"`
	LikesCount    int    `json:"likes_count"`
	CommentsCount int    `json:"comments_count"`
	CreatedAt     string `json:"created_at"`
	IsLiked       bool   `json:"is_liked"`
}

// Payload pour la mise à jour d'un utilisateur.
type UpdateUserPayload struct {
	FirstName *string
	LastName  *string
	Email     *string
	Password  *string
	Username  *string // ===== AJOUT USERNAME =====
	AvatarURL *string
	Bio       *string
}

// ===== FONCTIONS UTILISATEUR DE BASE =====

// Crée un nouvel utilisateur dans la base de données AVEC USERNAME
func CreateUser(user *domain.User) error {
	query := `
		INSERT INTO users (first_name, last_name, username, email, password, role, avatar_url, bio)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
		RETURNING id, created_at, updated_at
	`
	log.Printf("[CreateUser] Création de l'utilisateur: %s %s, username: %s, email: %s",
		user.FirstName, user.LastName, user.Username, user.Email)

	err := database.DB.QueryRow(
		query,
		user.FirstName, // $1 (chiffré)
		user.LastName,  // $2 (chiffré)
		user.Username,  // $3 (clair - pseudo public)
		user.Email,     // $4 (chiffré)
		user.Password,  // $5 (hashé)
		user.Role,      // $6
		user.AvatarURL, // $7
		user.Bio,       // $8
	).Scan(&user.ID, &user.CreatedAt, &user.UpdatedAt)

	if err != nil {
		log.Printf("[CreateUser][ERREUR] Impossible de créer l'utilisateur (%s): %v", user.Email, err)
	} else {
		log.Printf("[CreateUser] Utilisateur créé avec succès - ID: %d, Username: %s", user.ID, user.Username)
	}
	return err
}

// Recherche un utilisateur par email (décrypté) - AVEC TOUS LES CHAMPS
func GetUserByEmail(email string) (*domain.User, error) {
	log.Printf("[GetUserByEmail] Recherche de l'utilisateur avec l'email: %s", email)

	rows, err := database.DB.Query(`
		SELECT id, first_name, last_name, username, email, password, role, avatar_url, bio, created_at, updated_at 
		FROM users
	`)
	if err != nil {
		log.Printf("[GetUserByEmail][ERREUR] Erreur lors de la requête SQL: %v", err)
		return nil, fmt.Errorf("erreur lors de la requête des utilisateurs: %v", err)
	}
	defer rows.Close()

	for rows.Next() {
		var user domain.User
		var avatarURL, bio sql.NullString
		var updatedAt sql.NullTime

		if err := rows.Scan(
			&user.ID,
			&user.FirstName,
			&user.LastName,
			&user.Username, // ===== AJOUT USERNAME =====
			&user.Email,
			&user.Password,
			&user.Role,
			&avatarURL,
			&bio,
			&user.CreatedAt,
			&updatedAt,
		); err != nil {
			log.Printf("[GetUserByEmail][ERREUR] Erreur lors du scan d'un utilisateur: %v", err)
			return nil, fmt.Errorf("erreur lors du scan d'un utilisateur: %v", err)
		}

		// Assignation des champs nullable
		if avatarURL.Valid {
			user.AvatarURL = avatarURL.String
		}
		if bio.Valid {
			user.Bio = bio.String
		}
		if updatedAt.Valid {
			user.UpdatedAt = updatedAt.Time
		}

		decryptedEmail, err := utils.DecryptAES(user.Email)
		if err != nil {
			log.Printf("[GetUserByEmail][ERREUR] Erreur lors du décryptage de l'email: %v", err)
			return nil, fmt.Errorf("erreur lors du décryptage de l'email: %v", err)
		}

		if decryptedEmail == email {
			// Décrypter les autres champs pour le retour
			if decryptedFirstName, err := utils.DecryptAES(user.FirstName); err == nil {
				user.FirstName = decryptedFirstName
			}
			if decryptedLastName, err := utils.DecryptAES(user.LastName); err == nil {
				user.LastName = decryptedLastName
			}
			user.Email = decryptedEmail

			log.Printf("[GetUserByEmail] Utilisateur trouvé pour l'email: %s (ID: %d, Username: %s)",
				email, user.ID, user.Username)
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
func GetUserByID(userID int64) (*domain.User, error) {
	log.Printf("[GetUserByID] Recherche de l'utilisateur avec l'ID: %d", userID)

	query := `
		SELECT id, first_name, last_name, username, email, password, role, avatar_url, bio, created_at, updated_at
		FROM users 
		WHERE id = $1
	`

	var user domain.User
	var avatarURL, bio sql.NullString
	var updatedAt sql.NullTime

	err := database.DB.QueryRow(query, userID).Scan(
		&user.ID,
		&user.FirstName,
		&user.LastName,
		&user.Username, // ===== AJOUT USERNAME =====
		&user.Email,
		&user.Password,
		&user.Role,
		&avatarURL,
		&bio,
		&user.CreatedAt,
		&updatedAt,
	)

	if err != nil {
		log.Printf("[GetUserByID][ERREUR] Impossible de récupérer l'utilisateur (ID: %d): %v", userID, err)
		return nil, fmt.Errorf("erreur lors de la récupération de l'utilisateur par ID: %v", err)
	}

	// Décryption des champs chiffrés
	if decryptedFirstName, err := utils.DecryptAES(user.FirstName); err == nil {
		user.FirstName = decryptedFirstName
	}
	if decryptedLastName, err := utils.DecryptAES(user.LastName); err == nil {
		user.LastName = decryptedLastName
	}
	if decryptedEmail, err := utils.DecryptAES(user.Email); err == nil {
		user.Email = decryptedEmail
	}

	// ===== CORRECTION : Assignation des nouveaux champs (non chiffrés) =====
	if avatarURL.Valid {
		user.AvatarURL = avatarURL.String
	}
	if bio.Valid {
		user.Bio = bio.String
	}
	if updatedAt.Valid {
		user.UpdatedAt = updatedAt.Time
	}

	log.Printf("[GetUserByID] Utilisateur trouvé: %s %s (ID: %d, Username: %s)",
		user.FirstName, user.LastName, user.ID, user.Username)
	return &user, nil
}

// GetUserByUsername récupère un utilisateur par son username
func GetUserByUsername(username string) (*domain.User, error) {
	log.Printf("[GetUserByUsername] Récupération utilisateur par username: %s", username)

	var user domain.User
	query := `SELECT id, first_name, last_name, email, role, created_at, avatar_url, bio, username, updated_at
	          FROM users WHERE username = $1`

	var firstName, lastName, email, avatarURL, bio, userUsername sql.NullString
	var createdAt time.Time
	var updatedAt sql.NullTime

	err := database.DB.QueryRow(query, username).Scan(
		&user.ID,
		&firstName,
		&lastName,
		&email,
		&user.Role,
		&createdAt,
		&avatarURL,
		&bio,
		&userUsername,
		&updatedAt,
	)

	if err != nil {
		if err == sql.ErrNoRows {
			log.Printf("[GetUserByUsername] Utilisateur non trouvé pour username: %s", username)
			return nil, nil
		}
		log.Printf("[GetUserByUsername][ERROR] Erreur récupération utilisateur: %v", err)
		return nil, fmt.Errorf("erreur récupération utilisateur: %w", err)
	}

	// Décryptage des champs chiffrés
	if firstName.Valid {
		if decryptedFirstName, err := utils.DecryptAES(firstName.String); err == nil {
			user.FirstName = decryptedFirstName
		} else {
			user.FirstName = firstName.String // Fallback
		}
	}

	if lastName.Valid {
		if decryptedLastName, err := utils.DecryptAES(lastName.String); err == nil {
			user.LastName = decryptedLastName
		} else {
			user.LastName = lastName.String // Fallback
		}
	}

	if email.Valid {
		if decryptedEmail, err := utils.DecryptAES(email.String); err == nil {
			user.Email = decryptedEmail
		} else {
			user.Email = email.String // Fallback
		}
	}

	// Champs non chiffrés
	if avatarURL.Valid {
		user.AvatarURL = avatarURL.String
	}
	if bio.Valid {
		user.Bio = bio.String
	}
	if userUsername.Valid {
		user.Username = userUsername.String
	}
	if updatedAt.Valid {
		user.UpdatedAt = updatedAt.Time
	}

	user.CreatedAt = createdAt

	log.Printf("[GetUserByUsername] Utilisateur trouvé: ID=%d, Username=%s", user.ID, username)
	return &user, nil
}

// Met à jour les champs non-nil du profil utilisateur AVEC SUPPORT USERNAME
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
	if payload.Username != nil { // ===== AJOUT USERNAME =====
		query += fmt.Sprintf(" username = $%d,", paramIndex)
		params = append(params, *payload.Username)
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
	if payload.AvatarURL != nil {
		query += fmt.Sprintf(" avatar_url = $%d,", paramIndex)
		params = append(params, *payload.AvatarURL)
		paramIndex++
	}
	if payload.Bio != nil {
		query += fmt.Sprintf(" bio = $%d,", paramIndex)
		params = append(params, *payload.Bio)
		paramIndex++
	}

	if len(params) == 0 {
		log.Printf("[UpdateUser] Aucun champ à mettre à jour pour l'utilisateur (ID: %d)", userID)
		return nil
	}

	// Ajouter updated_at automatiquement
	query += fmt.Sprintf(" updated_at = $%d,", paramIndex)
	params = append(params, time.Now())
	paramIndex++

	query = query[:len(query)-1] // Supprimer la dernière virgule
	query += fmt.Sprintf(" WHERE id = $%d", paramIndex)
	params = append(params, userID)

	log.Printf("[UpdateUser] Exécution de la requête: %s | Params: %v", query, params)
	result, err := database.DB.Exec(query, params...)
	if err != nil {
		log.Printf("[UpdateUser][ERREUR] Erreur lors de la mise à jour de l'utilisateur (ID: %d): %v", userID, err)
		return err
	}

	rowsAffected, _ := result.RowsAffected()
	if rowsAffected == 0 {
		return fmt.Errorf("utilisateur non trouvé")
	}

	log.Printf("[UpdateUser] Utilisateur %d mis à jour avec succès", userID)
	return nil
}

// Supprime un utilisateur de la base de données.
func DeleteUser(userID int64) error {
	log.Printf("[DeleteUser] Suppression de l'utilisateur (ID: %d)", userID)

	_, err := database.DB.Exec(`DELETE FROM users WHERE id = $1`, userID)
	if err != nil {
		log.Printf("[DeleteUser][ERREUR] Erreur lors de la suppression de l'utilisateur (ID: %d): %v", userID, err)
	}
	return err
}

// ===== FONCTIONS PROFIL AVANCÉES =====

// GetProfileStats récupère les statistiques d'un profil utilisateur
func GetProfileStats(userID int64) (*ProfileStats, error) {
	log.Printf("[GetProfileStats] Récupération des stats pour user %d", userID)

	var stats ProfileStats

	
	// 1. Nombre de posts
	var postsCount int
	err := database.DB.QueryRow("SELECT COUNT(*) FROM posts WHERE user_id = $1", userID).Scan(&postsCount)
	if err != nil {
		log.Printf("[GetProfileStats][ERROR] Erreur récupération posts count: %v", err)
		return nil, fmt.Errorf("erreur récupération posts count: %w", err)
	}
	stats.PostsCount = postsCount

	// 2. Nombre d'abonnés
	var followersCount int
	err = database.DB.QueryRow("SELECT COUNT(*) FROM subscriptions WHERE creator_id = $1 AND status = true", userID).Scan(&followersCount)
	if err != nil {
		log.Printf("[GetProfileStats][ERROR] Erreur récupération followers count: %v", err)
		return nil, fmt.Errorf("erreur récupération followers count: %w", err)
	}
	stats.FollowersCount = followersCount

	// 3. Nombre d'abonnements
	var followingCount int
	err = database.DB.QueryRow("SELECT COUNT(*) FROM subscriptions WHERE subscriber_id = $1 AND status = true", userID).Scan(&followingCount)
	if err != nil {
		log.Printf("[GetProfileStats][ERROR] Erreur récupération following count: %v", err)
		return nil, fmt.Errorf("erreur récupération following count: %w", err)
	}
	stats.FollowingCount = followingCount

	// 4. Nombre de likes reçus
	var likesReceived int
	err = database.DB.QueryRow(`
		SELECT COUNT(*) FROM likes l 
		JOIN posts p ON l.post_id = p.id 
		WHERE p.user_id = $1
	`, userID).Scan(&likesReceived)
	if err != nil {
		log.Printf("[GetProfileStats][ERROR] Erreur récupération likes received: %v", err)
		return nil, fmt.Errorf("erreur récupération likes received: %w", err)
	}
	stats.LikesReceived = likesReceived

	// 5. Revenus totaux
	var totalEarnings sql.NullFloat64
	err = database.DB.QueryRow(`
		SELECT COALESCE(SUM(pay.amount), 0) FROM payments pay 
		JOIN subscriptions sub ON pay.subscription_id = sub.id 
		WHERE sub.creator_id = $1 AND sub.status = true AND pay.status = 'success'
	`, userID).Scan(&totalEarnings)
	if err != nil {
		log.Printf("[GetProfileStats][ERROR] Erreur récupération earnings: %v", err)
		return nil, fmt.Errorf("erreur récupération earnings: %w", err)
	}
	
	if totalEarnings.Valid {
		stats.TotalEarnings = totalEarnings.Float64
	} else {
		stats.TotalEarnings = 0.0
	}

	log.Printf("[GetProfileStats] Stats récupérées: posts=%d, followers=%d, following=%d, likes=%d, earnings=%.2f",
		stats.PostsCount, stats.FollowersCount, stats.FollowingCount, stats.LikesReceived, stats.TotalEarnings)

	return &stats, nil
}

// GetUserPosts récupère les posts d'un utilisateur avec pagination
func GetUserPosts(userID int64, page, limit int, postType string) ([]*UserPost, error) {
	log.Printf("[GetUserPosts] Récupération posts pour user %d (page=%d, limit=%d, type=%s)", userID, page, limit, postType)

	offset := (page - 1) * limit

	baseQuery := `
		SELECT 
			p.id,
			COALESCE(p.title, '') as content,
			COALESCE(p.media_url, '') as image_url,
			'' as video_url,
			p.visibility,
			p.created_at
		FROM posts p
		WHERE p.user_id = $1
	`

	// Construction de la requête selon le type de posts
	var query string
	var args []interface{}

	switch postType {
	case "public":
		query = baseQuery + " AND p.visibility = 'public'"
		args = []interface{}{userID}
	case "subscriber":
		query = baseQuery + " AND p.visibility = 'subscriber'"
		args = []interface{}{userID}
	default: // "all"
		query = baseQuery
		args = []interface{}{userID}
	}

	query += " ORDER BY p.created_at DESC LIMIT $2 OFFSET $3"
	args = append(args, limit, offset)

	rows, err := database.DB.Query(query, args...)
	if err != nil {
		log.Printf("[GetUserPosts][ERROR] Erreur query posts: %v", err)
		return nil, fmt.Errorf("erreur récupération posts: %w", err)
	}
	defer rows.Close()

	var posts []*UserPost
	for rows.Next() {
		var post UserPost
		var imageURL, videoURL sql.NullString
		var createdAt time.Time

		err := rows.Scan(
			&post.ID,
			&post.Content,
			&imageURL,
			&videoURL,
			&post.Visibility,
			&createdAt,
		)

		if err != nil {
			log.Printf("[GetUserPosts][ERROR] Erreur scan post: %v", err)
			continue
		}

		// Gestion des champs nullable
		if imageURL.Valid {
			post.ImageURL = imageURL.String
		}
		if videoURL.Valid {
			post.VideoURL = videoURL.String
		}

		post.CreatedAt = createdAt.Format(time.RFC3339)
		
		// Récupération des compteurs séparément pour éviter les conflits
		post.LikesCount = getLikesCountForPost(post.ID)
		post.CommentsCount = getCommentsCountForPost(post.ID)
		post.IsLiked = isPostLikedByUser(post.ID, userID)

		posts = append(posts, &post)
	}

	log.Printf("[GetUserPosts] %d posts récupérés pour user %d", len(posts), userID)
	return posts, nil
}

func getLikesCountForPost(postID int64) int {
	var count int
	err := database.DB.QueryRow("SELECT COUNT(*) FROM likes WHERE post_id = $1", postID).Scan(&count)
	if err != nil {
		log.Printf("[getLikesCountForPost] Erreur: %v", err)
		return 0
	}
	return count
}

func getCommentsCountForPost(postID int64) int {
	var count int
	err := database.DB.QueryRow("SELECT COUNT(*) FROM comments WHERE post_id = $1", postID).Scan(&count)
	if err != nil {
		log.Printf("[getCommentsCountForPost] Erreur: %v", err)
		return 0
	}
	return count
}

func isPostLikedByUser(postID, userID int64) bool {
	var exists bool
	err := database.DB.QueryRow("SELECT EXISTS(SELECT 1 FROM likes WHERE post_id = $1 AND user_id = $2)", postID, userID).Scan(&exists)
	if err != nil {
		log.Printf("[isPostLikedByUser] Erreur: %v", err)
		return false
	}
	return exists
}

// UpdateUserAvatar met à jour l'avatar d'un utilisateur
func UpdateUserAvatar(userID int64, avatarURL string) error {
	log.Printf("[UpdateUserAvatar] Mise à jour avatar pour user %d: %s", userID, avatarURL)

	query := `UPDATE users SET avatar_url = $1, updated_at = NOW() WHERE id = $2`

	result, err := database.DB.Exec(query, avatarURL, userID)
	if err != nil {
		log.Printf("[UpdateUserAvatar][ERROR] Erreur mise à jour avatar: %v", err)
		return fmt.Errorf("erreur mise à jour avatar: %w", err)
	}

	rowsAffected, _ := result.RowsAffected()
	if rowsAffected == 0 {
		return fmt.Errorf("utilisateur non trouvé")
	}

	log.Printf("[UpdateUserAvatar] Avatar mis à jour avec succès pour user %d", userID)
	return nil
}

// UpdateUserBio met à jour la bio d'un utilisateur
func UpdateUserBio(userID int64, bio string) error {
	log.Printf("[UpdateUserBio] Mise à jour bio pour user %d", userID)

	query := `UPDATE users SET bio = $1, updated_at = NOW() WHERE id = $2`

	result, err := database.DB.Exec(query, bio, userID)
	if err != nil {
		log.Printf("[UpdateUserBio][ERROR] Erreur mise à jour bio: %v", err)
		return fmt.Errorf("erreur mise à jour bio: %w", err)
	}

	rowsAffected, _ := result.RowsAffected()
	if rowsAffected == 0 {
		return fmt.Errorf("utilisateur non trouvé")
	}

	log.Printf("[UpdateUserBio] Bio mise à jour avec succès pour user %d", userID)
	return nil
}

// CheckUsernameAvailability vérifie si un username est disponible
func CheckUsernameAvailability(username string) (bool, error) {
	log.Printf("[CheckUsernameAvailability] Vérification disponibilité username: %s", username)

	var count int
	query := `SELECT COUNT(*) FROM users WHERE username = $1`

	err := database.DB.QueryRow(query, username).Scan(&count)
	if err != nil {
		log.Printf("[CheckUsernameAvailability][ERROR] Erreur vérification username: %v", err)
		return false, fmt.Errorf("erreur vérification username: %w", err)
	}

	available := count == 0
	log.Printf("[CheckUsernameAvailability] Username %s disponible: %v (count: %d)", username, available, count)
	return available, nil
}

// ===== NOUVELLES MÉTHODES POUR LES STATISTIQUES SÉPARÉES =====

// GetUserPostsCount récupère le nombre de posts d'un utilisateur
func GetUserPostsCount(userID int64) (int, error) {
	log.Printf("[GetUserPostsCount] Récupération nombre de posts pour user %d", userID)

	var count int
	query := `SELECT COUNT(*) FROM posts WHERE user_id = $1`

	err := database.DB.QueryRow(query, userID).Scan(&count)
	if err != nil {
		log.Printf("[GetUserPostsCount][ERROR] Erreur récupération nombre de posts: %v", err)
		return 0, fmt.Errorf("erreur récupération nombre de posts: %w", err)
	}

	log.Printf("[GetUserPostsCount] Utilisateur %d a %d posts", userID, count)
	return count, nil
}

// GetUserFollowersCount récupère le nombre d'abonnés d'un utilisateur (si créateur)
func GetUserFollowersCount(userID int64) (int, error) {
	log.Printf("[GetUserFollowersCount] Récupération nombre de followers pour user %d", userID)

	var count int
	query := `SELECT COUNT(*) FROM subscriptions WHERE creator_id = $1 AND status = true`

	err := database.DB.QueryRow(query, userID).Scan(&count)
	if err != nil {
		log.Printf("[GetUserFollowersCount][ERROR] Erreur récupération nombre de followers: %v", err)
		return 0, fmt.Errorf("erreur récupération nombre de followers: %w", err)
	}

	log.Printf("[GetUserFollowersCount] Utilisateur %d a %d followers", userID, count)
	return count, nil
}

// GetUserFollowingCount récupère le nombre d'abonnements d'un utilisateur
func GetUserFollowingCount(userID int64) (int, error) {
	log.Printf("[GetUserFollowingCount] Récupération nombre de following pour user %d", userID)

	var count int
	query := `SELECT COUNT(*) FROM subscriptions WHERE subscriber_id = $1 AND status = true`

	err := database.DB.QueryRow(query, userID).Scan(&count)
	if err != nil {
		log.Printf("[GetUserFollowingCount][ERROR] Erreur récupération nombre de following: %v", err)
		return 0, fmt.Errorf("erreur récupération nombre de following: %w", err)
	}

	log.Printf("[GetUserFollowingCount] Utilisateur %d suit %d créateurs", userID, count)
	return count, nil
}

// ===== NOUVEAU : GetUserPostsCountByType récupère le nombre de posts d'un utilisateur selon le type de visibilité =====
func GetUserPostsCountByType(userID int64, postType string) (int, error) {
	log.Printf("[GetUserPostsCountByType] Récupération nombre de posts pour user %d (type: %s)", userID, postType)

	var query string
	var args []interface{}

	switch postType {
	case "public":
		query = `SELECT COUNT(*) FROM posts WHERE user_id = $1 AND visibility = 'public'`
		args = []interface{}{userID}
	case "subscriber":
		query = `SELECT COUNT(*) FROM posts WHERE user_id = $1 AND visibility = 'subscriber'`
		args = []interface{}{userID}
	default: // "all"
		query = `SELECT COUNT(*) FROM posts WHERE user_id = $1`
		args = []interface{}{userID}
	}

	var count int
	err := database.DB.QueryRow(query, args...).Scan(&count)
	if err != nil {
		log.Printf("[GetUserPostsCountByType][ERROR] Erreur récupération nombre de posts: %v", err)
		return 0, fmt.Errorf("erreur récupération nombre de posts: %w", err)
	}

	log.Printf("[GetUserPostsCountByType] Utilisateur %d a %d posts (type: %s)", userID, count, postType)
	return count, nil
}

func GetAllUsers() ([]*domain.User, error) {
	log.Printf("[GetAllUsers] Récupération de tous les utilisateurs")

	rows, err := database.DB.Query(`
		SELECT id, first_name, last_name, username, email, password, role, avatar_url, bio, created_at, updated_at
		FROM users
		ORDER BY id ASC
	`)
	if err != nil {
		log.Printf("[GetAllUsers][ERREUR] Erreur lors de la requête SQL: %v", err)
		return nil, fmt.Errorf("erreur lors de la récupération des utilisateurs: %w", err)
	}
	defer rows.Close()

	var users []*domain.User
	for rows.Next() {
		var user domain.User
		var avatarURL, bio sql.NullString
		var updatedAt sql.NullTime

		if err := rows.Scan(
			&user.ID,
			&user.FirstName,
			&user.LastName,
			&user.Username,
			&user.Email,
			&user.Password,
			&user.Role,
			&avatarURL,
			&bio,
			&user.CreatedAt,
			&updatedAt,
		); err != nil {
			log.Printf("[GetAllUsers][ERREUR] Erreur lors du scan d'un utilisateur: %v", err)
			continue
		}

		// Décryptage des champs chiffrés
		if decryptedFirstName, err := utils.DecryptAES(user.FirstName); err == nil {
			user.FirstName = decryptedFirstName
		}
		if decryptedLastName, err := utils.DecryptAES(user.LastName); err == nil {
			user.LastName = decryptedLastName
		}
		if decryptedEmail, err := utils.DecryptAES(user.Email); err == nil {
			user.Email = decryptedEmail
		}

		if avatarURL.Valid {
			user.AvatarURL = avatarURL.String
		}
		if bio.Valid {
			user.Bio = bio.String
		}
		if updatedAt.Valid {
			user.UpdatedAt = updatedAt.Time
		}

		users = append(users, &user)
	}

	if err := rows.Err(); err != nil {
		log.Printf("[GetAllUsers][ERREUR] Erreur lors de l'itération des lignes: %v", err)
		return nil, fmt.Errorf("erreur lors de l'itération des lignes: %w", err)
	}

	log.Printf("[GetAllUsers] %d utilisateurs récupérés", len(users))
	return users, nil
}