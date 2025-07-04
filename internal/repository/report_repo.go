package repository

import (
	"fmt"
	"log"
	"onlyflick/internal/database"
	"onlyflick/internal/domain"
	"time"
)

// CreateReport insère un nouveau signalement dans la base de données.
func CreateReport(userID int64, contentType string, contentID int64, reason string) error {
	_, err := database.DB.Exec(`
		INSERT INTO reports (user_id, content_type, content_id, reason, status, created_at, updated_at)
		VALUES ($1, $2, $3, $4, 'pending', NOW(), NOW())
	`, userID, contentType, contentID, reason)
	if err != nil {
		log.Printf("[ERREUR] Impossible de créer le signalement : %v", err)
	}
	return err
}

// ListReport retourne tous les signalements enrichis (posts & commentaires)
func ListReport() ([]domain.Report, error) {
	query := `
		SELECT 
			r.id,
			r.user_id,
			u.username,
			r.content_type,
			r.content_id,
			r.reason,
			r.status,
			r.created_at,
			r.updated_at,
			p.title AS content_text,
			p.media_url AS content_media
		FROM reports r
		JOIN users u ON r.user_id = u.id
		JOIN posts p ON r.content_id = p.id
		WHERE r.content_type = 'post'

		UNION

		SELECT 
			r.id,
			r.user_id,
			u.username,
			r.content_type,
			r.content_id,
			r.reason,
			r.status,
			r.created_at,
			r.updated_at,
			c.content AS content_text,
			NULL AS content_media
		FROM reports r
		JOIN users u ON r.user_id = u.id
		JOIN comments c ON r.content_id = c.id
		WHERE r.content_type = 'comment'

		ORDER BY created_at DESC
	`

	rows, err := database.DB.Query(query)
	if err != nil {
		log.Printf("[ERREUR] Impossible de lister les signalements : %v", err)
		return nil, err
	}
	defer rows.Close()

	var reports []domain.Report
	for rows.Next() {
		var r domain.Report
		if err := rows.Scan(
			&r.ID,
			&r.UserID,
			&r.ReporterUsername,
			&r.ContentType,
			&r.ContentID,
			&r.Reason,
			&r.Status,
			&r.CreatedAt,
			&r.ProcessedAt,
			&r.ContentText,     // post.title ou comment.text
			&r.ContentMediaURL, // post.media_url ou NULL
		); err != nil {
			log.Printf("[ERREUR] Scan ligne report : %v", err)
			return nil, err
		}
		reports = append(reports, r)
	}

	log.Printf("[INFO] %d signalements enrichis récupérés", len(reports))
	return reports, nil
}

// ListReportsByStatus retourne les signalements filtrés par statut.
func ListReportsByStatus(status string) ([]domain.Report, error) {
	rows, err := database.DB.Query(`
		SELECT id, user_id, content_type, content_id, reason, status, created_at, updated_at
		FROM reports
		WHERE status = $1
		ORDER BY created_at DESC
	`, status)
	if err != nil {
		log.Printf("[ERREUR] Impossible de lister les signalements par statut '%s' : %v", status, err)
		return nil, err
	}
	defer rows.Close()

	var reports []domain.Report
	for rows.Next() {
		var r domain.Report
		if err := rows.Scan(&r.ID, &r.UserID, &r.ContentType, &r.ContentID, &r.Reason, &r.Status, &r.CreatedAt, &r.ProcessedAt); err != nil {
			log.Printf("[ERREUR] Impossible de scanner le signalement : %v", err)
			return nil, err
		}
		reports = append(reports, r)
	}
	log.Printf("[INFO] %d signalements avec le statut '%s' récupérés", len(reports), status)
	return reports, nil
}

// UpdateReportStatus met à jour le statut et la date de traitement d'un signalement.
func UpdateReportStatus(reportID int64, status string, processedAt time.Time) error {
	_, err := database.DB.Exec(`
		UPDATE reports
		SET status = $1, updated_at = $2
		WHERE id = $3
	`, status, processedAt, reportID)
	if err != nil {
		log.Printf("[ERREUR] Impossible de mettre à jour le statut du signalement %d : %v", reportID, err)
	}
	return err
}

// AdminActOnReport permet à un administrateur d'agir sur un signalement (approuver ou rejeter).
// Si approuvé, le contenu signalé et ses signalements associés sont supprimés.
func AdminActOnReport(reportID int64, action string) error {
	tx, err := database.DB.Begin()
	if err != nil {
		log.Printf("[ERREUR] Impossible de démarrer la transaction : %v", err)
		return err
	}
	defer tx.Rollback()

	var contentType string
	var contentID int64
	err = tx.QueryRow(`
		SELECT content_type, content_id FROM reports WHERE id = $1
	`, reportID).Scan(&contentType, &contentID)
	if err != nil {
		log.Printf("[ERREUR] Impossible de récupérer le contenu du signalement %d : %v", reportID, err)
		return err
	}

	// Mise à jour du statut du signalement
	_, err = tx.Exec(`
		UPDATE reports SET status = $1, updated_at = NOW() WHERE id = $2
	`, action, reportID)
	if err != nil {
		log.Printf("[ERREUR] Impossible de mettre à jour le statut du signalement %d : %v", reportID, err)
		return err
	}

	// Supprimer le contenu ET ses reports s'il est approuvé
	if action == "approved" {
		switch contentType {
		case "post":
			if _, err := tx.Exec(`DELETE FROM posts WHERE id = $1`, contentID); err != nil {
				log.Printf("[ERREUR] Impossible de supprimer le post %d : %v", contentID, err)
				return err
			}
			if _, err := tx.Exec(`DELETE FROM reports WHERE content_type = 'post' AND content_id = $1`, contentID); err != nil {
				log.Printf("[ERREUR] Impossible de supprimer les signalements du post %d : %v", contentID, err)
				return err
			}
			log.Printf("[INFO] Post %d et ses signalements supprimés", contentID)
		case "comment":
			if _, err := tx.Exec(`DELETE FROM comments WHERE id = $1`, contentID); err != nil {
				log.Printf("[ERREUR] Impossible de supprimer le commentaire %d : %v", contentID, err)
				return err
			}
			if _, err := tx.Exec(`DELETE FROM reports WHERE content_type = 'comment' AND content_id = $1`, contentID); err != nil {
				log.Printf("[ERREUR] Impossible de supprimer les signalements du commentaire %d : %v", contentID, err)
				return err
			}
			log.Printf("[INFO] Commentaire %d et ses signalements supprimés", contentID)
		default:
			log.Printf("[ERREUR] Type de contenu inconnu : %s", contentType)
			return fmt.Errorf("unknown content type: %s", contentType)
		}
	}

	if err := tx.Commit(); err != nil {
		log.Printf("[ERREUR] Impossible de valider la transaction : %v", err)
		return err
	}
	log.Printf("[INFO] Action '%s' appliquée sur le signalement %d", action, reportID)
	return nil
}
