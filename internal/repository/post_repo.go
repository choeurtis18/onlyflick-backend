package repository

import (
	"context"
	"errors"
	"fmt"
	"log"
	"onlyflick/internal/database"
	"onlyflick/internal/domain"
	"database/sql"
	"strings"
	"time"
)

// =====================
// Repository des Posts
// =====================

// CreatePost insère un nouveau post dans la base de données.
func CreatePost(post *domain.Post) error {
	log.Printf("[PostRepo] Création d'un nouveau post pour l'utilisateur ID: %d", post.UserID)

	query := `
		INSERT INTO posts (user_id, title, description, media_url, file_id, visibility, created_at, updated_at)
		VALUES ($1, $2, $3, $4, $5, $6, NOW(), NOW())
		RETURNING id, created_at, updated_at
	`
	err := database.DB.QueryRow(
		query,
		post.UserID,
		post.Title,
		post.Description,
		post.MediaURL,
		post.FileID,
		post.Visibility,
	).Scan(&post.ID, &post.CreatedAt, &post.UpdatedAt)

	if err != nil {
		log.Printf("[PostRepo][ERREUR] Échec de la création du post pour l'utilisateur ID %d : %v", post.UserID, err)
		return fmt.Errorf("échec de la création du post : %w", err)
	}

	log.Printf("[PostRepo] Post créé avec succès (ID: %d)", post.ID)
	return nil
}


// ListPostsByUser retourne tous les posts d'un utilisateur donné.
func ListPostsByUser(userID int64) ([]domain.Post, error) {
	log.Printf("[PostRepo] Liste des posts pour l'utilisateur ID: %d", userID)

	query := `
		SELECT id, user_id, title, description, media_url, visibility, created_at, updated_at
		FROM posts
		WHERE user_id = $1
		ORDER BY created_at DESC
	`
	rows, err := database.DB.Query(query, userID)
	if err != nil {
		log.Printf("[PostRepo][ERREUR] Impossible de lister les posts pour l'utilisateur ID %d : %v", userID, err)
		return nil, fmt.Errorf("échec du listing des posts : %w", err)
	}
	defer rows.Close()

	var posts []domain.Post
	for rows.Next() {
		var post domain.Post
		err := rows.Scan(
			&post.ID,
			&post.UserID,
			&post.Title,
			&post.Description,
			&post.MediaURL,
			&post.Visibility,
			&post.CreatedAt,
			&post.UpdatedAt,
		)
		if err != nil {
			log.Printf("[PostRepo][ERREUR] Scan du post échoué pour l'utilisateur ID %d : %v", userID, err)
			return nil, fmt.Errorf("échec du scan du post : %w", err)
		}
		posts = append(posts, post)
	}

	log.Printf("[PostRepo] %d posts trouvés pour l'utilisateur ID %d", len(posts), userID)
	return posts, nil
}

// DeletePost supprime un post spécifique par son ID.
func DeletePost(postID int64) error {
	log.Printf("[PostRepo] Suppression du post ID: %d", postID)

	query := `DELETE FROM posts WHERE id = $1`
	result, err := database.DB.ExecContext(context.Background(), query, postID)
	if err != nil {
		log.Printf("[PostRepo][ERREUR] Échec de la suppression du post ID %d : %v", postID, err)
		return fmt.Errorf("échec de la suppression du post : %w", err)
	}

	rowsAffected, err := result.RowsAffected()
	if err != nil {
		log.Printf("[PostRepo][ERREUR] Impossible de récupérer le nombre de lignes affectées pour le post ID %d : %v", postID, err)
		return fmt.Errorf("échec lors de la récupération du nombre de lignes affectées : %w", err)
	}

	if rowsAffected == 0 {
		log.Printf("[PostRepo][INFO] Aucun post trouvé avec l'ID %d", postID)
		return errors.New("aucun post trouvé avec cet ID")
	}

	log.Printf("[PostRepo] Post ID %d supprimé avec succès", postID)
	return nil
}

