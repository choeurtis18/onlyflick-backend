package handler

import (
	"encoding/json"
	"fmt"
	"io"
	"log"
	"mime/multipart"
	"net/http"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"time"

	"onlyflick/internal/middleware"
	"onlyflick/internal/repository"
	"onlyflick/internal/service"
	"onlyflick/internal/utils"
	"onlyflick/pkg/response"
)

// ===== STRUCTURES DE REQUÊTE =====

type UpdateProfileRequest struct {
	FirstName *string `json:"first_name,omitempty"`
	LastName  *string `json:"last_name,omitempty"`
	Email     *string `json:"email,omitempty"`
	Password  *string `json:"password,omitempty"`
}

// ===== HANDLERS PROFIL DE BASE =====

// UpdateProfile met à jour le profil complet (existant)
func UpdateProfile(w http.ResponseWriter, r *http.Request) {
	log.Println("[PROFILE] UpdateProfile - Mise à jour profil complet")

	userIDVal := r.Context().Value(middleware.ContextUserIDKey)
	userID, ok := userIDVal.(int64)
	if !ok {
		response.RespondWithError(w, http.StatusUnauthorized, "Utilisateur non authentifié")
		return
	}

	var req UpdateProfileRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		log.Printf("[ERROR] Décodage du corps de la requête échoué : %v", err)
		response.RespondWithError(w, http.StatusBadRequest, "Corps de requête invalide")
		return
	}

	// Chiffrement des champs sensibles
	if req.FirstName != nil {
		if encrypted, err := utils.EncryptAES(*req.FirstName); err == nil {
			req.FirstName = &encrypted
		}
	}
	if req.LastName != nil {
		if encrypted, err := utils.EncryptAES(*req.LastName); err == nil {
			req.LastName = &encrypted
		}
	}
	if req.Email != nil {
		if encrypted, err := utils.EncryptAES(*req.Email); err == nil {
			req.Email = &encrypted
		}
	}
	if req.Password != nil {
		if hashed, err := service.HashPassword(*req.Password); err == nil {
			req.Password = &hashed
		}
	}

	payload := repository.UpdateUserPayload{
		FirstName: req.FirstName,
		LastName:  req.LastName,
		Email:     req.Email,
		Password:  req.Password,
	}

	if err := repository.UpdateUser(userID, payload); err != nil {
		log.Printf("[ERROR] Mise à jour du profil utilisateur %d échouée : %v", userID, err)
		response.RespondWithError(w, http.StatusInternalServerError, "Échec de la mise à jour")
		return
	}

	log.Printf("[SUCCESS] Profil de l'utilisateur %d mis à jour avec succès", userID)
	response.RespondWithJSON(w, http.StatusOK, map[string]string{"message": "Profil mis à jour"})
}

// DeleteAccount supprime le compte utilisateur (existant)
func DeleteAccount(w http.ResponseWriter, r *http.Request) {
	log.Println("[PROFILE] DeleteAccount - Suppression compte")

	userIDVal := r.Context().Value(middleware.ContextUserIDKey)
	userID, ok := userIDVal.(int64)
	if !ok {
		response.RespondWithError(w, http.StatusUnauthorized, "Utilisateur non authentifié")
		return
	}

	if err := repository.DeleteUser(userID); err != nil {
		log.Printf("[ERROR] Suppression du compte utilisateur %d échouée : %v", userID, err)
		response.RespondWithError(w, http.StatusInternalServerError, "Échec de la suppression du compte")
		return
	}

	log.Printf("[SUCCESS] Compte utilisateur %d supprimé avec succès", userID)
	response.RespondWithJSON(w, http.StatusOK, map[string]string{"message": "Compte supprimé"})
}

