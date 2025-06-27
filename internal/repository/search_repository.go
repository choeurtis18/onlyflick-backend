// internal/repository/search_repository.go

package repository

import (
	"database/sql"
	"fmt"
	"log"
	"strings"
	"time"

	"onlyflick/internal/database"
	"onlyflick/internal/domain"
)

// ===== RECHERCHE D'UTILISATEURS =====

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

// ===== RECHERCHE DE POSTS =====

func SearchPosts(searchRequest domain.SearchRequest) ([]interface{}, int, error) {
	log.Printf("[SearchPosts] 🔍 Recherche posts: query='%s', tags=%v, sort=%s", 
		searchRequest.Query, searchRequest.Tags, searchRequest.SortBy)

	var whereConditions []string
	var args []interface{}
	argIndex := 1

	baseCondition := fmt.Sprintf(`
	(p.visibility = 'public' 
	OR (
		p.visibility = 'subscriber' AND EXISTS (
			SELECT 1 FROM subscriptions s 
			WHERE s.subscriber_id = $%d 
			AND s.creator_id = p.user_id 
			AND s.status = TRUE
		)
	))`, argIndex)

	whereConditions = append(whereConditions, baseCondition)
	args = append(args, searchRequest.UserID)
	argIndex++

	// Préparer les tags (si présents)
	var tagPlaceholders []string
	if len(searchRequest.Tags) > 0 {
		for _, tag := range searchRequest.Tags {
			tagPlaceholders = append(tagPlaceholders, fmt.Sprintf("$%d", argIndex))
			args = append(args, string(tag))
			argIndex++
		}
	}

	// Clause de tri
	var orderBy string
	switch searchRequest.SortBy {
	case domain.SortPopular24h:
		orderBy = `ORDER BY 
			(SELECT COUNT(*) FROM likes l WHERE l.post_id = p.id AND l.created_at > NOW() - INTERVAL '24 hours') DESC,
			p.created_at DESC`
	case domain.SortPopularWeek:
		orderBy = `ORDER BY 
			(SELECT COUNT(*) FROM likes l WHERE l.post_id = p.id AND l.created_at > NOW() - INTERVAL '7 days') DESC,
			p.created_at DESC`
	case domain.SortPopularMonth:
		orderBy = `ORDER BY 
			(SELECT COUNT(*) FROM likes l WHERE l.post_id = p.id AND l.created_at > NOW() - INTERVAL '30 days') DESC,
			p.created_at DESC`
	case domain.SortRelevance:
		orderBy = `ORDER BY 
			(SELECT COUNT(*) FROM likes l WHERE l.post_id = p.id) * 2 +
			(SELECT COUNT(*) FROM comments c WHERE c.post_id = p.id) * 3 +
			EXTRACT(EPOCH FROM (NOW() - p.created_at)) / 3600 DESC,
			p.created_at DESC`
	default:
		orderBy = `ORDER BY p.created_at DESC`
	}

	// JOIN conditionnel pour post_tags
	tagJoin := "LEFT JOIN post_tags pt ON p.id = pt.post_id"
	if len(searchRequest.Tags) > 0 {
		tagJoin = "INNER JOIN post_tags pt ON p.id = pt.post_id"
		whereConditions = append(whereConditions, fmt.Sprintf("pt.category IN (%s)", strings.Join(tagPlaceholders, ",")))
	}

	// Requête principale
	query := fmt.Sprintf(`
		SELECT 
			p.id,
			p.title,
			p.description,
			p.media_url,
			p.visibility,
			p.created_at,
			p.user_id AS author_id,
			COALESCE(u.first_name || ' ' || u.last_name, u.username) as author_name,
			COALESCE(COUNT(DISTINCT l.user_id), 0) as likes_count,
			COALESCE(COUNT(DISTINCT c.id), 0) as comments_count,
			ARRAY_AGG(DISTINCT pt.category) FILTER (WHERE pt.category IS NOT NULL) as tags
		FROM posts p
		JOIN users u ON p.user_id = u.id
		LEFT JOIN likes l ON p.id = l.post_id
		LEFT JOIN comments c ON p.id = c.post_id
		%s
		WHERE %s
		GROUP BY p.id, u.id
		%s
		LIMIT $%d OFFSET $%d
	`, tagJoin, strings.Join(whereConditions, " AND "), orderBy, argIndex, argIndex+1)

	args = append(args, searchRequest.Limit, searchRequest.Offset)

	log.Printf("[SearchPosts] Exécution requête SQL avec %d arguments", len(args))

	rows, err := database.DB.Query(query, args...)
	if err != nil {
		log.Printf("[SearchPosts][ERREUR] Erreur requête posts : %v", err)
		return nil, 0, err
	}
	defer rows.Close()

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
			log.Printf("[SearchPosts][ERREUR] Erreur scan post : %v", err)
			continue
		}

		if tagsArray.Valid {
			post.Tags = strings.Split(strings.Trim(tagsArray.String, "{}"), ",")
		}

		posts = append(posts, post)
	}

	// Requête COUNT (sans LIMIT/OFFSET)
	countQuery := fmt.Sprintf(`
		SELECT COUNT(DISTINCT p.id)
		FROM posts p
		JOIN users u ON p.user_id = u.id
		%s
		WHERE %s
	`, tagJoin, strings.Join(whereConditions, " AND "))

	var total int
	err = database.DB.QueryRow(countQuery, args[:len(args)-2]...).Scan(&total)
	if err != nil {
		log.Printf("[SearchPosts][ERREUR] Erreur count posts : %v", err)
		total = len(posts)
	}

	log.Printf("[SearchPosts] ✅ Trouvé %d posts (total: %d)", len(posts), total)
	return posts, total, nil
}