// UpdatePost met à jour un post existant.
func UpdatePost(post *domain.Post) error {
	log.Printf("[PostRepo] Mise à jour du post ID: %d", post.ID)

	query := `
		UPDATE posts
		SET title = $1, description = $2, media_url = $3, visibility = $4, updated_at = NOW()
		WHERE id = $5 AND user_id = $6
		RETURNING updated_at
	`

	err := database.DB.QueryRow(
		query,
		post.Title,
		post.Description,
		post.MediaURL,
		post.Visibility,
		post.ID,
		post.UserID,
	).Scan(&post.UpdatedAt)

	if err != nil {
		log.Printf("[PostRepo][ERREUR] Échec de la mise à jour du post ID %d : %v", post.ID, err)
		return fmt.Errorf("échec de la mise à jour du post : %w", err)
	}

	log.Printf("[PostRepo] Post ID %d mis à jour avec succès", post.ID)
	return nil
}


// ===== FONCTION PRINCIPALE CORRIGÉE =====
// ListVisiblePosts retourne les posts visibles selon le rôle avec informations utilisateur complètes.
func ListVisiblePosts(userRole string) ([]domain.Post, error) {
	log.Printf("[PostRepo] Listing des posts visibles pour le rôle : %s", userRole)

	// ===== NOUVELLE REQUÊTE AVEC JOIN USERS =====
	var query string
	if userRole == "subscriber" || userRole == "creator" || userRole == "admin" {
		query = `
			SELECT 
				p.id, 
				p.user_id, 
				p.title, 
				p.description, 
				p.media_url, 
				COALESCE(p.file_id, '') as file_id,
				p.visibility, 
				p.created_at, 
				p.updated_at,
				-- Informations utilisateur depuis la table users
				COALESCE(u.username, '') as username,
				COALESCE(u.first_name, '') as first_name,
				COALESCE(u.last_name, '') as last_name,
				COALESCE(u.avatar_url, '') as avatar_url,
				COALESCE(u.bio, '') as bio,
				COALESCE(u.role, 'subscriber') as role,
				-- Compteurs
				COALESCE(likes_count.count, 0) as likes_count,
				COALESCE(comments_count.count, 0) as comments_count
			FROM posts p
			LEFT JOIN users u ON p.user_id = u.id
			LEFT JOIN (
				SELECT post_id, COUNT(*) as count 
				FROM likes 
				GROUP BY post_id
			) likes_count ON p.id = likes_count.post_id
			LEFT JOIN (
				SELECT post_id, COUNT(*) as count 
				FROM comments 
				GROUP BY post_id
			) comments_count ON p.id = comments_count.post_id
			ORDER BY p.created_at DESC
		`
	} else {
		query = `
			SELECT 
				p.id, 
				p.user_id, 
				p.title, 
				p.description, 
				p.media_url, 
				COALESCE(p.file_id, '') as file_id,
				p.visibility, 
				p.created_at, 
				p.updated_at,
				-- Informations utilisateur depuis la table users
				COALESCE(u.username, '') as username,
				COALESCE(u.first_name, '') as first_name,
				COALESCE(u.last_name, '') as last_name,
				COALESCE(u.avatar_url, '') as avatar_url,
				COALESCE(u.bio, '') as bio,
				COALESCE(u.role, 'subscriber') as role,
				-- Compteurs
				COALESCE(likes_count.count, 0) as likes_count,
				COALESCE(comments_count.count, 0) as comments_count
			FROM posts p
			LEFT JOIN users u ON p.user_id = u.id
			LEFT JOIN (
				SELECT post_id, COUNT(*) as count 
				FROM likes 
				GROUP BY post_id
			) likes_count ON p.id = likes_count.post_id
			LEFT JOIN (
				SELECT post_id, COUNT(*) as count 
				FROM comments 
				GROUP BY post_id
			) comments_count ON p.id = comments_count.post_id
			WHERE p.visibility = 'public'
			ORDER BY p.created_at DESC
		`
	}

	rows, err := database.DB.Query(query)
	if err != nil {
		log.Printf("[PostRepo][ERREUR] Impossible de lister les posts visibles : %v", err)
		return nil, fmt.Errorf("échec du listing des posts visibles : %w", err)
	}
	defer rows.Close()

	var posts []domain.Post
	for rows.Next() {
		var post domain.Post
		// ===== VARIABLES POUR LES DONNÉES UTILISATEUR =====
		var username, firstName, lastName, avatarUrl, bio, role string
		var likesCount, commentsCount int
		
		// ===== SCAN AVEC GESTION DES NULL VALUES =====
		if err := rows.Scan(
			&post.ID, 
			&post.UserID, 
			&post.Title, 
			&post.Description,
			&post.MediaURL, 
			&post.FileID,        // ===== MAINTENANT COALESCE EN SQL =====
			&post.Visibility, 
			&post.CreatedAt, 
			&post.UpdatedAt,
			// Données utilisateur
			&username,
			&firstName,
			&lastName,
			&avatarUrl,
			&bio,
			&role,
			// Compteurs
			&likesCount,
			&commentsCount,
		); err != nil {
			log.Printf("[PostRepo][ERREUR] Scan du post visible échoué : %v", err)
			return nil, fmt.Errorf("échec du scan du post : %w", err)
		}

		// ===== AJOUT DES DONNÉES UTILISATEUR AU POST =====
		post.Username = username
		post.FirstName = firstName
		post.LastName = lastName
		post.AvatarUrl = avatarUrl
		post.Bio = bio
		post.Role = role
		post.LikesCount = likesCount
		post.CommentsCount = commentsCount

		posts = append(posts, post)
	}

	log.Printf("[PostRepo] %d posts visibles trouvés avec informations utilisateur", len(posts))
	return posts, nil
}