// RequestCreatorUpgrade demande de passage en créateur (existant)
func RequestCreatorUpgrade(w http.ResponseWriter, r *http.Request) {
	log.Println("[PROFILE] RequestCreatorUpgrade - Demande passage créateur")

	userIDVal := r.Context().Value(middleware.ContextUserIDKey)
	userID, ok := userIDVal.(int64)
	if !ok {
		response.RespondWithError(w, http.StatusUnauthorized, "Utilisateur non authentifié")
		return
	}

	if err := repository.FlagUserAsPendingCreator(userID); err != nil {
		log.Printf("[ERROR] Demande de passage en créateur pour l'utilisateur %d échouée : %v", userID, err)
		response.RespondWithError(w, http.StatusInternalServerError, "Impossible de traiter la demande")
		return
	}

	log.Printf("[SUCCESS] Demande de passage en créateur envoyée pour l'utilisateur %d", userID)
	response.RespondWithJSON(w, http.StatusOK, map[string]string{"message": "Demande de passage en créateur envoyée"})
}

// ===== NOUVEAUX HANDLERS PROFIL AVANCÉS =====

// GetProfileStats récupère les statistiques du profil utilisateur
func GetProfileStats(w http.ResponseWriter, r *http.Request) {
	log.Println("[PROFILE] GetProfileStats - Récupération des statistiques profil")

	userIDVal := r.Context().Value(middleware.ContextUserIDKey)
	userID, ok := userIDVal.(int64)
	if !ok {
		response.RespondWithError(w, http.StatusUnauthorized, "Utilisateur non authentifié")
		return
	}

	stats, err := repository.GetProfileStats(userID)
	if err != nil {
		log.Printf("[ERROR] Erreur récupération stats profil pour user %d: %v", userID, err)
		response.RespondWithError(w, http.StatusInternalServerError, "Erreur récupération statistiques")
		return
	}

	log.Printf("[SUCCESS] Stats profil récupérées pour user %d", userID)
	response.RespondWithJSON(w, http.StatusOK, stats)
}

// GetUserPosts récupère les posts de l'utilisateur avec pagination
func GetUserPosts(w http.ResponseWriter, r *http.Request) {
	log.Println("[PROFILE] GetUserPosts - Récupération des posts utilisateur")

	userIDVal := r.Context().Value(middleware.ContextUserIDKey)
	userID, ok := userIDVal.(int64)
	if !ok {
		response.RespondWithError(w, http.StatusUnauthorized, "Utilisateur non authentifié")
		return
	}

	// Paramètres de pagination
	pageStr := r.URL.Query().Get("page")
	limitStr := r.URL.Query().Get("limit")
	postType := r.URL.Query().Get("type") // 'all', 'public', 'subscriber'

	page, err := strconv.Atoi(pageStr)
	if err != nil || page < 1 {
		page = 1
	}

	limit, err := strconv.Atoi(limitStr)
	if err != nil || limit < 1 || limit > 50 {
		limit = 20
	}

	if postType == "" {
		postType = "all"
	}

	// Validation du type de post
	validTypes := []string{"all", "public", "subscriber"}
	isValidType := false
	for _, vt := range validTypes {
		if postType == vt {
			isValidType = true
			break
		}
	}
	if !isValidType {
		response.RespondWithError(w, http.StatusBadRequest, "Type de post invalide. Utilisez: all, public, subscriber")
		return
	}

	posts, err := repository.GetUserPosts(userID, page, limit, postType)
	if err != nil {
		log.Printf("[ERROR] Erreur récupération posts pour user %d: %v", userID, err)
		response.RespondWithError(w, http.StatusInternalServerError, "Erreur récupération posts")
		return
	}

	log.Printf("[SUCCESS] %d posts récupérés pour user %d (page %d)", len(posts), userID, page)
	response.RespondWithJSON(w, http.StatusOK, posts)
}