// ===== DÉCOUVERTE DE POSTS =====

// GetDiscoveryPosts retourne des posts recommandés pour la découverte
func GetDiscoveryPosts(discoveryRequest domain.DiscoveryRequest) ([]interface{}, error) {
	log.Printf("[GetDiscoveryPosts] 🎯 Découverte posts: userID=%d, tags=%v, sort=%s", 
		discoveryRequest.UserID, discoveryRequest.Tags, discoveryRequest.SortBy)

	// Convertir en SearchRequest et utiliser la même logique
	searchRequest := domain.SearchRequest{
		Query:      "", // Pas de requête texte pour la découverte
		UserID:     discoveryRequest.UserID,
		Tags:       discoveryRequest.Tags,
		SortBy:     discoveryRequest.SortBy,
		Limit:      discoveryRequest.Limit,
		Offset:     discoveryRequest.Offset,
		SearchType: "discovery",
	}

	posts, _, err := SearchPosts(searchRequest)
	if err != nil {
		return nil, err
	}

	log.Printf("[GetDiscoveryPosts] ✅ %d posts découverte trouvés", len(posts))
	return posts, nil
}

// ===== TRACKING DES INTERACTIONS =====

// TrackInteraction enregistre une interaction utilisateur pour l'algorithme de recommandation
func TrackInteraction(userID int64, interactionType domain.InteractionType, contentType string, contentID int64, contentMeta string) error {
	log.Printf("[TrackInteraction] 📊 Tracking: user=%d, type=%s, content=%s:%d", 
		userID, interactionType, contentType, contentID)

	// Vérifier si la table existe
	var exists bool
	err := database.DB.QueryRow(`
		SELECT EXISTS (
			SELECT FROM information_schema.tables 
			WHERE table_schema = 'public' 
			AND table_name = 'user_interactions'
		)
	`).Scan(&exists)
	
	if err != nil {
		log.Printf("[TrackInteraction][ERREUR] Vérification table : %v", err)
		return err
	}

	if !exists {
		log.Printf("[TrackInteraction] ⚠️ Table user_interactions n'existe pas, création...")
		
		// Créer la table si elle n'existe pas
		createTableQuery := `
			CREATE TABLE IF NOT EXISTS user_interactions (
				id SERIAL PRIMARY KEY,
				user_id BIGINT NOT NULL,
				interaction_type VARCHAR(50) NOT NULL,
				content_type VARCHAR(50) NOT NULL,
				content_id BIGINT NOT NULL,
				content_meta TEXT,
				score DECIMAL(10,2) DEFAULT 1.0,
				created_at TIMESTAMP DEFAULT NOW()
			)
		`
		
		if _, err := database.DB.Exec(createTableQuery); err != nil {
			log.Printf("[TrackInteraction][ERREUR] Création table : %v", err)
			return err
		}
		
		log.Printf("[TrackInteraction] ✅ Table user_interactions créée")
	}

	// Calculer le score selon le type d'interaction
	score := calculateInteractionScore(interactionType)

	// Insérer l'interaction
	query := `
		INSERT INTO user_interactions (user_id, interaction_type, content_type, content_id, content_meta, score, created_at)
		VALUES ($1, $2, $3, $4, $5, $6, NOW())
	`

	_, err = database.DB.Exec(query, userID, string(interactionType), contentType, contentID, contentMeta, score)
	if err != nil {
		log.Printf("[TrackInteraction][ERREUR] Insertion interaction : %v", err)
		return err
	}

	log.Printf("[TrackInteraction] ✅ Interaction enregistrée: score=%.1f", score)
	return nil
}

