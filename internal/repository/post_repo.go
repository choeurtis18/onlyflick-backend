package repository

import (
	"context"
	"database/sql"
	"errors"
	"fmt"
	"log"
	"onlyflick/internal/database"
	"onlyflick/internal/domain"
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

// =====================
// MÉTHODES TAGS - Nouvelles fonctions ajoutées
// =====================

// CreatePostTag insère un tag pour un post dans la table post_tags
func CreatePostTag(postID int64, tagCategory string) error {
	log.Printf("[PostRepo] Insertion tag '%s' pour post %d", tagCategory, postID)

	query := `
		INSERT INTO post_tags (post_id, category)
		VALUES ($1, $2)
		ON CONFLICT (post_id, category) DO NOTHING
	`

	_, err := database.DB.Exec(query, postID, tagCategory)
	if err != nil {
		log.Printf("[PostRepo][ERREUR] Impossible d'insérer le tag '%s' pour le post %d: %v", 
			tagCategory, postID, err)
		return err
	}

	log.Printf("[PostRepo] ✅ Tag '%s' ajouté avec succès au post %d", tagCategory, postID)
	return nil
}

// DeletePostTags supprime tous les tags d'un post
func DeletePostTags(postID int64) error {
	log.Printf("[PostRepo] Suppression de tous les tags pour le post %d", postID)

	query := `DELETE FROM post_tags WHERE post_id = $1`

	result, err := database.DB.Exec(query, postID)
	if err != nil {
		log.Printf("[PostRepo][ERREUR] Impossible de supprimer les tags du post %d: %v", postID, err)
		return err
	}

	rowsAffected, _ := result.RowsAffected()
	log.Printf("[PostRepo] ✅ %d tags supprimés pour le post %d", rowsAffected, postID)
	return nil
}

// GetPostTags récupère tous les tags d'un post
func GetPostTags(postID int64) ([]string, error) {
	log.Printf("[PostRepo] Récupération des tags pour le post %d", postID)

	query := `
		SELECT category 
		FROM post_tags 
		WHERE post_id = $1
		ORDER BY category
	`

	rows, err := database.DB.Query(query, postID)
	if err != nil {
		log.Printf("[PostRepo][ERREUR] Erreur lors de la récupération des tags du post %d: %v", postID, err)
		return nil, err
	}
	defer rows.Close()

	var tags []string
	for rows.Next() {
		var tag string
		if err := rows.Scan(&tag); err != nil {
			log.Printf("[PostRepo][ERREUR] Erreur lors du scan du tag: %v", err)
			continue
		}
		tags = append(tags, tag)
	}

	if err = rows.Err(); err != nil {
		log.Printf("[PostRepo][ERREUR] Erreur lors du parcours des résultats: %v", err)
		return nil, err
	}

	log.Printf("[PostRepo] ✅ %d tags récupérés pour le post %d: %v", len(tags), postID, tags)
	return tags, nil
}

// UpdatePostTags met à jour les tags d'un post (supprime les anciens et ajoute les nouveaux)
func UpdatePostTags(postID int64, newTags []string) error {
	log.Printf("[PostRepo] Mise à jour des tags pour le post %d: %v", postID, newTags)

	// Commencer une transaction
	tx, err := database.DB.Begin()
	if err != nil {
		log.Printf("[PostRepo][ERREUR] Impossible de commencer la transaction: %v", err)
		return err
	}
	defer tx.Rollback()

	// Supprimer tous les tags existants du post
	deleteQuery := `DELETE FROM post_tags WHERE post_id = $1`
	_, err = tx.Exec(deleteQuery, postID)
	if err != nil {
		log.Printf("[PostRepo][ERREUR] Impossible de supprimer les anciens tags: %v", err)
		return err
	}

	// Ajouter les nouveaux tags
	insertQuery := `INSERT INTO post_tags (post_id, category) VALUES ($1, $2)`
	for _, tag := range newTags {
		_, err = tx.Exec(insertQuery, postID, tag)
		if err != nil {
			log.Printf("[PostRepo][ERREUR] Impossible d'insérer le tag '%s': %v", tag, err)
			return err
		}
	}

	// Valider la transaction
	if err = tx.Commit(); err != nil {
		log.Printf("[PostRepo][ERREUR] Impossible de valider la transaction: %v", err)
		return err
	}

	log.Printf("[PostRepo] ✅ Tags mis à jour avec succès pour le post %d (%d tags)", postID, len(newTags))
	return nil
}

// =====================
// MÉTHODES POSTS EXISTANTES - Conservées
// =====================

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

// ListVisiblePosts retourne les posts visibles selon le rôle avec informations utilisateur complètes.
func ListVisiblePosts(userRole string) ([]domain.Post, error) {
	log.Printf("[PostRepo] Listing des posts visibles pour le rôle : %s", userRole)

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
		var username, firstName, lastName, avatarUrl, bio, role string
		var likesCount, commentsCount int

		if err := rows.Scan(
			&post.ID,
			&post.UserID,
			&post.Title,
			&post.Description,
			&post.MediaURL,
			&post.FileID,
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

		// Ajout des données utilisateur au post
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

// GetPostByID récupère un post par son ID avec ses tags
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
		&post.FileID,
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

	// Récupérer les tags du post
	tags, err := GetPostTags(postID)
	if err != nil {
		log.Printf("[PostRepo][WARN] Impossible de récupérer les tags du post %d: %v", postID, err)
		// Ne pas faire échouer la requête si les tags ne peuvent pas être récupérés
		post.Tags = []string{}
	} else {
		post.Tags = tags
	}

	log.Printf("[PostRepo] Post récupéré : %s (ID: %d) par %s avec %d tags", post.Title, post.ID, post.Username, len(post.Tags))
	return &post, nil
}

// =====================
// MÉTHODES RECOMMANDATIONS AVEC TAGS - Conservées et améliorées
// =====================

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

// getRecommendedPostsWithoutTags - VERSION CORRIGÉE avec nettoyage des prepared statements
func getRecommendedPostsWithoutTags(userID int64, limit, offset int) ([]interface{}, int, error) {
	log.Printf("[PostRepo] Recommandations sans filtrage tags pour user %d", userID)

	// Nettoyer les prepared statements existants au début
	_, err := database.DB.Exec("DEALLOCATE ALL")
	if err != nil {
		log.Printf("[PostRepo][WARN] Impossible de nettoyer les prepared statements: %v", err)
	}

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
			AND p.user_id != $1
		GROUP BY p.id, u.id
		ORDER BY 
			COUNT(DISTINCT l.user_id) * 2 + COUNT(DISTINCT c.id) * 3 DESC,
			p.created_at DESC
		LIMIT $2 OFFSET $3
	`

	args := []interface{}{userID, limit, offset}

	// Préparer explicitement la requête
	stmt, err := database.DB.Prepare(query)
	if err != nil {
		log.Printf("[PostRepo][ERREUR] Erreur préparation requête : %v", err)
		return nil, 0, err
	}
	defer stmt.Close()

	rows, err := stmt.Query(args...)
	if err != nil {
		log.Printf("[PostRepo][ERREUR] Erreur query posts recommandés : %v", err)
		return nil, 0, err
	}
	defer rows.Close()

	posts, err := scanPostsResults(rows)
	if err != nil {
		log.Printf("[PostRepo][ERREUR] Erreur scan results: %v", err)
		return nil, 0, err
	}

	// Compter le total
	total, err := countRecommendedPostsWithoutTags(userID)
	if err != nil {
		log.Printf("[PostRepo][WARN] Erreur count total : %v", err)
		total = len(posts)
	}

	log.Printf("[PostRepo] ✅ %d posts recommandés trouvés (total: %d)", len(posts), total)
	return posts, total, nil
}

// getRecommendedPostsWithTags - VERSION CORRIGÉE avec même approche
func getRecommendedPostsWithTags(userID int64, tags []string, limit, offset int) ([]interface{}, int, error) {
	log.Printf("[PostRepo] Recommandations avec filtrage tags: %v pour user %d", tags, userID)

	if len(tags) == 0 {
		log.Printf("[PostRepo] Aucun tag fourni, délégation vers getRecommendedPostsWithoutTags")
		return getRecommendedPostsWithoutTags(userID, limit, offset)
	}

	// Nettoyer les prepared statements existants
	_, err := database.DB.Exec("DEALLOCATE ALL")
	if err != nil {
		log.Printf("[PostRepo][WARN] Impossible de nettoyer les prepared statements: %v", err)
	}

	// Construction cohérente des arguments
	var args []interface{}
	var tagPlaceholders []string

	args = append(args, userID)
	for i, tag := range tags {
		args = append(args, tag)
		tagPlaceholders = append(tagPlaceholders, fmt.Sprintf("$%d", i+2))
	}
	args = append(args, limit, offset)
	limitPos := len(tags) + 2
	offsetPos := len(tags) + 3

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
		LIMIT $%d OFFSET $%d
	`, strings.Join(tagPlaceholders, ","), limitPos, offsetPos)

	// Préparer explicitement la requête
	stmt, err := database.DB.Prepare(query)
	if err != nil {
		log.Printf("[PostRepo][ERREUR] Erreur préparation requête avec tags : %v", err)
		return nil, 0, err
	}
	defer stmt.Close()

	rows, err := stmt.Query(args...)
	if err != nil {
		log.Printf("[PostRepo][ERREUR] Erreur query posts recommandés avec tags : %v", err)
		return nil, 0, err
	}
	defer rows.Close()

	posts, err := scanPostsResults(rows)
	if err != nil {
		log.Printf("[PostRepo][ERREUR] Erreur scan results: %v", err)
		return nil, 0, err
	}

	// Compter le total avec la même logique
	total, err := countRecommendedPostsWithTags(userID, tags)
	if err != nil {
		log.Printf("[PostRepo][WARN] Erreur count total avec tags : %v", err)
		total = len(posts)
	}

	log.Printf("[PostRepo] ✅ %d posts recommandés avec tags trouvés (total: %d)", len(posts), total)
	return posts, total, nil
}

// =====================
// FONCTIONS UTILITAIRES - Conservées
// =====================

// countRecommendedPostsWithoutTags - Fonction de comptage pour les posts sans tags
func countRecommendedPostsWithoutTags(userID int64) (int, error) {
	query := `
		SELECT COUNT(DISTINCT p.id)
		FROM posts p
		WHERE p.visibility = 'public' AND p.user_id != $1
	`

	var total int
	err := database.DB.QueryRow(query, userID).Scan(&total)
	if err != nil {
		log.Printf("[PostRepo][ERREUR] Erreur count posts sans tags : %v", err)
		return 0, err
	}

	return total, nil
}

// countRecommendedPostsWithTags - Fonction de comptage cohérente avec la requête principale
func countRecommendedPostsWithTags(userID int64, tags []string) (int, error) {
	if len(tags) == 0 {
		return countRecommendedPostsWithoutTags(userID)
	}

	var args []interface{}
	var tagPlaceholders []string

	args = append(args, userID)
	for i, tag := range tags {
		args = append(args, tag)
		tagPlaceholders = append(tagPlaceholders, fmt.Sprintf("$%d", i+2))
	}

	query := fmt.Sprintf(`
		SELECT COUNT(DISTINCT p.id)
		FROM posts p
		INNER JOIN post_tags pt ON p.id = pt.post_id
		WHERE p.visibility = 'public' 
			AND p.user_id != $1
			AND pt.category IN (%s)
	`, strings.Join(tagPlaceholders, ","))

	var total int
	err := database.DB.QueryRow(query, args...).Scan(&total)
	if err != nil {
		log.Printf("[PostRepo][ERREUR] Erreur count posts avec tags : %v", err)
		return 0, err
	}

	return total, nil
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

// =====================
// AUTRES MÉTHODES CONSERVÉES
// =====================

// ListPostsFromCreator retourne les posts d'un créateur, avec option pour inclure/exclure les posts privés.
func ListPostsFromCreator(creatorID int64, includePrivate bool) ([]*domain.Post, error) {
	log.Printf("[PostRepo] Listing des posts du créateur ID: %d (includePrivate: %v)", creatorID, includePrivate)

	query := `
		SELECT id, user_id, title, description, media_url, visibility, created_at, updated_at
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
		err := rows.Scan(&p.ID, &p.UserID, &p.Title, &p.Description, &p.MediaURL, &p.Visibility, &p.CreatedAt, &p.UpdatedAt)
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

// GetTagsStatistics retourne le nombre de posts pour chaque tag
func GetTagsStatistics() (map[string]int, error) {
	log.Printf("[PostRepo] 📊 Récupération des statistiques de tags")

	query := `
		SELECT 
			pt.category as tag,
			COUNT(DISTINCT p.id) as post_count
		FROM post_tags pt
		INNER JOIN posts p ON pt.post_id = p.id
		WHERE p.visibility = 'public'
		GROUP BY pt.category
		ORDER BY post_count DESC
	`

	rows, err := database.DB.Query(query)
	if err != nil {
		log.Printf("[PostRepo][ERREUR] Erreur query statistiques tags : %v", err)
		return nil, err
	}
	defer rows.Close()

	tagStats := make(map[string]int)

	for rows.Next() {
		var tag string
		var count int

		err := rows.Scan(&tag, &count)
		if err != nil {
			log.Printf("[PostRepo][ERREUR] Erreur scan stat tag : %v", err)
			continue
		}

		tagStats[tag] = count
	}

	if err = rows.Err(); err != nil {
		log.Printf("[PostRepo][ERREUR] Erreur itération rows stats : %v", err)
		return nil, err
	}

	log.Printf("[PostRepo] ✅ Statistiques tags récupérées : %v", tagStats)
	return tagStats, nil
}

// GetTotalPublicPosts retourne le nombre total de posts publics
func GetTotalPublicPosts() (int, error) {
	query := `SELECT COUNT(*) FROM posts WHERE visibility = 'public'`

	var total int
	err := database.DB.QueryRow(query).Scan(&total)
	if err != nil {
		log.Printf("[PostRepo][ERREUR] Erreur récupération total posts publics : %v", err)
		return 0, err
	}

	log.Printf("[PostRepo] 📊 Total posts publics : %d", total)
	return total, nil
}

// GetPostsByTag récupère tous les posts qui ont un tag spécifique
func GetPostsByTag(tagCategory string, limit, offset int) ([]int64, error) {
	log.Printf("[PostRepo] Recherche des posts avec le tag '%s' (limit: %d, offset: %d)", 
		tagCategory, limit, offset)

	query := `
		SELECT post_id 
		FROM post_tags 
		WHERE category = $1
		ORDER BY post_id DESC
		LIMIT $2 OFFSET $3
	`

	rows, err := database.DB.Query(query, tagCategory, limit, offset)
	if err != nil {
		log.Printf("[PostRepo][ERREUR] Erreur lors de la recherche des posts: %v", err)
		return nil, err
	}
	defer rows.Close()

	var postIDs []int64
	for rows.Next() {
		var postID int64
		if err := rows.Scan(&postID); err != nil {
			log.Printf("[PostRepo][ERREUR] Erreur lors du scan du post ID: %v", err)
			continue
		}
		postIDs = append(postIDs, postID)
	}

	if err = rows.Err(); err != nil {
		log.Printf("[PostRepo][ERREUR] Erreur lors du parcours des résultats: %v", err)
		return nil, err
	}

	log.Printf("[PostRepo] ✅ %d posts trouvés avec le tag '%s'", len(postIDs), tagCategory)
	return postIDs, nil
}

// CountPostsByTag compte le nombre de posts qui ont un tag spécifique
func CountPostsByTag(tagCategory string) (int, error) {
	log.Printf("[PostRepo] Comptage des posts avec le tag '%s'", tagCategory)

	query := `SELECT COUNT(*) FROM post_tags WHERE category = $1`

	var count int
	err := database.DB.QueryRow(query, tagCategory).Scan(&count)
	if err != nil {
		log.Printf("[PostRepo][ERREUR] Erreur lors du comptage: %v", err)
		return 0, err
	}

	log.Printf("[PostRepo] ✅ %d posts trouvés avec le tag '%s'", count, tagCategory)
	return count, nil
}

// GetAllTags récupère tous les tags distincts utilisés dans l'application
func GetAllTags() ([]string, error) {
	log.Println("[PostRepo] Récupération de tous les tags distincts")

	query := `
		SELECT DISTINCT category 
		FROM post_tags 
		ORDER BY category
	`

	rows, err := database.DB.Query(query)
	if err != nil {
		log.Printf("[PostRepo][ERREUR] Erreur lors de la récupération des tags: %v", err)
		return nil, err
	}
	defer rows.Close()

	var tags []string
	for rows.Next() {
		var tag string
		if err := rows.Scan(&tag); err != nil {
			log.Printf("[PostRepo][ERREUR] Erreur lors du scan du tag: %v", err)
			continue
		}
		tags = append(tags, tag)
	}

	if err = rows.Err(); err != nil {
		log.Printf("[PostRepo][ERREUR] Erreur lors du parcours des résultats: %v", err)
		return nil, err
	}

	log.Printf("[PostRepo] ✅ %d tags distincts récupérés: %v", len(tags), tags)
	return tags, nil
}

// TagExists vérifie si un tag spécifique existe dans la base de données
func TagExists(tagCategory string) (bool, error) {
	log.Printf("[PostRepo] Vérification de l'existence du tag '%s'", tagCategory)

	query := `SELECT EXISTS(SELECT 1 FROM post_tags WHERE category = $1)`

	var exists bool
	err := database.DB.QueryRow(query, tagCategory).Scan(&exists)
	if err != nil {
		log.Printf("[PostRepo][ERREUR] Erreur lors de la vérification: %v", err)
		return false, err
	}

	log.Printf("[PostRepo] ✅ Tag '%s' existe: %v", tagCategory, exists)
	return exists, nil
}