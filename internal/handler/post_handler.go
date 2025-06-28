package handler

import (
	"log"
	"net/http"
	"strconv"

	"onlyflick/internal/domain"
	"onlyflick/internal/middleware"
	"onlyflick/internal/repository"
	"onlyflick/internal/service"
	"onlyflick/pkg/response"
	"strings"

	"github.com/go-chi/chi/v5"
)

// ==============================
// Structures de requête
// ==============================

// Requête pour la création d'un post
type CreatePostRequest struct {
	Title       string `json:"title"`
	Description string `json:"description"`
	MediaURL    string `json:"media_url"`
	Visibility  string `json:"visibility"` // public | subscriber
}

// Requête pour la mise à jour d'un post
type UpdatePostRequest struct {
	Title       string `json:"title"`
	Description string `json:"description"`
	MediaURL    string `json:"media_url"`
	Visibility  string `json:"visibility"` // public | subscriber
}

// ==============================
// Handlers principaux
// ==============================

// CreatePost insère un nouveau post, y compris file_id
func CreatePost(w http.ResponseWriter, r *http.Request) {
	log.Println("[CreatePost] Handler appelé")

	userVal := r.Context().Value(middleware.ContextUserIDKey)
	userID, ok := userVal.(int64)
	if !ok {
		response.RespondWithError(w, http.StatusUnauthorized, "Utilisateur non autorisé")
		log.Println("[CreatePost] Tentative d'accès non autorisé")
		return
	}

	// Parse le formulaire multipart
	if err := r.ParseMultipartForm(10 << 20); err != nil {
		response.RespondWithError(w, http.StatusBadRequest, "Formulaire multipart invalide")
		log.Printf("[CreatePost] Erreur lors du parsing du formulaire : %v", err)
		return
	}

	title := r.FormValue("title")
	description := r.FormValue("description")
	visibility := r.FormValue("visibility")

	var mediaURL, fileID string
	file, header, err := r.FormFile("media")
	if err == nil {
		defer file.Close()
		mediaURL, fileID, err = service.UploadFile(file, title+"_"+header.Filename)
		if err != nil {
			response.RespondWithError(w, http.StatusInternalServerError, "Échec de l'upload de l'image")
			log.Printf("[CreatePost] Échec de l'upload de l'image : %v", err)
			return
		}
	} else {
		log.Printf("[CreatePost] Aucun fichier média fourni ou erreur : %v", err)
	}

	post := &domain.Post{
		UserID:      userID,
		Title:       title,
		Description: description,
		MediaURL:    mediaURL,
		FileID:      fileID,
		Visibility:  domain.Visibility(visibility),
	}

	if err := repository.CreatePost(post); err != nil {
		response.RespondWithError(w, http.StatusInternalServerError, "Impossible de créer le post")
		log.Printf("[CreatePost] Erreur lors de la création du post : %v", err)
		return
	}

	log.Printf("[CreatePost] Post créé avec succès (ID: %d, UserID: %d, Titre: %s)", post.ID, userID, post.Title)
	response.RespondWithJSON(w, http.StatusCreated, post)
}

// GetPostByID récupère un post par son ID
func GetPostByID(w http.ResponseWriter, r *http.Request) {
	log.Println("[GetPostByID] Handler appelé")

	idStr := chi.URLParam(r, "id")
	postID, err := strconv.ParseInt(idStr, 10, 64)
	if err != nil {
		response.RespondWithError(w, http.StatusBadRequest, "ID du post invalide")
		log.Printf("[GetPostByID] Erreur lors du parsing de l'ID : %v", err)
		return
	}

	post, err := repository.GetPostByID(postID)
	if err != nil {
		response.RespondWithError(w, http.StatusNotFound, "Post introuvable")
		log.Printf("[GetPostByID] Post non trouvé (ID: %d) : %v", postID, err)
		return
	}

	log.Printf("[GetPostByID] Post récupéré (ID: %d, Titre: %s)", post.ID, post.Title)
	response.RespondWithJSON(w, http.StatusOK, post)
}

// ListMyPosts liste les posts de l'utilisateur connecté
func ListMyPosts(w http.ResponseWriter, r *http.Request) {
	log.Println("[ListMyPosts] Handler appelé")

	userVal := r.Context().Value(middleware.ContextUserIDKey)
	userID, ok := userVal.(int64)
	if !ok {
		response.RespondWithError(w, http.StatusUnauthorized, "Utilisateur non autorisé")
		log.Println("[ListMyPosts] Tentative d'accès non autorisé")
		return
	}

	posts, err := repository.ListPostsByUser(userID)
	if err != nil {
		response.RespondWithError(w, http.StatusInternalServerError, "Impossible de lister les posts")
		log.Printf("[ListMyPosts] Erreur lors de la récupération des posts pour l'utilisateur %d : %v", userID, err)
		return
	}

	log.Printf("[ListMyPosts] %d posts récupérés pour l'utilisateur %d", len(posts), userID)
	response.RespondWithJSON(w, http.StatusOK, posts)
}

