package repository

import (
	"database/sql"
	"fmt"
	"log"
	"onlyflick/internal/database"
	"onlyflick/internal/domain"
	"strings"
	"time"
)

// ===== GESTION DES TAGS =====

// CreatePostTag ajoute un tag à un post
func CreatePostTag(tag *domain.PostTag) error {
	query := `
		INSERT INTO post_tags (post_id, category)
		VALUES ($1, $2)
		RETURNING id, created_at
	`
	err := database.DB.QueryRow(query, tag.PostID, tag.Category).
		Scan(&tag.ID, &tag.CreatedAt)
	if err != nil {
		log.Printf("[CreatePostTag][ERREUR] Impossible de créer le tag : %v", err)
		return err
	}
	log.Printf("[CreatePostTag] Tag créé: Post %d, Category %s", tag.PostID, tag.Category)
	return nil
}

// GetPostTags récupère tous les tags d'un post
func GetPostTags(postID int64) ([]domain.TagCategory, error) {
	query := `SELECT category FROM post_tags WHERE post_id = $1`
	rows, err := database.DB.Query(query, postID)
	if err != nil {
		log.Printf("[GetPostTags][ERREUR] Erreur requête tags post %d : %v", postID, err)
		return nil, err
	}
	defer rows.Close()

	var tags []domain.TagCategory
	for rows.Next() {
		var tag domain.TagCategory
		if err := rows.Scan(&tag); err != nil {
			log.Printf("[GetPostTags][ERREUR] Erreur scan tag : %v", err)
			return nil, err
		}
		tags = append(tags, tag)
	}
	return tags, nil
}

// DeletePostTags supprime tous les tags d'un post
func DeletePostTags(postID int64) error {
	query := `DELETE FROM post_tags WHERE post_id = $1`
	_, err := database.DB.Exec(query, postID)
	if err != nil {
		log.Printf("[DeletePostTags][ERREUR] Impossible de supprimer les tags du post %d : %v", postID, err)
	}
	return err
}

// ===== GESTION DES INTERACTIONS =====

// CreateUserInteraction enregistre une interaction utilisateur
func CreateUserInteraction(interaction *domain.UserInteraction) error {
	query := `
		INSERT INTO user_interactions (user_id, interaction_type, content_type, content_id, content_meta, score)
		VALUES ($1, $2, $3, $4, $5, $6)
		RETURNING id, created_at
	`
	err := database.DB.QueryRow(query, 
		interaction.UserID, 
		interaction.InteractionType, 
		interaction.ContentType,
		interaction.ContentID,
		interaction.ContentMeta,
		interaction.Score).
		Scan(&interaction.ID, &interaction.CreatedAt)
	
	if err != nil {
		log.Printf("[CreateUserInteraction][ERREUR] Impossible de créer l'interaction : %v", err)
		return err
	}
	log.Printf("[CreateUserInteraction] Interaction créée: User %d, Type %s", interaction.UserID, interaction.InteractionType)
	return nil
}

// GetUserInteractions récupère les interactions récentes d'un utilisateur
func GetUserInteractions(userID int64, limit int) ([]domain.UserInteraction, error) {
	query := `
		SELECT id, user_id, interaction_type, content_type, content_id, content_meta, score, created_at
		FROM user_interactions 
		WHERE user_id = $1 
		ORDER BY created_at DESC 
		LIMIT $2
	`
	rows, err := database.DB.Query(query, userID, limit)
	if err != nil {
		log.Printf("[GetUserInteractions][ERREUR] Erreur requête interactions user %d : %v", userID, err)
		return nil, err
	}
	defer rows.Close()

	var interactions []domain.UserInteraction
	for rows.Next() {
		var interaction domain.UserInteraction
		if err := rows.Scan(
			&interaction.ID,
			&interaction.UserID,
			&interaction.InteractionType,
			&interaction.ContentType,
			&interaction.ContentID,
			&interaction.ContentMeta,
			&interaction.Score,
			&interaction.CreatedAt,
		); err != nil {
			log.Printf("[GetUserInteractions][ERREUR] Erreur scan interaction : %v", err)
			return nil, err
		}
		interactions = append(interactions, interaction)
	}
	return interactions, nil
}

