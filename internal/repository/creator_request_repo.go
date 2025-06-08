package repository

import (
	"fmt"
	"log"
	"time"

	"onlyflick/internal/database"
)

// CreatorRequest représente une demande de passage en créateur.
type CreatorRequest struct {
	ID        int64     `json:"id"`
	UserID    int64     `json:"user_id"`
	Status    string    `json:"status"`
	CreatedAt time.Time `json:"created_at"`
	UpdatedAt time.Time `json:"updated_at"`
}

// FlagUserAsPendingCreator ajoute une demande de passage en créateur pour l'utilisateur donné.
// Si une demande existe déjà pour cet utilisateur, rien n'est fait.
func FlagUserAsPendingCreator(userID int64) error {
	log.Printf("[CreatorRequest] Ajout d'une demande de passage en créateur pour l'utilisateur ID: %d", userID)

	query := `
      INSERT INTO creator_requests (user_id, status)
      VALUES ($1, 'pending')
      ON CONFLICT (user_id)
      DO UPDATE SET status = 'pending', updated_at = NOW();
	`
	_, err := database.DB.Exec(query, userID)
	if err != nil {
		log.Printf("[CreatorRequest][ERREUR] Impossible d'insérer la demande pour l'utilisateur ID: %d : %v", userID, err)
		return fmt.Errorf("échec de l'insertion de la demande de créateur: %w", err)
	}
	log.Printf("[CreatorRequest] Demande ajoutée (ou déjà existante) pour l'utilisateur ID: %d", userID)
	return nil
}

// GetAllPendingRequests récupère toutes les demandes de passage en créateur.
// Retourne la liste complète, peu importe le statut.
func GetAllPendingRequests() ([]CreatorRequest, error) {
	log.Println("[CreatorRequest] Récupération de toutes les demandes de créateur")

	query := `SELECT id, user_id, status, created_at, updated_at FROM creator_requests`
	rows, err := database.DB.Query(query)
	if err != nil {
		log.Printf("[CreatorRequest][ERREUR] Erreur lors de la récupération des demandes : %v", err)
		return nil, fmt.Errorf("échec de la récupération des demandes: %w", err)
	}
	defer rows.Close()

	var requests []CreatorRequest
	for rows.Next() {
		var r CreatorRequest
		if err := rows.Scan(&r.ID, &r.UserID, &r.Status, &r.CreatedAt, &r.UpdatedAt); err != nil {
			log.Printf("[CreatorRequest][ERREUR] Erreur lors du scan d'une ligne : %v", err)
			return nil, fmt.Errorf("échec du scan d'une demande: %w", err)
		}
		requests = append(requests, r)
	}

	log.Printf("[CreatorRequest] %d demandes trouvées", len(requests))
	return requests, nil
}

// ApproveCreatorRequest approuve une demande de passage en créateur et met à jour le rôle de l'utilisateur.
// Effectue l'opération dans une transaction pour garantir la cohérence.
func ApproveCreatorRequest(requestID int64) error {
	log.Printf("[CreatorRequest] Approbation de la demande ID: %d", requestID)

	tx, err := database.DB.Begin()
	if err != nil {
		log.Printf("[CreatorRequest][ERREUR] Impossible de démarrer la transaction : %v", err)
		return fmt.Errorf("échec de la création de la transaction: %w", err)
	}
	defer tx.Rollback()

	// Récupération de l'ID utilisateur lié à la demande
	var userID int64
	err = tx.QueryRow(`SELECT user_id FROM creator_requests WHERE id = $1`, requestID).Scan(&userID)
	if err != nil {
		log.Printf("[CreatorRequest][ERREUR] Impossible de récupérer la demande ID: %d : %v", requestID, err)
		return fmt.Errorf("échec de la récupération de la demande: %w", err)
	}

	// Mise à jour du rôle de l'utilisateur
	_, err = tx.Exec(`UPDATE users SET role = 'creator' WHERE id = $1`, userID)
	if err != nil {
		log.Printf("[CreatorRequest][ERREUR] Impossible de mettre à jour le rôle de l'utilisateur ID: %d : %v", userID, err)
		return fmt.Errorf("échec de la mise à jour du rôle utilisateur: %w", err)
	}

	// Mise à jour du statut de la demande
	_, err = tx.Exec(`UPDATE creator_requests SET status = 'approved', updated_at = NOW() WHERE id = $1`, requestID)
	if err != nil {
		log.Printf("[CreatorRequest][ERREUR] Impossible de mettre à jour le statut de la demande ID: %d : %v", requestID, err)
		return fmt.Errorf("échec de la mise à jour du statut de la demande: %w", err)
	}

	if err := tx.Commit(); err != nil {
		log.Printf("[CreatorRequest][ERREUR] Commit de la transaction échoué : %v", err)
		return fmt.Errorf("échec du commit de la transaction: %w", err)
	}

	log.Printf("[CreatorRequest] Demande ID: %d approuvée et rôle utilisateur mis à jour", requestID)
	return nil
}

// RejectCreatorRequest rejette une demande de passage en créateur.
func RejectCreatorRequest(requestID int64) error {
	log.Printf("[CreatorRequest] Rejet de la demande ID: %d", requestID)

	_, err := database.DB.Exec(`
		UPDATE creator_requests
		SET status = 'rejected', updated_at = NOW()
		WHERE id = $1`, requestID)
	if err != nil {
		log.Printf("[CreatorRequest][ERREUR] Impossible de rejeter la demande ID: %d : %v", requestID, err)
		return fmt.Errorf("échec du rejet de la demande: %w", err)
	}

	log.Printf("[CreatorRequest] Demande ID: %d rejetée", requestID)
	return nil
}