// UpdatePost met à jour un post existant (avec remplacement d'image possible)
func UpdatePost(w http.ResponseWriter, r *http.Request) {
	log.Println("[UpdatePost] Handler appelé (remplacement d'image possible)")

	userVal := r.Context().Value(middleware.ContextUserIDKey)
	userID, ok := userVal.(int64)
	if !ok {
		response.RespondWithError(w, http.StatusUnauthorized, "Utilisateur non autorisé")
		log.Println("[UpdatePost] Tentative d'accès non autorisé")
		return
	}

	roleVal := r.Context().Value("userRole")
	userRole, _ := roleVal.(string)

	postID, err := strconv.ParseInt(chi.URLParam(r, "id"), 10, 64)
	if err != nil {
		response.RespondWithError(w, http.StatusBadRequest, "ID du post invalide")
		log.Printf("[UpdatePost] Erreur lors du parsing de l'ID : %v", err)
		return
	}

	post, err := repository.GetPostByID(postID)
	if err != nil {
		response.RespondWithError(w, http.StatusNotFound, "Post introuvable")
		log.Printf("[UpdatePost] Post non trouvé (ID: %d) : %v", postID, err)
		return
	}

	// Vérification des droits
	if userRole != "admin" && post.UserID != userID {
		response.RespondWithError(w, http.StatusForbidden, "Non autorisé à modifier ce post")
		log.Printf("[UpdatePost] Utilisateur %d a tenté de modifier le post %d sans permission", userID, postID)
		return
	}

	// Parse le formulaire multipart
	if err := r.ParseMultipartForm(10 << 20); err != nil {
		response.RespondWithError(w, http.StatusBadRequest, "Formulaire multipart invalide")
		log.Printf("[UpdatePost] Erreur lors du parsing du formulaire : %v", err)
		return
	}

	post.Title = r.FormValue("title")
	post.Description = r.FormValue("description")
	post.Visibility = domain.Visibility(r.FormValue("visibility"))

	// Nouveau fichier image ?
	file, header, err := r.FormFile("media")
	if err == nil {
		defer file.Close()
		newURL, newFileID, err := service.UploadFile(file, header.Filename)
		if err != nil {
			response.RespondWithError(w, http.StatusInternalServerError, "Échec de l'upload de l'image")
			log.Printf("[UpdatePost] Échec de l'upload de la nouvelle image : %v", err)
			return
		}

		// Suppression de l'ancienne image si existante
		if post.FileID != "" {
			if err := service.DeleteFile(post.FileID); err != nil {
				log.Printf("[UpdatePost] Attention : échec de suppression de l'ancienne image (FileID: %s) : %v", post.FileID, err)
			} else {
				log.Printf("[UpdatePost] Ancienne image supprimée (FileID: %s)", post.FileID)
			}
		}

		post.MediaURL = newURL
		post.FileID = newFileID
	} else {
		log.Printf("[UpdatePost] Aucun nouveau fichier média fourni ou erreur : %v", err)
	}

	// Sauvegarde en base de données
	if err := repository.UpdatePost(post); err != nil {
		response.RespondWithError(w, http.StatusInternalServerError, "Impossible de mettre à jour le post")
		log.Printf("[UpdatePost] Erreur lors de la mise à jour du post (ID: %d) : %v", postID, err)
		return
	}

	log.Printf("[UpdatePost] Post %d mis à jour avec succès par l'utilisateur %d", postID, userID)
	response.RespondWithJSON(w, http.StatusOK, post)
}

