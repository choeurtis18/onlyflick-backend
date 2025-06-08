package handler

import (
	"encoding/json"
	"log"
	"net/http"
	"strconv"

	"onlyflick/internal/domain"
	"onlyflick/internal/middleware"
	"onlyflick/internal/repository"
	"onlyflick/pkg/response"

	"github.com/go-chi/chi/v5"
)

// CreateComment gère la création d'un nouveau commentaire.
func CreateComment(w http.ResponseWriter, r *http.Request) {
	log.Println("[CommentHandler] Création d'un commentaire")

	var comment domain.Comment
	if err := json.NewDecoder(r.Body).Decode(&comment); err != nil {
		response.RespondWithError(w, http.StatusBadRequest, "Entrée invalide")
		log.Printf("[CreateComment] JSON invalide : %v", err)
		return
	}

	userIDVal := r.Context().Value(middleware.ContextUserIDKey)
	userID, ok := userIDVal.(int64)
	if !ok {
		response.RespondWithError(w, http.StatusUnauthorized, "Utilisateur non authentifié")
		log.Println("[CreateComment] userID manquant dans le contexte")
		return
	}

	comment.UserID = userID

	if err := repository.CreateComment(&comment); err != nil {
		response.RespondWithError(w, http.StatusInternalServerError, "Erreur lors de la création du commentaire")
		log.Printf("[CreateComment] DB error : %v", err)
		return
	}

	log.Printf("[CreateComment] Commentaire créé : %+v", comment)
	response.RespondWithJSON(w, http.StatusCreated, comment)
}

// GetComments récupère tous les commentaires pour un post.
func GetComments(w http.ResponseWriter, r *http.Request) {
	log.Println("[CommentHandler] Récupération des commentaires")

	postIDStr := chi.URLParam(r, "post_id")
	postID, err := strconv.ParseInt(postIDStr, 10, 64)
	if err != nil {
		response.RespondWithError(w, http.StatusBadRequest, "ID du post invalide")
		log.Printf("[GetComments] Erreur parsing ID : %v", err)
		return
	}

	comments, err := repository.GetCommentsByPostID(postID)
	if err != nil {
		response.RespondWithError(w, http.StatusInternalServerError, "Erreur récupération des commentaires")
		log.Printf("[GetComments] DB error : %v", err)
		return
	}

	log.Printf("[GetComments] %d commentaire(s) récupéré(s) pour le post %d", len(comments), postID)
	response.RespondWithJSON(w, http.StatusOK, comments)
}

// DeleteComment permet à un admin ou auteur du commentaire de le supprimer.
func DeleteComment(w http.ResponseWriter, r *http.Request) {
	log.Println("[CommentHandler] Suppression d'un commentaire")

	userIDVal := r.Context().Value(middleware.ContextUserIDKey)
	userID, ok := userIDVal.(int64)
	if !ok {
		response.RespondWithError(w, http.StatusUnauthorized, "Utilisateur non authentifié")
		log.Println("[DeleteComment] userID manquant")
		return
	}

	roleVal := r.Context().Value(middleware.ContextUserRoleKey)
	userRole, _ := roleVal.(string)

	commentIDStr := chi.URLParam(r, "id")
	commentID, err := strconv.ParseInt(commentIDStr, 10, 64)
	if err != nil {
		response.RespondWithError(w, http.StatusBadRequest, "ID du commentaire invalide")
		log.Printf("[DeleteComment] Parsing ID : %v", err)
		return
	}

	comment, err := repository.GetCommentByID(commentID)
	if err != nil {
		response.RespondWithError(w, http.StatusNotFound, "Commentaire non trouvé")
		log.Printf("[DeleteComment] Introuvable : %v", err)
		return
	}

	if userRole != "admin" && comment.UserID != userID {
		response.RespondWithError(w, http.StatusForbidden, "Non autorisé à supprimer ce commentaire")
		log.Printf("[DeleteComment] Accès refusé utilisateur %d pour commentaire %d", userID, commentID)
		return
	}

	if err := repository.DeleteComment(commentID); err != nil {
		response.RespondWithError(w, http.StatusInternalServerError, "Erreur suppression du commentaire")
		log.Printf("[DeleteComment] DB error : %v", err)
		return
	}

	log.Printf("[DeleteComment] Commentaire %d supprimé par utilisateur %d", commentID, userID)
	response.RespondWithJSON(w, http.StatusOK, map[string]string{"message": "Commentaire supprimé"})
}