// ===== FONCTION GetPostByID ÉGALEMENT CORRIGÉE =====
func GetPostByID(postID int64) (*domain.Post, error) {
	log.Printf("[PostRepo] Récupération du post ID: %d", postID)

	query := `
		SELECT 
			p.id, 
			p.user_id, 
			p.title, 
			p.description, 
			p.media_url, 
			COALESCE(p.file_id, '') as file_id,
			p.visibility, 
			p.created_at, 
			p.updated_at,
			-- Informations utilisateur
			COALESCE(u.username, '') as username,
			COALESCE(u.first_name, '') as first_name,
			COALESCE(u.last_name, '') as last_name,
			COALESCE(u.avatar_url, '') as avatar_url,
			COALESCE(u.bio, '') as bio,
			COALESCE(u.role, 'subscriber') as role,
			-- Compteurs
			COALESCE(likes_count.count, 0) as likes_count,
			COALESCE(comments_count.count, 0) as comments_count
		FROM posts p
		LEFT JOIN users u ON p.user_id = u.id
		LEFT JOIN (
			SELECT post_id, COUNT(*) as count 
			FROM likes 
			GROUP BY post_id
		) likes_count ON p.id = likes_count.post_id
		LEFT JOIN (
			SELECT post_id, COUNT(*) as count 
			FROM comments 
			GROUP BY post_id
		) comments_count ON p.id = comments_count.post_id
		WHERE p.id = $1
	`
	
	var post domain.Post
	var username, firstName, lastName, avatarUrl, bio, role string
	var likesCount, commentsCount int
	
	err := database.DB.QueryRow(query, postID).Scan(
		&post.ID,
		&post.UserID,
		&post.Title,
		&post.Description,
		&post.MediaURL,
		&post.FileID,        // ===== MAINTENANT COALESCE EN SQL =====
		&post.Visibility,
		&post.CreatedAt,
		&post.UpdatedAt,
		// Données utilisateur
		&username,
		&firstName,
		&lastName,
		&avatarUrl,
		&bio,
		&role,
		// Compteurs
		&likesCount,
		&commentsCount,
	)
	if err != nil {
		log.Printf("[PostRepo][ERREUR] Impossible de récupérer le post ID %d : %v", postID, err)
		return nil, fmt.Errorf("échec de la récupération du post : %w", err)
	}

	// Ajout des données utilisateur
	post.Username = username
	post.FirstName = firstName
	post.LastName = lastName
	post.AvatarUrl = avatarUrl
	post.Bio = bio
	post.Role = role
	post.LikesCount = likesCount
	post.CommentsCount = commentsCount

	log.Printf("[PostRepo] Post récupéré : %s (ID: %d) par %s", post.Title, post.ID, post.Username)
	return &post, nil
}