// DeletePost supprime un post (et son média associé si présent)
func DeletePost(w http.ResponseWriter, r *http.Request) {
	log.Println("[DeletePost] Handler appelé")

	userVal := r.Context().Value(middleware.ContextUserIDKey)
	userID, ok := userVal.(int64)
	if !ok {
		response.RespondWithError(w, http.StatusUnauthorized, "Utilisateur non autorisé")
		log.Println("[DeletePost] Tentative d'accès non autorisé")
		return
	}

	roleVal := r.Context().Value("userRole")
	userRole, _ := roleVal.(string)

	idStr := chi.URLParam(r, "id")
	postID, err := strconv.ParseInt(idStr, 10, 64)
	if err != nil {
		response.RespondWithError(w, http.StatusBadRequest, "ID du post invalide")
		log.Printf("[DeletePost] Erreur lors du parsing de l'ID : %v", err)
		return
	}

	post, err := repository.GetPostByID(postID)
	if err != nil {
		response.RespondWithError(w, http.StatusNotFound, "Post introuvable")
		log.Printf("[DeletePost] Post non trouvé (ID: %d) : %v", postID, err)
		return
	}

	// Vérification des droits
	if userRole != "admin" && post.UserID != userID {
		response.RespondWithError(w, http.StatusForbidden, "Non autorisé à supprimer ce post")
		log.Printf("[DeletePost] Utilisateur %d a tenté de supprimer le post %d sans permission", userID, postID)
		return
	}

	// Suppression en base de données
	if err := repository.DeletePost(postID); err != nil {
		response.RespondWithError(w, http.StatusInternalServerError, "Impossible de supprimer le post")
		log.Printf("[DeletePost] Erreur lors de la suppression du post (ID: %d) : %v", postID, err)
		return
	}

	// Suppression du média associé si présent
	if post.FileID != "" {
		if err := service.DeleteFile(post.FileID); err != nil {
			log.Printf("[DeletePost] Attention : post %d supprimé mais suppression du média échouée (FileID: %s) : %v", postID, post.FileID, err)
		} else {
			log.Printf("[DeletePost] Média supprimé (FileID: %s)", post.FileID)
		}
	}

	log.Printf("[DeletePost] Post %d supprimé avec succès par l'utilisateur %d", postID, userID)
	response.RespondWithJSON(w, http.StatusOK, map[string]string{"message": "Post supprimé"})
}

// ==============================
// Handlers de listing
// ==============================

// ListAllVisiblePosts liste tous les posts visibles selon le rôle
func ListAllVisiblePosts(w http.ResponseWriter, r *http.Request) {
	log.Println("[ListAllVisiblePosts] Handler appelé")

	roleVal := r.Context().Value("userRole")
	userRole, _ := roleVal.(string)

	if userRole != "subscriber" && userRole != "creator" && userRole != "admin" {
		userRole = "guest"
	}

	posts, err := repository.ListVisiblePosts(userRole)
	if err != nil {
		response.RespondWithError(w, http.StatusInternalServerError, "Impossible de récupérer les posts visibles")
		log.Printf("[ListAllVisiblePosts] Erreur lors de la récupération des posts visibles pour le rôle %s : %v", userRole, err)
		return
	}

	log.Printf("[ListAllVisiblePosts] %d posts visibles listés pour le rôle %s", len(posts), userRole)
	response.RespondWithJSON(w, http.StatusOK, posts)
}

// ListPostsFromCreator liste les posts d'un créateur selon les droits du demandeur
func ListPostsFromCreator(w http.ResponseWriter, r *http.Request) {
	log.Println("[ListPostsFromCreator] Handler appelé")

	requesterID := r.Context().Value(middleware.ContextUserIDKey).(int64)
	role := r.Context().Value("userRole").(string)

	creatorIDStr := chi.URLParam(r, "creator_id")
	creatorID, err := strconv.ParseInt(creatorIDStr, 10, 64)
	if err != nil {
		response.RespondWithError(w, http.StatusBadRequest, "ID du créateur invalide")
		log.Printf("[ListPostsFromCreator] Erreur lors du parsing de l'ID créateur : %v", err)
		return
	}

	canViewPrivate := (role == "admin" || requesterID == creatorID)

	if !canViewPrivate {
		isSub, err := repository.IsSubscribed(requesterID, creatorID)
		if err != nil {
			response.RespondWithError(w, http.StatusInternalServerError, "Impossible de vérifier l'abonnement")
			log.Printf("[ListPostsFromCreator] Erreur lors de la vérification de l'abonnement (user: %d, creator: %d) : %v", requesterID, creatorID, err)
			return
		}
		canViewPrivate = isSub
	}

	posts, err := repository.ListPostsFromCreator(creatorID, canViewPrivate)
	if err != nil {
		response.RespondWithError(w, http.StatusInternalServerError, "Impossible de lister les posts du créateur")
		log.Printf("[ListPostsFromCreator] Erreur lors du listing des posts du créateur %d : %v", creatorID, err)
		return
	}

	log.Printf("[ListPostsFromCreator] %d posts listés pour le créateur %d par l'utilisateur %d (rôle: %s)", len(posts), creatorID, requesterID, role)
	response.RespondWithJSON(w, http.StatusOK, posts)
}

