package handler

import (
	"log"
	"net/http"
	"onlyflick/internal/middleware"
	"onlyflick/internal/repository"
	"onlyflick/pkg/response"
	"strconv"

	"github.com/go-chi/chi/v5"
)

// LikePost permet à un utilisateur de liker ou retirer son like sur un post.
func LikePost(w http.ResponseWriter, r *http.Request) {
	userIDVal := r.Context().Value(middleware.ContextUserIDKey)
	userID, ok := userIDVal.(int64)
	if !ok {
		log.Println("[LikePost] userID introuvable dans le contexte")
		response.RespondWithError(w, http.StatusUnauthorized, "Utilisateur non authentifié")
		return
	}

	postIDStr := chi.URLParam(r, "id")
	postID, err := strconv.ParseInt(postIDStr, 10, 64)
	if err != nil {
		log.Printf("[LikePost] ID post invalide : %v", err)
		response.RespondWithError(w, http.StatusBadRequest, "ID du post invalide")
		return
	}

	liked, err := repository.ToggleLike(userID, postID)
	if err != nil {
		log.Printf("[LikePost] Erreur toggle like (userID=%d, postID=%d) : %v", userID, postID, err)
		response.RespondWithError(w, http.StatusInternalServerError, "Erreur lors de la mise à jour du like")
		return
	}

	status := "liké"
	if !liked {
		status = "retiré son like de"
	}
	log.Printf("[LikePost] Utilisateur %d a %s le post %d", userID, status, postID)

	response.RespondWithJSON(w, http.StatusOK, map[string]bool{"liked": liked})
}

// GetPostLikes retourne le nombre total de likes pour un post.
func GetPostLikes(w http.ResponseWriter, r *http.Request) {
	postIDStr := chi.URLParam(r, "id")
	postID, err := strconv.ParseInt(postIDStr, 10, 64)
	if err != nil {
		log.Printf("[GetPostLikes] ID post invalide : %v", err)
		response.RespondWithError(w, http.StatusBadRequest, "ID du post invalide")
		return
	}

	count, err := repository.GetLikesCount(postID)
	if err != nil {
		log.Printf("[GetPostLikes] Erreur récupération likes post %d : %v", postID, err)
		response.RespondWithError(w, http.StatusInternalServerError, "Erreur récupération des likes")
		return
	}

	log.Printf("[GetPostLikes] Post %d a %d like(s)", postID, count)
	response.RespondWithJSON(w, http.StatusOK, map[string]int{"likes_count": count})
}
