package response

import (
	"encoding/json"
	"log"
	"net/http"
)

// ErrorResponse représente la structure d'une réponse d'erreur JSON.
type ErrorResponse struct {
	Error   string `json:"error"`   // Type d'erreur HTTP (ex: "Not Found")
	Message string `json:"message"` // Message détaillé de l'erreur
}

// SuccessResponse représente la structure d'une réponse de succès JSON.
type SuccessResponse struct {
	Message string      `json:"message"`        // Message de succès
	Data    interface{} `json:"data,omitempty"` // Données optionnelles à retourner
}

// RespondWithError envoie une réponse d'erreur JSON au client.
// code : code de statut HTTP à retourner
// message : message d'erreur détaillé
func RespondWithError(w http.ResponseWriter, code int, message string) {
	resp := ErrorResponse{
		Error:   http.StatusText(code),
		Message: message,
	}
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(code)
	if err := json.NewEncoder(w).Encode(resp); err != nil {
		log.Printf("Erreur lors de l'encodage de la réponse d'erreur : %v", err)
	}
	log.Printf("Réponse d'erreur envoyée (%d): %s - %s", code, resp.Error, message)
}

// RespondWithJSON envoie une réponse JSON générique au client.
// code : code de statut HTTP à retourner
// payload : données à encoder en JSON
func RespondWithJSON(w http.ResponseWriter, code int, payload interface{}) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(code)
	if err := json.NewEncoder(w).Encode(payload); err != nil {
		log.Printf("Erreur lors de l'encodage de la réponse JSON : %v", err)
	}
	log.Printf("Réponse JSON envoyée (%d)", code)
}
