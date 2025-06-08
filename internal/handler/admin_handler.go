package handler

import (
	"log"
	"net/http"
	"strconv"

	"onlyflick/internal/repository"
	"onlyflick/pkg/response"

	"github.com/go-chi/chi/v5"
)

// AdminDashboard affiche un message de bienvenue sur le tableau de bord admin.
func AdminDashboard(w http.ResponseWriter, r *http.Request) {
	log.Println("[AdminDashboard] Accès au tableau de bord admin")
	response.RespondWithJSON(w, http.StatusOK, map[string]string{
		"message": "Bienvenue sur le tableau de bord admin",
	})
}

// ListCreatorRequests liste toutes les demandes de créateurs en attente.
func ListCreatorRequests(w http.ResponseWriter, r *http.Request) {
	log.Println("[ListCreatorRequests] Récupération des demandes de créateurs en attente")

	requests, err := repository.GetAllPendingRequests()
	if err != nil {
		log.Printf("[ListCreatorRequests][ERREUR] Impossible de récupérer les demandes : %v", err)
		response.RespondWithError(w, http.StatusInternalServerError, "Échec de la récupération des demandes : "+err.Error())
		return
	}

	log.Printf("[ListCreatorRequests] %d demandes en attente récupérées", len(requests))
	response.RespondWithJSON(w, http.StatusOK, requests)
}

// ApproveCreatorRequest approuve une demande de créateur selon son ID.
func ApproveCreatorRequest(w http.ResponseWriter, r *http.Request) {
	log.Println("[ApproveCreatorRequest] Tentative d'approbation d'une demande de créateur")

	idStr := chi.URLParam(r, "id")
	requestID, err := strconv.ParseInt(idStr, 10, 64)
	if err != nil {
		log.Printf("[ApproveCreatorRequest][ERREUR] ID de demande invalide : %v", err)
		response.RespondWithError(w, http.StatusBadRequest, "ID de demande invalide")
		return
	}

	if err := repository.ApproveCreatorRequest(requestID); err != nil {
		log.Printf("[ApproveCreatorRequest][ERREUR] Échec de l'approbation de la demande %d : %v", requestID, err)
		response.RespondWithError(w, http.StatusInternalServerError, "Échec de l'approbation de la demande : "+err.Error())
		return
	}

	log.Printf("[ApproveCreatorRequest] Demande %d approuvée avec succès", requestID)
	response.RespondWithJSON(w, http.StatusOK, map[string]string{"message": "Demande approuvée"})
}

// RejectCreatorRequest rejette une demande de créateur selon son ID.
func RejectCreatorRequest(w http.ResponseWriter, r *http.Request) {
	log.Println("[RejectCreatorRequest] Tentative de rejet d'une demande de créateur")

	idStr := chi.URLParam(r, "id")
	requestID, err := strconv.ParseInt(idStr, 10, 64)
	if err != nil {
		log.Printf("[RejectCreatorRequest][ERREUR] ID de demande invalide : %v", err)
		response.RespondWithError(w, http.StatusBadRequest, "ID de demande invalide")
		return
	}

	if err := repository.RejectCreatorRequest(requestID); err != nil {
		log.Printf("[RejectCreatorRequest][ERREUR] Échec du rejet de la demande %d : %v", requestID, err)
		response.RespondWithError(w, http.StatusInternalServerError, "Échec du rejet de la demande : "+err.Error())
		return
	}

	log.Printf("[RejectCreatorRequest] Demande %d rejetée avec succès", requestID)
	response.RespondWithJSON(w, http.StatusOK, map[string]string{"message": "Demande rejetée"})
}

// DeleteAccountByID supprime le compte d'un utilisateur selon son ID passé dans l'URL
func DeleteAccountByID(w http.ResponseWriter, r *http.Request) {
	log.Println("[DeleteAccountByID] Suppression du compte utilisateur par ID")

	idStr := chi.URLParam(r, "id")
	userID, err := strconv.ParseInt(idStr, 10, 64)
	if err != nil {
		log.Printf("[DeleteAccountByID][ERREUR] ID utilisateur invalide : %v", err)
		response.RespondWithError(w, http.StatusBadRequest, "ID utilisateur invalide")
		return
	}

	if err := repository.DeleteUser(userID); err != nil {
		log.Printf("[DeleteAccountByID][ERREUR] Suppression du compte utilisateur %d échouée : %v", userID, err)
		response.RespondWithError(w, http.StatusInternalServerError, "Échec de la suppression du compte : "+err.Error())
		return
	}

	log.Printf("[DeleteAccountByID] Compte utilisateur %d supprimé avec succès", userID)
	response.RespondWithJSON(w, http.StatusOK, map[string]string{"message": "Compte supprimé"})
}
