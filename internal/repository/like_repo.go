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
		"SELECT EXISTS(SELECT 1 FROM likes WHERE user_id=$1 AND post_id=$2)",
		userID, postID,
	).Scan(&exists)
	if err != nil {
		log.Printf("Erreur lors de la vérification du like (userID=%d, postID=%d) : %v", userID, postID, err)
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
		_, err = database.DB.Exec("DELETE FROM likes WHERE user_id=$1 AND post_id=$2", userID, postID)
		if err != nil {
			log.Printf("Erreur lors du retrait du like (userID=%d, postID=%d) : %v", userID, postID, err)
			return false, fmt.Errorf("impossible de retirer le like : %w", err)
		}
		log.Printf("Like retiré (userID=%d, postID=%d)", userID, postID)
		return false, nil
	}

	_, err = database.DB.Exec("INSERT INTO likes (user_id, post_id) VALUES ($1, $2)", userID, postID)
	if err != nil {
		log.Printf("Erreur lors de l'ajout du like (userID=%d, postID=%d) : %v", userID, postID, err)
		return false, fmt.Errorf("impossible d'ajouter le like : %w", err)
	}
	log.Printf("Like ajouté (userID=%d, postID=%d)", userID, postID)
	return true, nil
}

// GetLikesCount retourne le nombre de likes pour un post donné.
func GetLikesCount(postID int64) (int, error) {
	var count int
	err := database.DB.QueryRow(
		"SELECT COUNT(*) FROM likes WHERE post_id=$1",
		postID,
	).Scan(&count)
	if err != nil {
		log.Printf("Erreur lors de la récupération du nombre de likes (postID=%d) : %v", postID, err)
		return 0, err
	}
	return count, nil
}