// ===== RECHERCHE D'UTILISATEURS =====

// SearchUsers recherche des utilisateurs par nom/username
func SearchUsers(searchTerm string, currentUserID int64, limit, offset int) ([]domain.UserSearchResult, int, error) {
	searchPattern := "%" + strings.ToLower(searchTerm) + "%"
	
	// Requête principale avec métadonnées
	query := `
		SELECT DISTINCT u.id, u.username, u.first_name, u.last_name, u.avatar_url, u.bio, u.role,
			(SELECT COUNT(*) FROM subscriptions WHERE creator_id = u.id) as followers_count,
			(SELECT COUNT(*) FROM posts WHERE user_id = u.id) as posts_count,
			CASE WHEN s.subscriber_id IS NOT NULL THEN true ELSE false END as is_following,
			0 as mutual_followers
		FROM users u
		LEFT JOIN subscriptions s ON s.creator_id = u.id AND s.subscriber_id = $2
		WHERE (LOWER(u.username) LIKE $1 OR LOWER(u.first_name) LIKE $1 OR LOWER(u.last_name) LIKE $1)
			AND u.id != $2
		ORDER BY 
			CASE WHEN LOWER(u.username) = LOWER($3) THEN 1 ELSE 2 END,
			followers_count DESC
		LIMIT $4 OFFSET $5
	`
	
	rows, err := database.DB.Query(query, searchPattern, currentUserID, searchTerm, limit, offset)
	if err != nil {
		log.Printf("[SearchUsers][ERREUR] Erreur requête recherche users : %v", err)
		return nil, 0, err
	}
	defer rows.Close()

	var users []domain.UserSearchResult
	for rows.Next() {
		var user domain.UserSearchResult
		var avatarURL, bio sql.NullString
		
		if err := rows.Scan(
			&user.ID,
			&user.Username,
			&user.FirstName,
			&user.LastName,
			&avatarURL,
			&bio,
			&user.Role,
			&user.FollowersCount,
			&user.PostsCount,
			&user.IsFollowing,
			&user.MutualFollowers,
		); err != nil {
			log.Printf("[SearchUsers][ERREUR] Erreur scan user : %v", err)
			return nil, 0, err
		}

		if avatarURL.Valid {
			user.AvatarURL = avatarURL.String
		}
		if bio.Valid {
			user.Bio = bio.String
		}
		
		users = append(users, user)
	}

	// Compter le total pour pagination
	countQuery := `
		SELECT COUNT(DISTINCT u.id)
		FROM users u
		WHERE (LOWER(u.username) LIKE $1 OR LOWER(u.first_name) LIKE $1 OR LOWER(u.last_name) LIKE $1)
			AND u.id != $2
	`
	var total int
	err = database.DB.QueryRow(countQuery, searchPattern, currentUserID).Scan(&total)
	if err != nil {
		log.Printf("[SearchUsers][ERREUR] Erreur count users : %v", err)
		return users, 0, err
	}

	log.Printf("[SearchUsers] Trouvé %d users pour '%s'", len(users), searchTerm)
	return users, total, nil
}

// ===== RECHERCHE DE POSTS AVEC FILTRES =====

