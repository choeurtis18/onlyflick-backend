package repository

import (
	"context"
	"errors"
	"fmt"
	"log"
	"onlyflick/internal/database"
	"onlyflick/internal/domain"
	"database/sql"
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

// ListPostsRecommendedForUser retourne des posts recommandés pour un utilisateur.
func ListPostsRecommendedForUser(userID int64) ([]*domain.Post, error) {
	query := `
		WITH liked_creators AS (
			SELECT DISTINCT p.user_id
			FROM likes l
			JOIN posts p ON l.post_id = p.id
			WHERE l.user_id = $1
		),
		liked_tags AS (
			SELECT DISTINCT pt.category
			FROM likes l
			JOIN post_tags pt ON pt.post_id = l.post_id
			WHERE l.user_id = $1
		),
		seen_posts AS (
			SELECT content_id FROM user_interactions
			WHERE user_id = $1 AND content_type = 'post'
			UNION
			SELECT post_id FROM likes WHERE user_id = $1
		),
		recommended_from_creators AS (
			SELECT p.* FROM posts p
			WHERE p.user_id IN (SELECT user_id FROM liked_creators)
			AND p.id NOT IN (SELECT content_id FROM seen_posts)
			AND p.visibility = 'public'
		),
		recommended_from_tags AS (
			SELECT p.* FROM posts p
			JOIN post_tags pt ON p.id = pt.post_id
			WHERE pt.category IN (SELECT category FROM liked_tags)
			AND p.id NOT IN (SELECT content_id FROM seen_posts)
			AND p.visibility = 'public'
		),
		popular_unseen_posts AS (
			SELECT p.* FROM posts p
			JOIN post_metrics pm ON p.id = pm.post_id
			WHERE p.id NOT IN (SELECT content_id FROM seen_posts)
			AND p.visibility = 'public'
			ORDER BY pm.popularity_score DESC
			LIMIT 20
		),
		all_recommended AS (
			SELECT * FROM recommended_from_creators
			UNION
			SELECT * FROM recommended_from_tags
			UNION
			SELECT * FROM popular_unseen_posts
		)
		SELECT DISTINCT id, user_id, title, description, media_url,
		                file_id, visibility, created_at, updated_at,
		                image_url, video_url
		FROM all_recommended
		ORDER BY created_at DESC
		LIMIT 30;
	`

	rows, err := database.DB.Query(query, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var posts []*domain.Post
	for rows.Next() {
		var post domain.Post
		var fileID, imageURL, videoURL sql.NullString

		err := rows.Scan(
			&post.ID,
			&post.UserID,
			&post.Title,
			&post.Description,
			&post.MediaURL,
			&fileID,
			&post.Visibility,
			&post.CreatedAt,
			&post.UpdatedAt,
			&imageURL,
			&videoURL,
		)
		if err != nil {
			return nil, err
		}

		if fileID.Valid {
			post.FileID = fileID.String
		}
		if imageURL.Valid {
			post.ImageURL = imageURL.String
		}
		if videoURL.Valid {
			post.VideoURL = videoURL.String
		}

		posts = append(posts, &post)
	}
	return posts, nil
}