package service

import (
	"context"
	"fmt"
	"log"
	"mime/multipart"
	"os"

	"github.com/imagekit-developer/imagekit-go"
	"github.com/imagekit-developer/imagekit-go/api/uploader"
)

// Client global pour ImageKit
var imageKitClient *imagekit.ImageKit

// InitImageKit initialise le client ImageKit avec les clés d'environnement
func InitImageKit() {
	imageKitClient = imagekit.NewFromParams(imagekit.NewParams{
		PublicKey:  os.Getenv("IMAGEKIT_PUBLIC_KEY"),
		PrivateKey: os.Getenv("IMAGEKIT_PRIVATE_KEY"),
	})

	log.Println("✅ [ImageKit] Client initialisé avec succès")
}

// UploadFile téléverse un fichier sur ImageKit et retourne l'URL et l'ID du fichier
func UploadFile(file multipart.File, fileName string) (string, string, error) {
	log.Printf("⏳ [ImageKit] Téléversement du fichier : %s", fileName)

	resp, err := imageKitClient.Uploader.Upload(context.Background(), file, uploader.UploadParam{
		FileName: fileName,
	})
	if err != nil {
		log.Printf("❌ [ImageKit] Erreur lors du téléversement du fichier '%s' : %v", fileName, err)
		return "", "", fmt.Errorf("échec du téléversement sur ImageKit : %w", err)
	}

	log.Printf("✅ [ImageKit] Fichier téléversé : %s (ID : %s)", resp.Data.Url, resp.Data.FileId)
	return resp.Data.Url, resp.Data.FileId, nil
}

// DeleteFile supprime un fichier d'ImageKit à partir de son ID
func DeleteFile(fileID string) error {
	log.Printf("⏳ [ImageKit] Suppression du fichier : %s", fileID)

	_, err := imageKitClient.Media.DeleteFile(context.Background(), fileID)
	if err != nil {
		log.Printf("❌ [ImageKit] Erreur lors de la suppression du fichier '%s' : %v", fileID, err)
		return fmt.Errorf("échec de la suppression sur ImageKit : %w", err)
	}

	log.Printf("✅ [ImageKit] Fichier supprimé : %s", fileID)
	return nil
}