// ListPostsFromCreator retourne les posts d'un créateur, avec option pour inclure/exclure les posts privés.
func ListPostsFromCreator(creatorID int64, includePrivate bool) ([]*domain.Post, error) {
	log.Printf("[PostRepo] Listing des posts du créateur ID: %d (includePrivate: %v)", creatorID, includePrivate)

	query := `
		SELECT id, user_id, title, description, media_url, file_id, visibility, created_at, updated_at
		FROM posts
		WHERE user_id = $1
	`
	if !includePrivate {
		query += ` AND visibility = 'public'`
	}
	query += ` ORDER BY created_at DESC`

	rows, err := database.DB.Query(query, creatorID)
	if err != nil {
		log.Printf("[PostRepo][ERREUR] Impossible de lister les posts du créateur ID %d : %v", creatorID, err)
		return nil, err
	}
	defer rows.Close()

	var posts []*domain.Post
	for rows.Next() {
		var p domain.Post
		err := rows.Scan(&p.ID, &p.UserID, &p.Title, &p.Description, &p.MediaURL, &p.FileID, &p.Visibility, &p.CreatedAt, &p.UpdatedAt)
		if err != nil {
			log.Printf("[PostRepo][ERREUR] Scan du post du créateur ID %d échoué : %v", creatorID, err)
			return nil, err
		}
		posts = append(posts, &p)
	}

	log.Printf("[PostRepo] %d posts trouvés pour le créateur ID %d", len(posts), creatorID)
	return posts, nil
}

// ListSubscriberOnlyPosts retourne les posts visibles uniquement par les abonnés d'un créateur.
func ListSubscriberOnlyPosts(creatorID int64) ([]*domain.Post, error) {
	log.Printf("[PostRepo] Listing des posts 'subscriber only' pour le créateur ID: %d", creatorID)

	query := `
		SELECT id, user_id, title, description, media_url, file_id, visibility, created_at, updated_at
		FROM posts
		WHERE user_id = $1 AND visibility = 'subscriber'
		ORDER BY created_at DESC
	`
	rows, err := database.DB.Query(query, creatorID)
	if err != nil {
		log.Printf("[PostRepo][ERREUR] Impossible de lister les posts 'subscriber only' pour le créateur ID %d : %v", creatorID, err)
		return nil, err
	}
	defer rows.Close()

	var posts []*domain.Post
	for rows.Next() {
		var p domain.Post
		err := rows.Scan(&p.ID, &p.UserID, &p.Title, &p.Description, &p.MediaURL, &p.FileID, &p.Visibility, &p.CreatedAt, &p.UpdatedAt)
		if err != nil {
			log.Printf("[PostRepo][ERREUR] Scan du post 'subscriber only' échoué pour le créateur ID %d : %v", creatorID, err)
			return nil, err
		}
		posts = append(posts, &p)
	}

	log.Printf("[PostRepo] %d posts 'subscriber only' trouvés pour le créateur ID %d", len(posts), creatorID)
	return posts, nil
}

// ListPostsRecommendedForUserWithTags retourne des posts recommandés avec filtrage par tags optionnel
func ListPostsRecommendedForUserWithTags(userID int64, tags []string, limit, offset int) ([]interface{}, int, error) {
	log.Printf("[PostRepo] Posts recommandés avec tags pour user %d: tags=%v, limit=%d, offset=%d", 
		userID, tags, limit, offset)

	// Si aucun tag spécifié, utiliser la logique de recommandation normale
	if len(tags) == 0 {
		return getRecommendedPostsWithoutTags(userID, limit, offset)
	}

	// Sinon, filtrer par tags
	return getRecommendedPostsWithTags(userID, tags, limit, offset)
}