// SearchPosts recherche des posts avec filtres et tri
func SearchPosts(request domain.SearchRequest) ([]domain.PostWithDetails, int, error) {
	// Construction de la requête dynamique
	var whereConditions []string
	var args []interface{}
	argIndex := 1

	// Condition de base : posts publics ou de créateurs suivis
	baseCondition := `(p.visibility = 'public' OR (p.visibility = 'subscriber' AND s.subscriber_id = $1))`
	whereConditions = append(whereConditions, baseCondition)
	args = append(args, request.UserID)
	argIndex++

	// Filtre par terme de recherche
	if request.Query != "" {
		searchPattern := "%" + strings.ToLower(request.Query) + "%"
		whereConditions = append(whereConditions, fmt.Sprintf("(LOWER(p.title) LIKE $%d OR LOWER(p.description) LIKE $%d)", argIndex, argIndex))
		args = append(args, searchPattern)
		argIndex++
	}

	// Filtre par tags
	if len(request.Tags) > 0 {
		tagPlaceholders := make([]string, len(request.Tags))
		for i, tag := range request.Tags {
			tagPlaceholders[i] = fmt.Sprintf("$%d", argIndex)
			args = append(args, tag)
			argIndex++
		}
		whereConditions = append(whereConditions, fmt.Sprintf("pt.category IN (%s)", strings.Join(tagPlaceholders, ",")))
	}

	// Construction de l'ORDER BY selon le type de tri
	var orderBy string
	switch request.SortBy {
	case domain.SortRelevance:
		orderBy = "pm.popularity_score DESC, p.created_at DESC"
	case domain.SortPopular24h:
		whereConditions = append(whereConditions, "p.created_at >= NOW() - INTERVAL '24 hours'")
		orderBy = "pm.popularity_score DESC"
	case domain.SortPopularWeek:
		whereConditions = append(whereConditions, "p.created_at >= NOW() - INTERVAL '7 days'")
		orderBy = "pm.popularity_score DESC"
	case domain.SortPopularMonth:
		whereConditions = append(whereConditions, "p.created_at >= NOW() - INTERVAL '30 days'")
		orderBy = "pm.popularity_score DESC"
	case domain.SortRecent:
		orderBy = "p.created_at DESC"
	default:
		orderBy = "p.created_at DESC"
	}

	// Requête principale
	query := fmt.Sprintf(`
		SELECT DISTINCT p.id, p.user_id, p.title, p.description, p.media_url, p.file_id, 
			p.visibility, p.created_at, p.updated_at,
			u.id, u.username, u.first_name, u.last_name, u.avatar_url, u.bio, u.role,
			COALESCE(pm.views_count, 0) as views_count,
			COALESCE(pm.likes_count, 0) as likes_count,
			COALESCE(pm.comments_count, 0) as comments_count,
			COALESCE(pm.popularity_score, 0) as popularity_score,
			CASE WHEN l.user_id IS NOT NULL THEN true ELSE false END as is_liked
		FROM posts p
		INNER JOIN users u ON p.user_id = u.id
		LEFT JOIN subscriptions s ON s.creator_id = p.user_id AND s.subscriber_id = $1
		LEFT JOIN post_tags pt ON pt.post_id = p.id
		LEFT JOIN post_metrics pm ON pm.post_id = p.id
		LEFT JOIN likes l ON l.post_id = p.id AND l.user_id = $1
		WHERE %s
		ORDER BY %s
		LIMIT $%d OFFSET $%d
	`, strings.Join(whereConditions, " AND "), orderBy, argIndex, argIndex+1)

	args = append(args, request.Limit, request.Offset)

	rows, err := database.DB.Query(query, args...)
	if err != nil {
		log.Printf("[SearchPosts][ERREUR] Erreur requête recherche posts : %v", err)
		return nil, 0, err
	}
	defer rows.Close()

	var posts []domain.PostWithDetails
	for rows.Next() {
		var post domain.PostWithDetails
		var fileID, avatarURL, bio sql.NullString
		
		if err := rows.Scan(
			&post.ID, &post.UserID, &post.Title, &post.Description, &post.MediaURL,
			&fileID, &post.Visibility, &post.CreatedAt, &post.UpdatedAt,
			&post.Author.ID, &post.Author.Username, &post.Author.FirstName, 
			&post.Author.LastName, &avatarURL, &bio, &post.Author.Role,
			&post.ViewsCount, &post.LikesCount, &post.CommentsCount, 
			&post.PopularityScore, &post.IsLiked,
		); err != nil {
			log.Printf("[SearchPosts][ERREUR] Erreur scan post : %v", err)
			return nil, 0, err
		}

		if fileID.Valid {
			post.FileID = fileID.String
		}
		if avatarURL.Valid {
			post.Author.AvatarURL = avatarURL.String
		}
		if bio.Valid {
			post.Author.Bio = bio.String
		}

		// Récupérer les tags du post
		tags, _ := GetPostTags(post.ID)
		post.Tags = tags

		// Compter les commentaires
		var commentsCount int64
		database.DB.QueryRow("SELECT COUNT(*) FROM comments WHERE post_id = $1", post.ID).Scan(&commentsCount)
		post.CommentsCount = commentsCount

		posts = append(posts, post)
	}

	// Compter le total pour pagination
	countQuery := fmt.Sprintf(`
		SELECT COUNT(DISTINCT p.id)
		FROM posts p
		INNER JOIN users u ON p.user_id = u.id
		LEFT JOIN subscriptions s ON s.creator_id = p.user_id AND s.subscriber_id = $1
		LEFT JOIN post_tags pt ON pt.post_id = p.id
		WHERE %s
	`, strings.Join(whereConditions, " AND "))

	var total int
	err = database.DB.QueryRow(countQuery, args[:len(args)-2]...).Scan(&total)
	if err != nil {
		log.Printf("[SearchPosts][ERREUR] Erreur count posts : %v", err)
		return posts, 0, err
	}

	log.Printf("[SearchPosts] Trouvé %d posts pour requête", len(posts))
	return posts, total, nil
}