// ===== FONCTIONS UTILITAIRES =====

// calculateInteractionScore calcule le score d'une interaction selon son type
func calculateInteractionScore(interactionType domain.InteractionType) float64 {
	switch interactionType {
	case domain.InteractionView:
		return 0.5
	case domain.InteractionLike:
		return 1.0
	case domain.InteractionComment:
		return 2.0
	case domain.InteractionShare:
		return 3.0
	case domain.InteractionProfileView:
		return 0.3
	case domain.InteractionSearch:
		return 0.2
	case domain.InteractionTagClick:
		return 0.4
	default:
		return 1.0
	}
}

// ===== FONCTIONS DE MAINTENANCE =====

// CleanupOldInteractions nettoie les anciennes interactions (optionnel)
func CleanupOldInteractions(daysToKeep int) error {
	log.Printf("[CleanupOldInteractions] 🧹 Nettoyage interactions > %d jours", daysToKeep)

	query := `
		DELETE FROM user_interactions 
		WHERE created_at < NOW() - INTERVAL '%d days'
	`

	result, err := database.DB.Exec(fmt.Sprintf(query, daysToKeep))
	if err != nil {
		log.Printf("[CleanupOldInteractions][ERREUR] : %v", err)
		return err
	}

	rowsAffected, _ := result.RowsAffected()
	log.Printf("[CleanupOldInteractions] ✅ %d interactions supprimées", rowsAffected)
	return nil
}

// GetSearchStats retourne des statistiques de recherche pour un utilisateur
func GetSearchStats(userID int64) (map[string]interface{}, error) {
	log.Printf("[GetSearchStats] 📈 Stats pour user %d", userID)

	// Pour l'instant, retourner des stats basiques
	stats := map[string]interface{}{
		"total_searches":     0,
		"total_interactions": 0,
		"recent_searches":    []string{},
		"popular_tags":       []string{"art", "music", "tech", "travel"},
		"status":            "basic",
	}

	// Compter les interactions si la table existe
	var interactionCount int
	err := database.DB.QueryRow(`
		SELECT COUNT(*) FROM user_interactions 
		WHERE user_id = $1 AND created_at > NOW() - INTERVAL '30 days'
	`, userID).Scan(&interactionCount)
	
	if err == nil {
		stats["total_interactions"] = interactionCount
	}

	log.Printf("[GetSearchStats] ✅ Stats récupérées pour user %d", userID)
	return stats, nil
}