// ListSubscriberOnlyPostsFromCreator liste uniquement les posts réservés aux abonnés d'un créateur
func ListSubscriberOnlyPostsFromCreator(w http.ResponseWriter, r *http.Request) {
	log.Println("[ListSubscriberOnlyPostsFromCreator] Handler appelé")

	requesterID := r.Context().Value(middleware.ContextUserIDKey).(int64)
	role := r.Context().Value("userRole").(string)

	creatorIDStr := chi.URLParam(r, "creator_id")
	creatorID, err := strconv.ParseInt(creatorIDStr, 10, 64)
	if err != nil {
		response.RespondWithError(w, http.StatusBadRequest, "ID du créateur invalide")
		log.Printf("[ListSubscriberOnlyPostsFromCreator] Erreur lors du parsing de l'ID créateur : %v", err)
		return
	}

	if role != "admin" && requesterID != creatorID {
		isSub, err := repository.IsSubscribed(requesterID, creatorID)
		if err != nil || !isSub {
			response.RespondWithError(w, http.StatusForbidden, "Non autorisé à voir le contenu abonné")
			log.Printf("[ListSubscriberOnlyPostsFromCreator] Accès refusé à l'utilisateur %d pour le créateur %d (abonné: %v, err: %v)", requesterID, creatorID, isSub, err)
			return
		}
	}

	posts, err := repository.ListSubscriberOnlyPosts(creatorID)
	if err != nil {
		response.RespondWithError(w, http.StatusInternalServerError, "Impossible de lister les posts abonnés")
		log.Printf("[ListSubscriberOnlyPostsFromCreator] Erreur lors du listing des posts abonnés du créateur %d : %v", creatorID, err)
		return
	}

	log.Printf("[ListSubscriberOnlyPostsFromCreator] %d posts abonnés listés pour le créateur %d", len(posts), creatorID)
	response.RespondWithJSON(w, http.StatusOK, posts)
}

func GetRecommendedPosts(w http.ResponseWriter, r *http.Request) {
	log.Println("[GetRecommendedPosts] Handler appelé")

	userVal := r.Context().Value(middleware.ContextUserIDKey)
	userID, ok := userVal.(int64)
	if !ok {
		response.RespondWithError(w, http.StatusUnauthorized, "Utilisateur non autorisé")
		return
	}

	// ===== NOUVEAUX PARAMÈTRES =====
	// Parser les tags depuis les paramètres de requête
	tagsParam := r.URL.Query().Get("tags")
	var tags []string
	if tagsParam != "" {
		// Diviser par virgule et nettoyer
		rawTags := strings.Split(tagsParam, ",")
		for _, tag := range rawTags {
			cleanTag := strings.TrimSpace(tag)
			if cleanTag != "" && strings.ToLower(cleanTag) != "tous" {
				tags = append(tags, cleanTag)
			}
		}
	}

	// Parser limit et offset
	limit := 20 // valeur par défaut
	if limitParam := r.URL.Query().Get("limit"); limitParam != "" {
		if l, err := strconv.Atoi(limitParam); err == nil && l > 0 && l <= 100 {
			limit = l
		}
	}

	offset := 0 // valeur par défaut
	if offsetParam := r.URL.Query().Get("offset"); offsetParam != "" {
		if o, err := strconv.Atoi(offsetParam); err == nil && o >= 0 {
			offset = o
		}
	}

	log.Printf("[GetRecommendedPosts] Paramètres: userID=%d, tags=%v, limit=%d, offset=%d", 
		userID, tags, limit, offset)

	// ===== APPEL REPOSITORY MODIFIÉ =====
	posts, total, err := repository.ListPostsRecommendedForUserWithTags(userID, tags, limit, offset)
	if err != nil {
		response.RespondWithError(w, http.StatusInternalServerError, "Impossible de récupérer les posts recommandés")
		log.Printf("[GetRecommendedPosts] Erreur pour l'utilisateur %d : %v", userID, err)
		return
	}

	// ===== CONSTRUCTION DE LA RÉPONSE FORMATÉE =====
	result := map[string]interface{}{
		"posts":       posts,
		"total":       total,
		"has_more":    total > offset+len(posts),
		"limit":       limit,
		"offset":      offset,
		"tags":        tags,
		"query":       "", // Pas de query textuelle pour recommended
		"search_type": "recommended",
		"sort_by":     "recent", // Tri par défaut
	}

	log.Printf("[GetRecommendedPosts] ✅ %d posts recommandés trouvés (total: %d) pour l'utilisateur %d", 
		len(posts), total, userID)
	response.RespondWithJSON(w, http.StatusOK, result)
}