// ===== FEED DE DÉCOUVERTE =====

// GetDiscoveryPosts récupère des posts pour le feed de découverte basé sur l'algorithme
func GetDiscoveryPosts(request domain.DiscoveryRequest) ([]domain.PostWithDetails, error) {
	// Récupérer les préférences utilisateur pour personnaliser
	userPrefs, _ := GetUserPreferences(request.UserID)
	
	// Construction de la requête de découverte
	var whereConditions []string
	var args []interface{}
	argIndex := 1

	// Posts publics ou de créateurs non suivis (découverte)
	baseCondition := `(p.visibility = 'public' AND p.user_id NOT IN 
		(SELECT creator_id FROM subscriptions WHERE subscriber_id = $1)
		AND p.user_id != $1)`
	whereConditions = append(whereConditions, baseCondition)
	args = append(args, request.UserID)
	argIndex++

	// Filtre par tags si spécifié
	if len(request.Tags) > 0 {
		tagPlaceholders := make([]string, len(request.Tags))
		for i, tag := range request.Tags {
			tagPlaceholders[i] = fmt.Sprintf("$%d", argIndex)
			args = append(args, tag)
			argIndex++
		}
		whereConditions = append(whereConditions, fmt.Sprintf("pt.category IN (%s)", strings.Join(tagPlaceholders, ",")))
	}

	// Boost des posts avec tags préférés de l'utilisateur
	var scoreBoost string
	if len(userPrefs.PreferredTags) > 0 {
		scoreBoost = `COALESCE(pm.popularity_score, 0) + 
			CASE 
				WHEN pt.category = ANY($` + fmt.Sprintf("%d", argIndex) + `) THEN 10.0 
				ELSE 0.0 
			END as relevance_score`
		
		preferredTags := make([]string, 0, len(userPrefs.PreferredTags))
		for tag := range userPrefs.PreferredTags {
			preferredTags = append(preferredTags, string(tag))
		}
		args = append(args, preferredTags)
		argIndex++
	} else {
		scoreBoost = "COALESCE(pm.popularity_score, 0) as relevance_score"
	}

	// Tri selon la demande
	var orderBy string
	switch request.SortBy {
	case domain.SortRelevance:
		orderBy = "relevance_score DESC, p.created_at DESC"
	case domain.SortPopular24h:
		whereConditions = append(whereConditions, "p.created_at >= NOW() - INTERVAL '24 hours'")
		orderBy = "pm.popularity_score DESC"
	case domain.SortPopularWeek:
		whereConditions = append(whereConditions, "p.created_at >= NOW() - INTERVAL '7 days'")
		orderBy = "pm.popularity_score DESC"
	case domain.SortPopularMonth:
		whereConditions = append(whereConditions, "p.created_at >= NOW() - INTERVAL '30 days'")
		orderBy = "pm.popularity_score DESC"
	default:
		orderBy = "p.created_at DESC"
	}

	query := fmt.Sprintf(`
		SELECT DISTINCT p.id, p.user_id, p.title, p.description, p.media_url, p.file_id,
			p.visibility, p.created_at, p.updated_at,
			u.id, u.username, u.first_name, u.last_name, u.avatar_url, u.bio, u.role,
			COALESCE(pm.views_count, 0) as views_count,
			COALESCE(pm.likes_count, 0) as likes_count,
			COALESCE(pm.comments_count, 0) as comments_count,
			%s,
			CASE WHEN l.user_id IS NOT NULL THEN true ELSE false END as is_liked
		FROM posts p
		INNER JOIN users u ON p.user_id = u.id
		LEFT JOIN post_tags pt ON pt.post_id = p.id
		LEFT JOIN post_metrics pm ON pm.post_id = p.id
		LEFT JOIN likes l ON l.post_id = p.id AND l.user_id = $1
		WHERE %s
		ORDER BY %s
		LIMIT $%d OFFSET $%d
	`, scoreBoost, strings.Join(whereConditions, " AND "), orderBy, argIndex, argIndex+1)

	args = append(args, request.Limit, request.Offset)

	rows, err := database.DB.Query(query, args...)
	if err != nil {
		log.Printf("[GetDiscoveryPosts][ERREUR] Erreur requête découverte : %v", err)
		return nil, err
	}
	defer rows.Close()

	var posts []domain.PostWithDetails
	for rows.Next() {
		var post domain.PostWithDetails
		var fileID, avatarURL, bio sql.NullString
		
		if err := rows.Scan(
			&post.ID, &post.UserID, &post.Title, &post.Description, &post.MediaURL,
			&fileID, &post.Visibility, &post.CreatedAt, &post.UpdatedAt,
			&post.Author.ID, &post.Author.Username, &post.Author.FirstName,
			&post.Author.LastName, &avatarURL, &bio, &post.Author.Role,
			&post.ViewsCount, &post.LikesCount, &post.CommentsCount,
			&post.RelevanceScore, &post.IsLiked,
		); err != nil {
			log.Printf("[GetDiscoveryPosts][ERREUR] Erreur scan post découverte : %v", err)
			return nil, err
		}

		if fileID.Valid {
			post.FileID = fileID.String
		}
		if avatarURL.Valid {
			post.Author.AvatarURL = avatarURL.String
		}
		if bio.Valid {
			post.Author.Bio = bio.String
		}

		// Récupérer les tags
		tags, _ := GetPostTags(post.ID)
		post.Tags = tags

		posts = append(posts, post)
	}

	log.Printf("[GetDiscoveryPosts] Découverte: %d posts pour user %d", len(posts), request.UserID)
	return posts, nil
}

