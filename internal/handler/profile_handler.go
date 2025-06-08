package handler

import (
	"encoding/json"
	"log"
	"net/http"
	"onlyflick/internal/middleware"
	"onlyflick/internal/repository"
	"onlyflick/internal/service"
	"onlyflick/pkg/response"
	"onlyflick/pkg/utils"
)

type UpdateProfileRequest struct {
	FirstName *string `json:"first_name,omitempty"`
	LastName  *string `json:"last_name,omitempty"`
	Email     *string `json:"email,omitempty"`
	Password  *string `json:"password,omitempty"`
}

func UpdateProfile(w http.ResponseWriter, r *http.Request) {
	log.Println("[INFO] Appel du handler UpdateProfile")

	userIDVal := r.Context().Value(middleware.ContextUserIDKey)
	userID, ok := userIDVal.(int64)
	if !ok {
		log.Println("[ERREUR] Impossible de récupérer l'ID utilisateur depuis le contexte")
		response.RespondWithError(w, http.StatusUnauthorized, "Utilisateur non authentifié")
		return
	}

	var req UpdateProfileRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		log.Printf("[ERREUR] Décodage du corps de la requête échoué : %v", err)
		response.RespondWithError(w, http.StatusBadRequest, "Corps de requête invalide")
		return
	}

	if req.FirstName != nil {
		if encrypted, err := utils.Encrypt(*req.FirstName); err == nil {
			req.FirstName = &encrypted
		}
	}
	if req.LastName != nil {
		if encrypted, err := utils.Encrypt(*req.LastName); err == nil {
			req.LastName = &encrypted
		}
	}
	if req.Email != nil {
		if encrypted, err := utils.Encrypt(*req.Email); err == nil {
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
		log.Printf("[ERREUR] Mise à jour du profil utilisateur %d échouée : %v", userID, err)
		response.RespondWithError(w, http.StatusInternalServerError, "Échec de la mise à jour")
		return
	}

	log.Printf("[SUCCÈS] Profil de l'utilisateur %d mis à jour avec succès", userID)
	response.RespondWithJSON(w, http.StatusOK, map[string]string{"message": "Profil mis à jour"})
}

func DeleteAccount(w http.ResponseWriter, r *http.Request) {
	log.Println("[INFO] Appel du handler DeleteAccount")

	userIDVal := r.Context().Value(middleware.ContextUserIDKey)
	userID, ok := userIDVal.(int64)
	if !ok {
		log.Println("[ERREUR] Impossible de récupérer l'ID utilisateur depuis le contexte")
		response.RespondWithError(w, http.StatusUnauthorized, "Utilisateur non authentifié")
		return
	}

	if err := repository.DeleteUser(userID); err != nil {
		log.Printf("[ERREUR] Suppression du compte utilisateur %d échouée : %v", userID, err)
		response.RespondWithError(w, http.StatusInternalServerError, "Échec de la suppression du compte")
		return
	}

	log.Printf("[SUCCÈS] Compte utilisateur %d supprimé avec succès", userID)
	response.RespondWithJSON(w, http.StatusOK, map[string]string{"message": "Compte supprimé"})
}

func RequestCreatorUpgrade(w http.ResponseWriter, r *http.Request) {
	log.Println("[INFO] Appel du handler RequestCreatorUpgrade")

	userIDVal := r.Context().Value(middleware.ContextUserIDKey)
	userID, ok := userIDVal.(int64)
	if !ok {
		log.Println("[ERREUR] Impossible de récupérer l'ID utilisateur depuis le contexte")
		response.RespondWithError(w, http.StatusUnauthorized, "Utilisateur non authentifié")
		return
	}

	if err := repository.FlagUserAsPendingCreator(userID); err != nil {
		log.Printf("[ERREUR] Demande de passage en créateur pour l'utilisateur %d échouée : %v", userID, err)
		response.RespondWithError(w, http.StatusInternalServerError, "Impossible de traiter la demande")
		return
	}

	log.Printf("[SUCCÈS] Demande de passage en créateur envoyée pour l'utilisateur %d", userID)
	response.RespondWithJSON(w, http.StatusOK, map[string]string{"message": "Demande de passage en créateur envoyée"})
}
