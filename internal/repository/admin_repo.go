package repository

import (
	"fmt"
	"log"
	"onlyflick/internal/database"
	"onlyflick/internal/domain"
)

// GetCreatorsStats récupère les statistiques des créateurs (nombre d'abonnés, de posts, et de likes).
func GetCreatorsStats() ([]domain.CreatorStats, error) {
	rows, err := database.DB.Query(`
		SELECT u.id, u.first_name, u.last_name,
			(SELECT COUNT(*) FROM subscriptions WHERE creator_id = u.id) AS subscribers_count,
			(SELECT COUNT(*) FROM posts WHERE user_id = u.id) AS posts_count,
			(SELECT COUNT(*) FROM likes WHERE post_id IN (SELECT id FROM posts WHERE user_id = u.id)) AS likes_count
		FROM users u
		WHERE u.role = 'creator'
	`)
	if err != nil {
		log.Printf("[GetCreatorsStats] Erreur lors de la récupération des statistiques des créateurs : %v", err)
		return nil, err
	}
	defer rows.Close()

	var creators []domain.CreatorStats
	for rows.Next() {
		var creator domain.CreatorStats
		if err := rows.Scan(&creator.ID, &creator.FirstName, &creator.LastName, &creator.SubscribersCount, &creator.PostsCount, &creator.LikesCount); err != nil {
			log.Printf("[GetCreatorsStats] Erreur lors du scan des données du créateur : %v", err)
			return nil, err
		}
		creators = append(creators, creator)
	}

	return creators, nil
}

// GetCreatorDetails récupère les détails d'un créateur (ses abonnés, ses posts, ses statistiques).
func GetCreatorDetails(creatorID int64) (*domain.CreatorDetails, error) {
	// Récupérer les informations du créateur
	var creator domain.CreatorDetails
	err := database.DB.QueryRow(`
		SELECT u.id, u.first_name, u.last_name, u.email
		FROM users u
		WHERE u.id = $1 AND u.role = 'creator'
	`, creatorID).Scan(&creator.ID, &creator.FirstName, &creator.LastName, &creator.Email)
	if err != nil {
		log.Printf("[GetCreatorDetails] Erreur récupération des infos créateur %d : %v", creatorID, err)
		return nil, fmt.Errorf("créateur introuvable")
	}

	// Récupérer les abonnés du créateur
	rows, err := database.DB.Query(`
		SELECT u.id, u.first_name, u.last_name, u.email
		FROM users u
		JOIN subscriptions s ON s.subscriber_id = u.id
		WHERE s.creator_id = $1
	`, creatorID)
	if err != nil {
		log.Printf("[GetCreatorDetails] Erreur récupération des abonnés pour créateur %d : %v", creatorID, err)
		return nil, err
	}
	defer rows.Close()

	for rows.Next() {
		var subscriber domain.User
		if err := rows.Scan(&subscriber.ID, &subscriber.FirstName, &subscriber.LastName, &subscriber.Email); err != nil {
			log.Printf("[GetCreatorDetails] Erreur scan des abonnés : %v", err)
			return nil, err
		}
		creator.Subscribers = append(creator.Subscribers, subscriber)
	}

	// Récupérer les posts du créateur
	postRows, err := database.DB.Query(`
		SELECT id, title, created_at FROM posts WHERE user_id = $1
	`, creatorID)
	if err != nil {
		log.Printf("[GetCreatorDetails] Erreur récupération des posts pour créateur %d : %v", creatorID, err)
		return nil, err
	}
	defer postRows.Close()

	for postRows.Next() {
		var post domain.Post
		if err := postRows.Scan(&post.ID, &post.Title, &post.CreatedAt); err != nil {
			log.Printf("[GetCreatorDetails] Erreur scan des posts : %v", err)
			return nil, err
		}
		creator.Posts = append(creator.Posts, post)
	}

	// Ajouter d'autres statistiques (exemple : nombre total de likes)
	var totalLikes int64
	err = database.DB.QueryRow(`
		SELECT COUNT(*) FROM likes WHERE post_id IN (SELECT id FROM posts WHERE user_id = $1)
	`, creatorID).Scan(&totalLikes)
	if err != nil {
		log.Printf("[GetCreatorDetails] Erreur récupération des likes pour créateur %d : %v", creatorID, err)
		return nil, err
	}
	creator.TotalLikes = totalLikes

	return &creator, nil
}

// GetGlobalStats récupère les statistiques globales de l'application.
func GetGlobalStats() (domain.GlobalStats, error) {
	var stats domain.GlobalStats
	err := database.DB.QueryRow(`
		SELECT
			(SELECT COUNT(*) FROM users) AS total_users,
			(SELECT COUNT(*) FROM posts) AS total_posts,
			(SELECT COUNT(*) FROM reports) AS total_reports,
			(SELECT SUM(amount) FROM payments) AS total_revenue
	`).Scan(&stats.TotalUsers, &stats.TotalPosts, &stats.TotalReports, &stats.TotalRevenue)
	if err != nil {
		log.Printf("[GetGlobalStats] Erreur récupération des statistiques globales : %v", err)
		return stats, err
	}

	return stats, nil
}