// ===== MÉTRIQUES ET PRÉFÉRENCES =====

// UpdatePostMetrics met à jour les métriques d'un post
func UpdatePostMetrics(postID int64) error {
	query := `
		INSERT INTO post_metrics (post_id, views_count, likes_count, comments_count, popularity_score, last_updated)
		VALUES ($1, 
			(SELECT COUNT(*) FROM user_interactions WHERE content_type = 'post' AND content_id = $1 AND interaction_type = 'view'),
			(SELECT COUNT(*) FROM likes WHERE post_id = $1),
			(SELECT COUNT(*) FROM comments WHERE post_id = $1),
			0, NOW())
		ON CONFLICT (post_id) 
		DO UPDATE SET
			views_count = (SELECT COUNT(*) FROM user_interactions WHERE content_type = 'post' AND content_id = $1 AND interaction_type = 'view'),
			likes_count = (SELECT COUNT(*) FROM likes WHERE post_id = $1),
			comments_count = (SELECT COUNT(*) FROM comments WHERE post_id = $1),
			last_updated = NOW()
	`
	_, err := database.DB.Exec(query, postID)
	if err != nil {
		log.Printf("[UpdatePostMetrics][ERREUR] Erreur mise à jour métriques post %d : %v", postID, err)
		return err
	}

	// Calculer et mettre à jour le score de popularité
	updateScoreQuery := `
		UPDATE post_metrics 
		SET popularity_score = (likes_count * 1.0 + comments_count * 2.0 + views_count * 0.1)
		WHERE post_id = $1
	`
	_, err = database.DB.Exec(updateScoreQuery, postID)
	if err != nil {
		log.Printf("[UpdatePostMetrics][ERREUR] Erreur calcul score popularité : %v", err)
	}

	return err
}