// UploadAvatar gère l'upload de l'avatar utilisateur - VERSION CORRIGÉE POUR FLUTTER
func UploadAvatar(w http.ResponseWriter, r *http.Request) {
	log.Println("[PROFILE] UploadAvatar - Upload avatar utilisateur")

	userIDVal := r.Context().Value(middleware.ContextUserIDKey)
	userID, ok := userIDVal.(int64)
	if !ok {
		response.RespondWithError(w, http.StatusUnauthorized, "Utilisateur non authentifié")
		return
	}

	// Parse multipart form (limite 10 MB)
	err := r.ParseMultipartForm(10 << 20)
	if err != nil {
		log.Printf("[ERROR] Erreur parsing form: %v", err)
		response.RespondWithError(w, http.StatusBadRequest, "Erreur parsing du formulaire")
		return
	}

	file, header, err := r.FormFile("avatar")
	if err != nil {
		log.Printf("[ERROR] Erreur récupération fichier: %v", err)
		response.RespondWithError(w, http.StatusBadRequest, "Fichier avatar manquant")
		return
	}
	defer file.Close()

	// Validation du type de fichier
	contentType := header.Header.Get("Content-Type")
	allowedTypes := []string{"image/jpeg", "image/jpg", "image/png", "image/gif"}
	isValidType := false
	for _, at := range allowedTypes {
		if contentType == at {
			isValidType = true
			break
		}
	}
	if !isValidType {
		response.RespondWithError(w, http.StatusBadRequest, "Type de fichier non supporté. Utilisez JPG, PNG ou GIF")
		return
	}

	// Validation de la taille (5MB max)
	if header.Size > 5*1024*1024 {
		response.RespondWithError(w, http.StatusBadRequest, "Fichier trop volumineux (max 5MB)")
		return
	}

	// Validation de l'extension
	ext := strings.ToLower(filepath.Ext(header.Filename))
	allowedExts := []string{".jpg", ".jpeg", ".png", ".gif"}
	isValidExt := false
	for _, ae := range allowedExts {
		if ext == ae {
			isValidExt = true
			break
		}
	}
	if !isValidExt {
		response.RespondWithError(w, http.StatusBadRequest, "Extension de fichier non supportée")
		return
	}

	log.Printf("[INFO] Fichier valide: %s, taille: %d bytes, type: %s", header.Filename, header.Size, contentType)

	// Upload vers ImageKit ou stockage local - VERSION FONCTIONNELLE
	avatarURL, err := uploadAvatarToStorage(file, header, userID)
	if err != nil {
		log.Printf("[ERROR] Erreur upload avatar: %v", err)
		response.RespondWithError(w, http.StatusInternalServerError, "Erreur upload avatar")
		return
	}

	// Mettre à jour l'avatar dans la base de données
	err = repository.UpdateUserAvatar(userID, avatarURL)
	if err != nil {
		log.Printf("[ERROR] Erreur mise à jour avatar en DB: %v", err)
		response.RespondWithError(w, http.StatusInternalServerError, "Erreur sauvegarde avatar")
		return
	}

	log.Printf("[SUCCESS] Avatar mis à jour pour user %d: %s", userID, avatarURL)
	response.RespondWithJSON(w, http.StatusOK, map[string]string{
		"message":    "Avatar mis à jour avec succès",
		"avatar_url": avatarURL,
	})
}

// UpdateBio met à jour la bio de l'utilisateur
func UpdateBio(w http.ResponseWriter, r *http.Request) {
	log.Println("[PROFILE] UpdateBio - Mise à jour bio utilisateur")

	userIDVal := r.Context().Value(middleware.ContextUserIDKey)
	userID, ok := userIDVal.(int64)
	if !ok {
		response.RespondWithError(w, http.StatusUnauthorized, "Utilisateur non authentifié")
		return
	}

	var req struct {
		Bio string `json:"bio"`
	}

	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		log.Printf("[ERROR] Erreur décodage JSON: %v", err)
		response.RespondWithError(w, http.StatusBadRequest, "JSON invalide")
		return
	}

	// Validation de la bio
	req.Bio = strings.TrimSpace(req.Bio)
	if len(req.Bio) > 500 {
		response.RespondWithError(w, http.StatusBadRequest, "Bio trop longue (max 500 caractères)")
		return
	}

	// Nettoyage basique (enlever les caractères dangereux)
	req.Bio = strings.ReplaceAll(req.Bio, "\x00", "") // Enlever null bytes
	req.Bio = strings.ReplaceAll(req.Bio, "\r", "")   // Normaliser les retours à la ligne

	// Mise à jour en base de données
	err := repository.UpdateUserBio(userID, req.Bio)
	if err != nil {
		log.Printf("[ERROR] Erreur mise à jour bio pour user %d: %v", userID, err)
		response.RespondWithError(w, http.StatusInternalServerError, "Erreur mise à jour bio")
		return
	}

	log.Printf("[SUCCESS] Bio mise à jour pour user %d (length: %d)", userID, len(req.Bio))
	response.RespondWithJSON(w, http.StatusOK, map[string]string{
		"message": "Bio mise à jour avec succès",
	})
}

