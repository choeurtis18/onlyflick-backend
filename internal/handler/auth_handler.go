package handler

import (
	"encoding/json"
	"log"
	"net/http"

	"onlyflick/internal/domain"
	"onlyflick/internal/middleware"
	"onlyflick/internal/repository"
	"onlyflick/internal/service"
	"onlyflick/internal/utils" // Changement ici
	"onlyflick/pkg/response"
)

// ===== STRUCTURES =====
type RegisterRequest struct {
	FirstName string `json:"first_name"`
	LastName  string `json:"last_name"`
	Email     string `json:"email"`
	Password  string `json:"password"`
}

type LoginRequest struct {
	Email    string `json:"email"`
	Password string `json:"password"`
}

// ===== HANDLERS =====

func RegisterHandler(w http.ResponseWriter, r *http.Request) {
	log.Println("[AUTH][RegisterHandler] Tentative d'inscription")

	var req RegisterRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		response.RespondWithError(w, http.StatusBadRequest, "Requête invalide")
		log.Println("[RegisterHandler] JSON invalide :", err)
		return
	}

	if user, _ := repository.GetUserByEmail(req.Email); user != nil {
		response.RespondWithError(w, http.StatusBadRequest, "Email déjà utilisé")
		log.Printf("[RegisterHandler] Email existant : %s", req.Email)
		return
	}

	hashedPwd, err := service.HashPassword(req.Password)
	if err != nil {
		response.RespondWithError(w, http.StatusInternalServerError, "Erreur hash mot de passe")
		return
	}

	encryptedEmail, _ := utils.EncryptAES(req.Email)         // Changement ici
	encryptedFirstName, _ := utils.EncryptAES(req.FirstName) // Changement ici
	encryptedLastName, _ := utils.EncryptAES(req.LastName)   // Changement ici

	user := &domain.User{
		FirstName: encryptedFirstName,
		LastName:  encryptedLastName,
		Email:     encryptedEmail,
		Password:  hashedPwd,
		Role:      domain.RoleSubscriber,
	}

	if err := repository.CreateUser(user); err != nil {
		response.RespondWithError(w, http.StatusInternalServerError, "Erreur création utilisateur")
		log.Println("[RegisterHandler] DB error :", err)
		return
	}

	token, err := service.GenerateJWT(user.ID, string(user.Role))
	if err != nil {
		response.RespondWithError(w, http.StatusInternalServerError, "Erreur JWT")
		return
	}

	response.RespondWithJSON(w, http.StatusCreated, map[string]interface{}{
		"message": "Inscription réussie",
		"user_id": user.ID,
		"token":   token,
	})
}

func LoginHandler(w http.ResponseWriter, r *http.Request) {
	log.Println("[AUTH][LoginHandler] Tentative de connexion")

	var req LoginRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		response.RespondWithError(w, http.StatusBadRequest, "Requête invalide")
		return
	}

	user, err := repository.GetUserByEmail(req.Email)
	if err != nil || user == nil {
		response.RespondWithError(w, http.StatusUnauthorized, "Email ou mot de passe invalide")
		return
	}

	if !service.CheckPasswordHash(req.Password, user.Password) {
		response.RespondWithError(w, http.StatusUnauthorized, "Email ou mot de passe invalide")
		return
	}

	token, err := service.GenerateJWT(user.ID, string(user.Role))
	if err != nil {
		response.RespondWithError(w, http.StatusInternalServerError, "Erreur génération JWT")
		return
	}

	response.RespondWithJSON(w, http.StatusOK, map[string]interface{}{
		"message": "Connexion réussie",
		"token":   token,
	})
}

func ProfileHandler(w http.ResponseWriter, r *http.Request) {
	log.Println("[AUTH][ProfileHandler] Récupération du profil")

	userIDVal := r.Context().Value(middleware.ContextUserIDKey)
	userID, ok := userIDVal.(int64)
	if !ok {
		response.RespondWithError(w, http.StatusUnauthorized, "Utilisateur non authentifié")
		return
	}

	user, err := repository.GetUserByID(userID)
	if err != nil || user == nil {
		response.RespondWithError(w, http.StatusNotFound, "Utilisateur non trouvé")
		return
	}

	// Décryptage des champs chiffrés (déjà fait dans GetUserByID, mais on refait par sécurité)
	firstName, _ := utils.DecryptAES(user.FirstName)
	lastName, _ := utils.DecryptAES(user.LastName)
	email, _ := utils.DecryptAES(user.Email)

	// ===== CORRECTION : Retourner TOUS les champs du profil =====
	profile := domain.User{
		ID:        user.ID,
		FirstName: firstName,
		LastName:  lastName,
		Email:     email,
		Role:      user.Role,
		CreatedAt: user.CreatedAt,
		// ===== NOUVEAUX CHAMPS AJOUTÉS =====
		AvatarURL: user.AvatarURL,
		Bio:       user.Bio,
		Username:  user.Username,
		UpdatedAt: user.UpdatedAt,
	}

	log.Printf("[ProfileHandler] Profil récupéré pour user %d: Username=%s, Bio=%s, Avatar=%s", 
		userID, profile.Username, profile.Bio, profile.AvatarURL)

	response.RespondWithJSON(w, http.StatusOK, profile)
}