// GetUserPreferences récupère les préférences calculées d'un utilisateur
func GetUserPreferences(userID int64) (*domain.UserPreferences, error) {
	// Calculer les préférences basées sur les interactions récentes
	preferences := &domain.UserPreferences{
		UserID:         userID,
		PreferredTags:  make(map[domain.TagCategory]float64),
		LastUpdated:    time.Now(),
	}

	// Calculer les scores par tag basés sur les interactions
	query := `
		SELECT ui.content_meta, SUM(ui.score) as total_score, COUNT(*) as interaction_count
		FROM user_interactions ui
		WHERE ui.user_id = $1 
			AND ui.content_type = 'tag' 
			AND ui.created_at >= NOW() - INTERVAL '30 days'
		GROUP BY ui.content_meta
		ORDER BY total_score DESC
	`
	rows, err := database.DB.Query(query, userID)
	if err != nil {
		log.Printf("[GetUserPreferences][ERREUR] Erreur requête préférences : %v", err)
		return preferences, err
	}
	defer rows.Close()

	for rows.Next() {
		var tagStr string
		var score float64
		var count int
		if err := rows.Scan(&tagStr, &score, &count); err != nil {
			continue
		}
		preferences.PreferredTags[domain.TagCategory(tagStr)] = score
	}

	// Récupérer les créateurs préférés (les plus likés)
	creatorQuery := `
		SELECT p.user_id, COUNT(*) as like_count
		FROM likes l
		INNER JOIN posts p ON l.post_id = p.id
		WHERE l.user_id = $1
		GROUP BY p.user_id
		ORDER BY like_count DESC
		LIMIT 10
	`
	creatorRows, err := database.DB.Query(creatorQuery, userID)
	if err == nil {
		defer creatorRows.Close()
		for creatorRows.Next() {
			var creatorID int64
			var likeCount int
			if err := creatorRows.Scan(&creatorID, &likeCount); err == nil {
				preferences.PreferredCreators = append(preferences.PreferredCreators, creatorID)
			}
		}
	}

	log.Printf("[GetUserPreferences] Préférences calculées pour user %d: %d tags, %d créateurs", 
		userID, len(preferences.PreferredTags), len(preferences.PreferredCreators))
	return preferences, nil
}

// GetTrendingTags récupère les tags en tendance
func GetTrendingTags(period string, limit int) ([]domain.TrendingTag, error) {
	var timeCondition string
	switch period {
	case "24h":
		timeCondition = "p.created_at >= NOW() - INTERVAL '24 hours'"
	case "week":
		timeCondition = "p.created_at >= NOW() - INTERVAL '7 days'"
	case "month":
		timeCondition = "p.created_at >= NOW() - INTERVAL '30 days'"
	default:
		timeCondition = "p.created_at >= NOW() - INTERVAL '7 days'"
		period = "week"
	}

	query := fmt.Sprintf(`
		SELECT pt.category, COUNT(*) as posts_count,
			COUNT(*) * 1.0 / GREATEST(1, EXTRACT(epoch FROM (NOW() - MIN(p.created_at)))/86400) as growth_rate
		FROM post_tags pt
		INNER JOIN posts p ON pt.post_id = p.id
		WHERE %s
		GROUP BY pt.category
		HAVING COUNT(*) >= 3
		ORDER BY growth_rate DESC, posts_count DESC
		LIMIT $1
	`, timeCondition)

	rows, err := database.DB.Query(query, limit)
	if err != nil {
		log.Printf("[GetTrendingTags][ERREUR] Erreur requête trending tags : %v", err)
		return nil, err
	}
	defer rows.Close()

	var trends []domain.TrendingTag
	for rows.Next() {
		var trend domain.TrendingTag
		if err := rows.Scan(&trend.Category, &trend.PostsCount, &trend.GrowthRate); err != nil {
			log.Printf("[GetTrendingTags][ERREUR] Erreur scan trending tag : %v", err)
			continue
		}
		trend.Period = period
		trend.TrendingScore = float64(trend.PostsCount) * trend.GrowthRate
		trends = append(trends, trend)
	}

	log.Printf("[GetTrendingTags] Trouvé %d tags trending pour période %s", len(trends), period)
	return trends, nil
}