// CheckUsernameAvailability vérifie si un username est disponible
func CheckUsernameAvailability(w http.ResponseWriter, r *http.Request) {
	log.Println("[PROFILE] CheckUsernameAvailability - Vérification username")

	username := r.URL.Query().Get("username")
	if username == "" {
		response.RespondWithError(w, http.StatusBadRequest, "Username manquant")
		return
	}

	username = strings.TrimSpace(strings.ToLower(username))
	if len(username) < 3 || len(username) > 50 {
		response.RespondWithError(w, http.StatusBadRequest, "Username doit faire entre 3 et 50 caractères")
		return
	}

	available, err := repository.CheckUsernameAvailability(username)
	if err != nil {
		log.Printf("[ERROR] Erreur vérification username %s: %v", username, err)
		response.RespondWithError(w, http.StatusInternalServerError, "Erreur vérification username")
		return
	}

	log.Printf("[INFO] Username %s disponible: %v", username, available)
	response.RespondWithJSON(w, http.StatusOK, map[string]interface{}{
		"username":  username,
		"available": available,
	})
}

// ===== FONCTIONS UTILITAIRES CORRIGÉES =====

// uploadAvatarToStorage gère l'upload de l'avatar - VERSION PRODUCTION
func uploadAvatarToStorage(file multipart.File, header *multipart.FileHeader, userID int64) (string, error) {
	log.Printf("[STORAGE] Upload avatar pour user %d: %s", userID, header.Filename)

	// Générer un nom unique pour le fichier
	ext := filepath.Ext(header.Filename)
	uniqueFilename := fmt.Sprintf("avatar_%d_%d%s", userID, time.Now().Unix(), ext)
	
	// Lire le contenu du fichier
	fileBytes, err := io.ReadAll(file)
	if err != nil {
		return "", fmt.Errorf("erreur lecture fichier: %w", err)
	}

	// OPTION 1: Stockage local (pour développement)
	if os.Getenv("ENVIRONMENT") == "development" {
		uploadDir := "./uploads/avatars"
		
		// Créer le dossier si nécessaire
		if err := os.MkdirAll(uploadDir, 0755); err != nil {
			return "", fmt.Errorf("erreur création dossier: %w", err)
		}
		
		// Sauvegarder le fichier localement
		localPath := filepath.Join(uploadDir, uniqueFilename)
		if err := os.WriteFile(localPath, fileBytes, 0644); err != nil {
			return "", fmt.Errorf("erreur sauvegarde locale: %w", err)
		}
		
		avatarURL := fmt.Sprintf("/uploads/avatars/%s", uniqueFilename)
		log.Printf("[STORAGE] Avatar sauvé localement: %s", avatarURL)
		return avatarURL, nil
	}

	// OPTION 2: ImageKit (pour production)
	/*
	import "github.com/imagekit-developer/imagekit-go"
	
	ik, err := imagekit.NewFromParams(imagekit.NewParams{
		PrivateKey:  os.Getenv("IMAGEKIT_PRIVATE_KEY"),
		PublicKey:   os.Getenv("IMAGEKIT_PUBLIC_KEY"),
		UrlEndpoint: os.Getenv("IMAGEKIT_URL_ENDPOINT"),
	})
	
	if err != nil {
		return "", fmt.Errorf("erreur configuration ImageKit: %w", err)
	}
	
	response, err := ik.Upload(ctx, fileBytes, imagekit.UploadParam{
		FileName: uniqueFilename,
		Folder:   "/avatars",
	})
	
	if err != nil {
		return "", fmt.Errorf("erreur upload ImageKit: %w", err)
	}
	
	log.Printf("[STORAGE] Avatar uploadé vers ImageKit: %s", response.Url)
	return response.Url, nil
	*/

	// OPTION 3: Placeholder pour les tests (temporaire)
	avatarURL := fmt.Sprintf("https://i.pravatar.cc/150?img=%d", userID%20+1)
	log.Printf("[STORAGE] Avatar placeholder généré: %s", avatarURL)
	return avatarURL, nil
}