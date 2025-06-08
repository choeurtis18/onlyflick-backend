package handler

import (
	"encoding/json"
	"log"
	"net/http"
	"onlyflick/internal/middleware"
	"onlyflick/internal/repository"
	"onlyflick/pkg/response"
	"strconv"
	"time"

	"github.com/go-chi/chi/v5"
)

// CreateReport permet à un utilisateur de signaler un contenu (post ou commentaire).
func CreateReport(w http.ResponseWriter, r *http.Request) {
	userID, ok := r.Context().Value(middleware.ContextUserIDKey).(int64)
	if !ok {
		log.Println("[CreateReport] Utilisateur non authentifié")
		response.RespondWithError(w, http.StatusUnauthorized, "Utilisateur non authentifié")
		return
	}

	var input struct {
		ContentType string `json:"content_type"` // "post" ou "comment"
		ContentID   int64  `json:"content_id"`
		Reason      string `json:"reason"`
	}

	if err := json.NewDecoder(r.Body).Decode(&input); err != nil {
		log.Printf("[CreateReport] Erreur de décodage du corps : %v", err)
		response.RespondWithError(w, http.StatusBadRequest, "Corps de requête invalide")
		return
	}

	if input.ContentType != "post" && input.ContentType != "comment" {
		log.Printf("[CreateReport] ContentType invalide : %s", input.ContentType)
		response.RespondWithError(w, http.StatusBadRequest, "Type de contenu invalide")
		return
	}

	if err := repository.CreateReport(userID, input.ContentType, input.ContentID, input.Reason); err != nil {
		log.Printf("[CreateReport] Erreur création signalement : %v", err)
		response.RespondWithError(w, http.StatusInternalServerError, "Erreur création signalement")
		return
	}

	log.Printf("[CreateReport] Signalement OK : user %d, %s %d", userID, input.ContentType, input.ContentID)
	response.RespondWithJSON(w, http.StatusCreated, map[string]string{"message": "Signalement envoyé"})
}

// ListPendingReports retourne la liste des signalements en attente de traitement.
func ListPendingReports(w http.ResponseWriter, r *http.Request) {
	reports, err := repository.ListReportsByStatus("pending")
	if err != nil {
		log.Printf("[ListPendingReports] Erreur récupération : %v", err)
		response.RespondWithError(w, http.StatusInternalServerError, "Erreur récupération signalements")
		return
	}
	log.Printf("[ListPendingReports] %d signalements récupérés", len(reports))
	response.RespondWithJSON(w, http.StatusOK, reports)
}

// ListReports retourne la liste de tous les signalements.
func ListReports(w http.ResponseWriter, r *http.Request) {
	reports, err := repository.ListReport()
	if err != nil {
		log.Printf("[ListReports] Erreur récupération : %v", err)
		response.RespondWithError(w, http.StatusInternalServerError, "Erreur récupération signalements")
		return
	}
	log.Printf("[ListReports] %d signalements récupérés", len(reports))
	response.RespondWithJSON(w, http.StatusOK, reports)
}

// UpdateReportStatus met à jour le statut d'un signalement.
func UpdateReportStatus(w http.ResponseWriter, r *http.Request) {
	reportID, err := strconv.ParseInt(chi.URLParam(r, "id"), 10, 64)
	if err != nil {
		log.Printf("[UpdateReportStatus] ID invalide : %v", err)
		response.RespondWithError(w, http.StatusBadRequest, "ID invalide")
		return
	}

	var body struct {
		Status string `json:"status"`
	}
	if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
		log.Printf("[UpdateReportStatus] JSON invalide : %v", err)
		response.RespondWithError(w, http.StatusBadRequest, "Corps de requête invalide")
		return
	}

	if err := repository.UpdateReportStatus(reportID, body.Status, time.Now()); err != nil {
		log.Printf("[UpdateReportStatus] Échec update statut %d : %v", reportID, err)
		response.RespondWithError(w, http.StatusInternalServerError, "Mise à jour échouée")
		return
	}

	log.Printf("[UpdateReportStatus] Statut du report %d mis à jour en %s", reportID, body.Status)
	response.RespondWithJSON(w, http.StatusOK, map[string]string{"message": "Statut mis à jour"})
}

// AdminActOnReport permet à un administrateur d'agir sur un signalement.
func AdminActOnReport(w http.ResponseWriter, r *http.Request) {
	reportID, err := strconv.ParseInt(chi.URLParam(r, "id"), 10, 64)
	if err != nil {
		log.Printf("[AdminActOnReport] ID invalide : %v", err)
		response.RespondWithError(w, http.StatusBadRequest, "ID invalide")
		return
	}

	var body struct {
		Action string `json:"action"` // "approved", "rejected", "pending"
	}
	if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
		log.Printf("[AdminActOnReport] JSON invalide : %v", err)
		response.RespondWithError(w, http.StatusBadRequest, "Corps invalide")
		return
	}

	switch body.Action {
	case "approved", "rejected", "pending":
		// OK
	default:
		log.Printf("[AdminActOnReport] Action non supportée : %s", body.Action)
		response.RespondWithError(w, http.StatusBadRequest, "Action non reconnue")
		return
	}

	if err := repository.AdminActOnReport(reportID, body.Action); err != nil {
		log.Printf("[AdminActOnReport] Erreur action '%s' sur report %d : %v", body.Action, reportID, err)
		response.RespondWithError(w, http.StatusInternalServerError, err.Error())
		return
	}

	log.Printf("[AdminActOnReport] Action '%s' appliquée à report %d", body.Action, reportID)
	response.RespondWithJSON(w, http.StatusOK, map[string]string{"message": "Action exécutée"})
}
