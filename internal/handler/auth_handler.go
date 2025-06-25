package handler

import (
	"encoding/json"
	"log"
	"net/http"
	"regexp"
	"strings"

	"onlyflick/internal/domain"
	"onlyflick/internal/middleware"
	"onlyflick/internal/repository"
	"onlyflick/internal/service"
	"onlyflick/internal/utils"
	"onlyflick/pkg/response"
)

// ===== STRUCTURES =====
type RegisterRequest struct {
	FirstName string `json:"first_name"`
	LastName  string `json:"last_name"`
	Username  string `json:"username"`  // ===== AJOUT USERNAME OBLIGATOIRE =====
	Email     string `json:"email"`
	Password  string `json:"password"`
}

type LoginRequest struct {
	Email    string `json:"email"`
	Password string `json:"password"`
}

// ===== VALIDATION USERNAME =====
func validateUsername(username string) (bool, string) {
	// Nettoyer le username (retirer les espaces)
	username = strings.TrimSpace(username)
	
	// Vérifier que ce n'est pas vide
	if username == "" {
		return false, "Username est obligatoire"
	}
	
	// Vérifier la longueur (3-20 caractères)
	if len(username) < 3 || len(username) > 20 {
		return false, "Username doit contenir entre 3 et 20 caractères"
	}
	
	// Vérifier le format (lettres, chiffres, underscore, tiret)
	// Doit commencer par une lettre
	usernameRegex := regexp.MustCompile(`^[a-zA-Z][a-zA-Z0-9_-]*$`)
	if !usernameRegex.MatchString(username) {
		return false, "Username doit commencer par une lettre et ne contenir que des lettres, chiffres, _ ou -"
	}
	
	// Vérifier qu'il ne contient pas de mots interdits
	forbiddenWords := []string{"admin", "root", "api", "www", "mail", "support", "info", "contact", "help"}
	usernameLower := strings.ToLower(username)
	for _, word := range forbiddenWords {
		if usernameLower == word {
			return false, "Ce username n'est pas disponible"
		}
	}
	
	return true, ""
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

	// ===== VALIDATION CHAMPS OBLIGATOIRES =====
	if strings.TrimSpace(req.FirstName) == "" {
		response.RespondWithError(w, http.StatusBadRequest, "Prénom est obligatoire")
		return
	}
	if strings.TrimSpace(req.LastName) == "" {
		response.RespondWithError(w, http.StatusBadRequest, "Nom est obligatoire")
		return
	}
	if strings.TrimSpace(req.Email) == "" {
		response.RespondWithError(w, http.StatusBadRequest, "Email est obligatoire")
		return
	}
	if strings.TrimSpace(req.Password) == "" {
		response.RespondWithError(w, http.StatusBadRequest, "Mot de passe est obligatoire")
		return
	}

	// ===== VALIDATION USERNAME =====
	if valid, errMsg := validateUsername(req.Username); !valid {
		response.RespondWithError(w, http.StatusBadRequest, errMsg)
		log.Printf("[RegisterHandler] Username invalide : %s - %s", req.Username, errMsg)
		return
	}

	// Nettoyer le username
	req.Username = strings.TrimSpace(req.Username)
	
	// ===== VÉRIFICATION UNICITÉ USERNAME =====
	usernameAvailable, err := repository.CheckUsernameAvailability(req.Username)
	if err != nil {
		response.RespondWithError(w, http.StatusInternalServerError, "Erreur vérification username")
		log.Printf("[RegisterHandler] Erreur vérification username : %v", err)
		return
	}
	if !usernameAvailable {
		response.RespondWithError(w, http.StatusBadRequest, "Ce username est déjà pris")
		log.Printf("[RegisterHandler] Username déjà pris : %s", req.Username)
		return
	}

	// ===== VÉRIFICATION EMAIL =====
	if user, _ := repository.GetUserByEmail(req.Email); user != nil {
		response.RespondWithError(w, http.StatusBadRequest, "Email déjà utilisé")
		log.Printf("[RegisterHandler] Email existant : %s", req.Email)
		return
	}

	// ===== HASHAGE MOT DE PASSE =====
	hashedPwd, err := service.HashPassword(req.Password)
	if err != nil {
		response.RespondWithError(w, http.StatusInternalServerError, "Erreur hash mot de passe")
		return
	}

	// ===== CHIFFREMENT DONNÉES SENSIBLES =====
	encryptedEmail, _ := utils.EncryptAES(req.Email)
	encryptedFirstName, _ := utils.EncryptAES(req.FirstName)
	encryptedLastName, _ := utils.EncryptAES(req.LastName)

	// ===== CRÉATION UTILISATEUR AVEC USERNAME =====
	user := &domain.User{
		FirstName: encryptedFirstName,
		LastName:  encryptedLastName,
		Username:  req.Username,  // ===== USERNAME EN CLAIR (PSEUDO PUBLIC) =====
		Email:     encryptedEmail,
		Password:  hashedPwd,
		Role:      domain.RoleSubscriber,
		AvatarURL: "",  // Avatar par défaut vide
		Bio:       "",  // Bio par défaut vide
	}

	if err := repository.CreateUser(user); err != nil {
		response.RespondWithError(w, http.StatusInternalServerError, "Erreur création utilisateur")
		log.Printf("[RegisterHandler] DB error : %v", err)
		return
	}

	// ===== GÉNÉRATION JWT =====
	token, err := service.GenerateJWT(user.ID, string(user.Role))
	if err != nil {
		response.RespondWithError(w, http.StatusInternalServerError, "Erreur JWT")
		return
	}

	log.Printf("[RegisterHandler] Inscription réussie - ID: %d, Username: %s, Email: %s", 
		user.ID, user.Username, req.Email)

	response.RespondWithJSON(w, http.StatusCreated, map[string]interface{}{
		"message": "Inscription réussie",
		"user_id": user.ID,
		"username": user.Username,  // ===== RETOURNER LE USERNAME =====
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

	log.Printf("[LoginHandler] Connexion réussie - ID: %d, Username: %s", user.ID, user.Username)

	response.RespondWithJSON(w, http.StatusOK, map[string]interface{}{
		"message": "Connexion réussie",
		"user_id": user.ID,
		"username": user.Username,  // ===== RETOURNER LE USERNAME =====
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

	// ===== RETOURNER TOUS LES CHAMPS DU PROFIL =====
	profile := domain.User{
		ID:        user.ID,
		FirstName: firstName,
		LastName:  lastName,
		Username:  user.Username,  // ===== USERNAME PUBLIC =====
		Email:     email,
		Role:      user.Role,
		CreatedAt: user.CreatedAt,
		AvatarURL: user.AvatarURL,
		Bio:       user.Bio,
		UpdatedAt: user.UpdatedAt,
	}

	log.Printf("[ProfileHandler] Profil récupéré pour user %d: Username=%s, Bio=%s, Avatar=%s", 
		userID, profile.Username, profile.Bio, profile.AvatarURL)

	response.RespondWithJSON(w, http.StatusOK, profile)
}

// ===== NOUVEAU HANDLER : VÉRIFICATION DISPONIBILITÉ USERNAME =====
func CheckUsernameHandler(w http.ResponseWriter, r *http.Request) {
	log.Println("[AUTH][CheckUsernameHandler] Vérification disponibilité username")

	username := r.URL.Query().Get("username")
	if username == "" {
		response.RespondWithError(w, http.StatusBadRequest, "Username requis")
		return
	}

	// Validation du format
	if valid, errMsg := validateUsername(username); !valid {
		response.RespondWithJSON(w, http.StatusOK, map[string]interface{}{
			"available": false,
			"message":   errMsg,
		})
		return
	}

	// Vérification disponibilité
	available, err := repository.CheckUsernameAvailability(username)
	if err != nil {
		response.RespondWithError(w, http.StatusInternalServerError, "Erreur vérification")
		return
	}

	message := "Username disponible"
	if !available {
		message = "Username déjà pris"
	}

	log.Printf("[CheckUsernameHandler] Username '%s' disponible: %v", username, available)

	response.RespondWithJSON(w, http.StatusOK, map[string]interface{}{
		"available": available,
		"message":   message,
	})
}