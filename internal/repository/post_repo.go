package repository

import (
	"context"
	"errors"
	"fmt"
	"log"
	"onlyflick/internal/database"
	"onlyflick/internal/domain"
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

// GetPostByID récupère un post spécifique par son ID.
func GetPostByID(postID int64) (*domain.Post, error) {
	log.Printf("[PostRepo] Récupération du post ID: %d", postID)

	query := `
		SELECT id, user_id, title, description, media_url, visibility, created_at, updated_at
		FROM posts
		WHERE id = $1
	`
	var post domain.Post
	err := database.DB.QueryRow(query, postID).Scan(
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
		log.Printf("[PostRepo][ERREUR] Impossible de récupérer le post ID %d : %v", postID, err)
		return nil, fmt.Errorf("échec de la récupération du post : %w", err)
	}

	log.Printf("[PostRepo] Post récupéré : %s (ID: %d)", post.Title, post.ID)
	return &post, nil
}

// ListPostsByUser retourne tous les posts d’un utilisateur donné.
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

// ListVisiblePosts retourne les posts visibles selon le rôle de l'utilisateur.
func ListVisiblePosts(userRole string) ([]domain.Post, error) {
	log.Printf("[PostRepo] Listing des posts visibles pour le rôle : %s", userRole)

	var query string
	if userRole == "subscriber" || userRole == "creator" || userRole == "admin" {
		query = `
			SELECT id, user_id, title, description, media_url, visibility, created_at, updated_at
			FROM posts
			ORDER BY created_at DESC
		`
	} else {
		query = `
			SELECT id, user_id, title, description, media_url, visibility, created_at, updated_at
			FROM posts
			WHERE visibility = 'public'
			ORDER BY created_at DESC
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
		if err := rows.Scan(
			&post.ID, &post.UserID, &post.Title, &post.Description,
			&post.MediaURL, &post.Visibility, &post.CreatedAt, &post.UpdatedAt,
		); err != nil {
			log.Printf("[PostRepo][ERREUR] Scan du post visible échoué : %v", err)
			return nil, fmt.Errorf("échec du scan du post : %w", err)
		}
		posts = append(posts, post)
	}

	log.Printf("[PostRepo] %d posts visibles trouvés", len(posts))
	return posts, nil
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