// getRecommendedPostsWithoutTags - logique normale de recommandation
func getRecommendedPostsWithoutTags(userID int64, limit, offset int) ([]interface{}, int, error) {
	log.Printf("[PostRepo] Recommandations sans filtrage tags pour user %d", userID)

	// Requête simplifiée basée sur l'activité récente et la popularité
	query := `
		SELECT 
			p.id,
			p.title,
			p.description,
			p.media_url,
			p.visibility,
			p.created_at,
			p.user_id AS author_id,
			COALESCE(u.username, CONCAT(u.first_name, ' ', u.last_name)) as author_name,
			COALESCE(COUNT(DISTINCT l.user_id), 0) as likes_count,
			COALESCE(COUNT(DISTINCT c.id), 0) as comments_count,
			ARRAY_AGG(DISTINCT pt.category) FILTER (WHERE pt.category IS NOT NULL) as tags
		FROM posts p
		JOIN users u ON p.user_id = u.id
		LEFT JOIN likes l ON p.id = l.post_id
		LEFT JOIN comments c ON p.id = c.post_id
		LEFT JOIN post_tags pt ON p.id = pt.post_id
		WHERE p.visibility = 'public'
			AND p.user_id != $1  -- Exclure ses propres posts
		GROUP BY p.id, u.id
		ORDER BY 
			-- Algorithme simple de scoring
			COUNT(DISTINCT l.user_id) * 2 + COUNT(DISTINCT c.id) * 3 DESC,
			p.created_at DESC
		LIMIT $2 OFFSET $3
	`

	rows, err := database.DB.Query(query, userID, limit, offset)
	if err != nil {
		log.Printf("[PostRepo][ERREUR] Erreur query posts recommandés : %v", err)
		return nil, 0, err
	}
	defer rows.Close()

	posts, err := scanPostsResults(rows)
	if err != nil {
		return nil, 0, err
	}

	// Compter le total
	total, err := countRecommendedPosts(userID, []string{})
	if err != nil {
		log.Printf("[PostRepo][WARN] Erreur count total : %v", err)
		total = len(posts)
	}

	log.Printf("[PostRepo] ✅ %d posts recommandés trouvés (total: %d)", len(posts), total)
	return posts, total, nil
}

// getRecommendedPostsWithTags - logique avec filtrage par tags
func getRecommendedPostsWithTags(userID int64, tags []string, limit, offset int) ([]interface{}, int, error) {
	log.Printf("[PostRepo] Recommandations avec filtrage tags: %v pour user %d", tags, userID)

	// Construire les placeholders pour les tags
	var tagPlaceholders []string
	var args []interface{}
	argIndex := 1

	// Ajouter userID
	args = append(args, userID)
	argIndex++

	// Ajouter les tags
	for _, tag := range tags {
		tagPlaceholders = append(tagPlaceholders, fmt.Sprintf("$%d", argIndex))
		args = append(args, tag)
		argIndex++
	}

	// Ajouter limit et offset
	args = append(args, limit, offset)
	limitPlaceholder := fmt.Sprintf("$%d", argIndex)
	offsetPlaceholder := fmt.Sprintf("$%d", argIndex+1)

	query := fmt.Sprintf(`
		SELECT 
			p.id,
			p.title,
			p.description,
			p.media_url,
			p.visibility,
			p.created_at,
			p.user_id AS author_id,
			COALESCE(u.username, CONCAT(u.first_name, ' ', u.last_name)) as author_name,
			COALESCE(COUNT(DISTINCT l.user_id), 0) as likes_count,
			COALESCE(COUNT(DISTINCT c.id), 0) as comments_count,
			ARRAY_AGG(DISTINCT pt.category) FILTER (WHERE pt.category IS NOT NULL) as tags
		FROM posts p
		JOIN users u ON p.user_id = u.id
		INNER JOIN post_tags pt ON p.id = pt.post_id
		LEFT JOIN likes l ON p.id = l.post_id
		LEFT JOIN comments c ON p.id = c.post_id
		WHERE p.visibility = 'public'
			AND p.user_id != $1
			AND pt.category IN (%s)
		GROUP BY p.id, u.id
		ORDER BY 
			COUNT(DISTINCT l.user_id) * 2 + COUNT(DISTINCT c.id) * 3 DESC,
			p.created_at DESC
		LIMIT %s OFFSET %s
	`, strings.Join(tagPlaceholders, ","), limitPlaceholder, offsetPlaceholder)

	rows, err := database.DB.Query(query, args...)
	if err != nil {
		log.Printf("[PostRepo][ERREUR] Erreur query posts recommandés avec tags : %v", err)
		return nil, 0, err
	}
	defer rows.Close()

	posts, err := scanPostsResults(rows)
	if err != nil {
		return nil, 0, err
	}

	// Compter le total avec tags
	total, err := countRecommendedPosts(userID, tags)
	if err != nil {
		log.Printf("[PostRepo][WARN] Erreur count total avec tags : %v", err)
		total = len(posts)
	}

	log.Printf("[PostRepo] ✅ %d posts recommandés avec tags trouvés (total: %d)", len(posts), total)
	return posts, total, nil
}

