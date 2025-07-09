package repository

import (
	"database/sql"
	"fmt"
	"log"
	"onlyflick/internal/database"
	"onlyflick/internal/domain"
)

// CreateComment insère un nouveau commentaire dans la base de données.
func CreateComment(c *domain.Comment) error {
	log.Printf("[CommentRepo] Création d'un commentaire pour le post ID %d par l'utilisateur ID %d", c.PostID, c.UserID)

	query := `
		INSERT INTO comments (user_id, post_id, content)
		VALUES ($1, $2, $3)
		RETURNING id, created_at, updated_at;
	`

	err := database.DB.QueryRow(query, c.UserID, c.PostID, c.Content).
		Scan(&c.ID, &c.CreatedAt, &c.UpdatedAt)
	if err != nil {
		log.Printf("[CommentRepo][ERREUR] Impossible de créer le commentaire : %v", err)
		return fmt.Errorf("erreur création commentaire : %w", err)
	}

	log.Printf("[CommentRepo] Commentaire créé avec succès : %+v", c)
	return nil
}


// GetCommentsByPostID récupère tous les commentaires associés à un post donné avec les informations utilisateur.
func GetCommentsByPostID(postID int64) ([]*domain.Comment, error) {
	log.Printf("[CommentRepo] Récupération des commentaires pour le post ID %d", postID)

	query := `
		SELECT 
			c.id, 
			c.user_id, 
			c.post_id, 
			c.content, 
			c.created_at, 
			c.updated_at,
			COALESCE(u.username, '') AS username,
			COALESCE(u.first_name, '') AS first_name,
			COALESCE(u.last_name, '') AS last_name,
			COALESCE(u.avatar_url, '') AS avatar_url
		FROM comments c
		LEFT JOIN users u ON c.user_id = u.id
		WHERE c.post_id = $1
		ORDER BY c.created_at ASC
	`

	rows, err := database.DB.Query(query, postID)
	if err != nil {
		log.Printf("[CommentRepo][ERREUR] Échec de la récupération des commentaires pour le post ID %d : %v", postID, err)
		return nil, fmt.Errorf("échec de la récupération des commentaires : %w", err)
	}
	defer rows.Close()

	var comments []*domain.Comment
	for rows.Next() {
		var c domain.Comment
		if err := rows.Scan(
			&c.ID,
			&c.UserID,
			&c.PostID,
			&c.Content,
			&c.CreatedAt,
			&c.UpdatedAt,
			&c.Username,
			&c.FirstName,
			&c.LastName,
			&c.AvatarUrl,
		); err != nil {
			log.Printf("[CommentRepo][ERREUR] Problème lors du scan d'un commentaire : %v", err)
			return nil, fmt.Errorf("échec scan commentaire : %w", err)
		}
		comments = append(comments, &c)
	}

	log.Printf("[CommentRepo] %d commentaire(s) récupéré(s) pour le post ID %d", len(comments), postID)
	return comments, nil
}


// DeleteComment supprime un commentaire selon son ID.
func DeleteComment(commentID int64) error {
	log.Printf("[CommentRepo] Suppression du commentaire ID %d", commentID)

	query := `DELETE FROM comments WHERE id = $1`

	result, err := database.DB.Exec(query, commentID)
	if err != nil {
		log.Printf("[CommentRepo][ERREUR] Impossible de supprimer le commentaire ID %d : %v", commentID, err)
		return fmt.Errorf("échec suppression commentaire : %w", err)
	}

	rowsAffected, err := result.RowsAffected()
	if err != nil {
		log.Printf("[CommentRepo][ERREUR] Impossible de récupérer le nombre de lignes supprimées : %v", err)
		return fmt.Errorf("échec récupération lignes supprimées : %w", err)
	}

	log.Printf("[CommentRepo] Suppression effectuée, %d ligne(s) affectée(s)", rowsAffected)
	return nil
}


// GetCommentByID récupère un commentaire par son ID avec les informations utilisateur.
func GetCommentByID(commentID int64) (*domain.Comment, error) {
	log.Printf("[CommentRepo] Récupération du commentaire ID %d", commentID)

	query := `
		SELECT 
			c.id, 
			c.post_id, 
			c.user_id, 
			c.content, 
			c.created_at, 
			c.updated_at,
			COALESCE(u.username, '') AS username,
			COALESCE(u.first_name, '') AS first_name,
			COALESCE(u.last_name, '') AS last_name,
			COALESCE(u.avatar_url, '') AS avatar_url
		FROM comments c
		LEFT JOIN users u ON c.user_id = u.id
		WHERE c.id = $1
	`

	var comment domain.Comment
	err := database.DB.QueryRow(query, commentID).Scan(
		&comment.ID,
		&comment.PostID,
		&comment.UserID,
		&comment.Content,
		&comment.CreatedAt,
		&comment.UpdatedAt,
		&comment.Username,
		&comment.FirstName,
		&comment.LastName,
		&comment.AvatarUrl,
	)
	if err != nil {
		if err == sql.ErrNoRows {
			log.Printf("[CommentRepo][INFO] Aucun commentaire trouvé pour l'ID %d", commentID)
			return nil, fmt.Errorf("commentaire non trouvé")
		}
		log.Printf("[CommentRepo][ERREUR] Impossible de récupérer le commentaire ID %d : %v", commentID, err)
		return nil, fmt.Errorf("échec récupération commentaire : %w", err)
	}

	log.Printf("[CommentRepo] Commentaire récupéré : %+v", comment)
	return &comment, nil
}

// GetCommentsByUserID récupère tous les commentaires d'un utilisateur donné
func GetCommentsByUserID(userID int64, limit, offset int) ([]*domain.Comment, error) {
	log.Printf("[CommentRepo] Récupération des commentaires pour l'utilisateur ID %d", userID)

	query := `
		SELECT 
			c.id, 
			c.user_id, 
			c.post_id, 
			c.content, 
			c.created_at, 
			c.updated_at,
			COALESCE(u.username, '') AS username,
			COALESCE(u.first_name, '') AS first_name,
			COALESCE(u.last_name, '') AS last_name,
			COALESCE(u.avatar_url, '') AS avatar_url
		FROM comments c
		LEFT JOIN users u ON c.user_id = u.id
		WHERE c.user_id = $1
		ORDER BY c.created_at DESC
		LIMIT $2 OFFSET $3
	`

	rows, err := database.DB.Query(query, userID, limit, offset)
	if err != nil {
		log.Printf("[CommentRepo][ERREUR] Échec de la récupération des commentaires pour l'utilisateur ID %d : %v", userID, err)
		return nil, fmt.Errorf("échec de la récupération des commentaires utilisateur : %w", err)
	}
	defer rows.Close()

	var comments []*domain.Comment
	for rows.Next() {
		var c domain.Comment
		if err := rows.Scan(
			&c.ID,
			&c.UserID,
			&c.PostID,
			&c.Content,
			&c.CreatedAt,
			&c.UpdatedAt,
			&c.Username,
			&c.FirstName,
			&c.LastName,
			&c.AvatarUrl,
		); err != nil {
			log.Printf("[CommentRepo][ERREUR] Problème lors du scan d'un commentaire : %v", err)
			return nil, fmt.Errorf("échec scan commentaire : %w", err)
		}
		comments = append(comments, &c)
	}

	log.Printf("[CommentRepo] %d commentaire(s) récupéré(s) pour l'utilisateur ID %d", len(comments), userID)
	return comments, nil
}
