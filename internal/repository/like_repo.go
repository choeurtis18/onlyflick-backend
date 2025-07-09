package repository

import (
	"fmt"
	"log"
	"onlyflick/internal/database"
)

// IsLiked vérifie si un utilisateur a déjà liké un post.
func IsLiked(userID, postID int64) (bool, error) {
	var exists bool
	err := database.DB.QueryRow(
		"SELECT EXISTS(SELECT 1 FROM likes WHERE user_id = $1 AND post_id = $2)",
		userID, postID,
	).Scan(&exists)
	if err != nil {
		log.Printf("[IsLiked] Erreur lors de la vérification du like (userID=%d, postID=%d) : %v", userID, postID, err)
		return false, err
	}
	return exists, nil
}


// ToggleLike ajoute ou retire un like selon l'état actuel.
// Retourne true si le post est liké après l'appel, false sinon.
func ToggleLike(userID, postID int64) (bool, error) {
	liked, err := IsLiked(userID, postID)
	if err != nil {
		return false, err
	}

	if liked {
		_, err = database.DB.Exec(
			"DELETE FROM likes WHERE user_id = $1 AND post_id = $2",
			userID, postID,
		)
		if err != nil {
			log.Printf("[ToggleLike] Erreur lors du retrait du like (userID=%d, postID=%d) : %v", userID, postID, err)
			return false, fmt.Errorf("impossible de retirer le like : %w", err)
		}
		log.Printf("[ToggleLike] Like retiré (userID=%d, postID=%d)", userID, postID)
		return false, nil
	}

	_, err = database.DB.Exec(
		"INSERT INTO likes (user_id, post_id) VALUES ($1, $2)",
		userID, postID,
	)
	if err != nil {
		log.Printf("[ToggleLike] Erreur lors de l'ajout du like (userID=%d, postID=%d) : %v", userID, postID, err)
		return false, fmt.Errorf("impossible d'ajouter le like : %w", err)
	}
	log.Printf("[ToggleLike] Like ajouté (userID=%d, postID=%d)", userID, postID)
	return true, nil
}


// GetLikesCount retourne le nombre de likes pour un post donné.
func GetLikesCount(postID int64) (int, error) {
	var count int
	err := database.DB.QueryRow(
		"SELECT COUNT(*) FROM likes WHERE post_id = $1",
		postID,
	).Scan(&count)
	if err != nil {
		log.Printf("[GetLikesCount] Erreur lors de la récupération du nombre de likes (postID=%d) : %v", postID, err)
		return 0, err
	}
	return count, nil
}


// GetUserLikes retourne la liste des posts likés par un utilisateur
func GetUserLikes(userID int64) ([]int64, error) {
	query := "SELECT post_id FROM likes WHERE user_id = $1 ORDER BY created_at DESC"

	rows, err := database.DB.Query(query, userID)
	if err != nil {
		log.Printf("[GetUserLikes] Erreur lors de la récupération des likes (userID=%d) : %v", userID, err)
		return nil, fmt.Errorf("erreur récupération likes utilisateur : %w", err)
	}
	defer rows.Close()

	var likedPosts []int64
	for rows.Next() {
		var postID int64
		if err := rows.Scan(&postID); err != nil {
			log.Printf("[GetUserLikes] Erreur scan postID : %v", err)
			continue
		}
		likedPosts = append(likedPosts, postID)
	}

	if err := rows.Err(); err != nil {
		log.Printf("[GetUserLikes] Erreur itération rows : %v", err)
		return nil, fmt.Errorf("erreur itération résultats : %w", err)
	}

	log.Printf("[GetUserLikes] Utilisateur %d a liké %d posts", userID, len(likedPosts))
	return likedPosts, nil
}