// scanPostsResults - fonction utilitaire pour scanner les résultats
func scanPostsResults(rows *sql.Rows) ([]interface{}, error) {
	var posts []interface{}

	for rows.Next() {
		var post struct {
			ID            int64     `json:"id"`
			Title         string    `json:"title"`
			Description   string    `json:"description"`
			MediaURL      string    `json:"media_url"`
			Visibility    string    `json:"visibility"`
			CreatedAt     time.Time `json:"created_at"`
			AuthorID      int64     `json:"author_id"`
			AuthorName    string    `json:"author_name"`
			LikesCount    int64     `json:"likes_count"`
			CommentsCount int64     `json:"comments_count"`
			Tags          []string  `json:"tags"`
		}

		var tagsArray sql.NullString

		err := rows.Scan(
			&post.ID,
			&post.Title,
			&post.Description,
			&post.MediaURL,
			&post.Visibility,
			&post.CreatedAt,
			&post.AuthorID,
			&post.AuthorName,
			&post.LikesCount,
			&post.CommentsCount,
			&tagsArray,
		)
		if err != nil {
			log.Printf("[PostRepo][ERREUR] Erreur scan post : %v", err)
			continue
		}

		// Parser les tags
		if tagsArray.Valid && tagsArray.String != "" {
			// Nettoyer la string des accolades PostgreSQL
			tagsStr := strings.Trim(tagsArray.String, "{}")
			if tagsStr != "" {
				post.Tags = strings.Split(tagsStr, ",")
			}
		}

		posts = append(posts, post)
	}

	return posts, nil
}

// countRecommendedPosts - compte le total de posts recommandés
func countRecommendedPosts(userID int64, tags []string) (int, error) {
	var query string
	var args []interface{}

	if len(tags) == 0 {
		// Count sans filtrage tags
		query = `
			SELECT COUNT(DISTINCT p.id)
			FROM posts p
			WHERE p.visibility = 'public' AND p.user_id != $1
		`
		args = []interface{}{userID}
	} else {
		// Count avec filtrage tags
		var tagPlaceholders []string
		args = append(args, userID)
		argIndex := 2

		for _, tag := range tags {
			tagPlaceholders = append(tagPlaceholders, fmt.Sprintf("$%d", argIndex))
			args = append(args, tag)
			argIndex++
		}

		query = fmt.Sprintf(`
			SELECT COUNT(DISTINCT p.id)
			FROM posts p
			INNER JOIN post_tags pt ON p.id = pt.post_id
			WHERE p.visibility = 'public' 
				AND p.user_id != $1
				AND pt.category IN (%s)
		`, strings.Join(tagPlaceholders, ","))
	}

	var total int
	err := database.DB.QueryRow(query, args...).Scan(&total)
	return total, err
}