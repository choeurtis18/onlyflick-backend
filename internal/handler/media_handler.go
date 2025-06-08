package handler

import (
	"log"
	"net/http"
	"onlyflick/internal/middleware"
	"onlyflick/internal/service"
	"onlyflick/pkg/response"
	"path/filepath"

	"github.com/go-chi/chi/v5"
)

// UploadMedia traite l'upload d'un fichier via un formulaire multipart.
// Le fichier est transmis à ImageKit et ses métadonnées sont retournées.
func UploadMedia(w http.ResponseWriter, r *http.Request) {
	log.Println("[UploadMedia] Début de l'upload")

	if err := r.ParseMultipartForm(10 << 20); err != nil {
		log.Printf("[UploadMedia] Erreur parsing multipart : %v", err)
		response.RespondWithError(w, http.StatusBadRequest, "Formulaire invalide")
		return
	}

	file, header, err := r.FormFile("file")
	if err != nil {
		log.Printf("[UploadMedia] Fichier manquant ou invalide : %v", err)
		response.RespondWithError(w, http.StatusBadRequest, "Fichier requis")
		return
	}
	defer file.Close()

	ext := filepath.Ext(header.Filename)
	if ext == "" {
		log.Printf("[UploadMedia] Extension manquante pour : %s", header.Filename)
		response.RespondWithError(w, http.StatusBadRequest, "Extension de fichier requise")
		return
	}

	url, fileID, err := service.UploadFile(file, header.Filename)
	if err != nil {
		log.Printf("[UploadMedia] Upload échoué : %v", err)
		response.RespondWithError(w, http.StatusInternalServerError, "Échec de l'upload")
		return
	}

	log.Printf("[UploadMedia] Succès - URL=%s, ID=%s", url, fileID)
	response.RespondWithJSON(w, http.StatusOK, map[string]string{
		"url":     url,
		"file_id": fileID,
	})
}

// DeleteMedia supprime un média via son file_id.
// Accès restreint aux rôles "admin" et "creator".
func DeleteMedia(w http.ResponseWriter, r *http.Request) {
	log.Println("[DeleteMedia] Suppression de média")

	roleVal := r.Context().Value(middleware.ContextUserRoleKey)
	userRole, _ := roleVal.(string)

	if userRole != "admin" && userRole != "creator" {
		log.Printf("[DeleteMedia] Rôle non autorisé : %s", userRole)
		response.RespondWithError(w, http.StatusForbidden, "Accès refusé")
		return
	}

	fileID := chi.URLParam(r, "file_id")
	if fileID == "" {
		log.Println("[DeleteMedia] file_id manquant")
		response.RespondWithError(w, http.StatusBadRequest, "file_id requis")
		return
	}

	if err := service.DeleteFile(fileID); err != nil {
		log.Printf("[DeleteMedia] Échec suppression ID=%s : %v", fileID, err)
		response.RespondWithError(w, http.StatusInternalServerError, "Suppression échouée")
		return
	}

	log.Printf("[DeleteMedia] Suppression réussie - ID=%s", fileID)
	response.RespondWithJSON(w, http.StatusOK, map[string]string{
		"message": "Média supprimé avec succès",
	})
}
