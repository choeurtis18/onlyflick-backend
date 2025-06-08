package service

import (
	"bytes"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"mime/multipart"
	"net/http"
	"os"

	"github.com/joho/godotenv"
)

// ImageKitService gère l'intégration avec l'API ImageKit
type ImageKitService struct {
	PublicKey   string
	PrivateKey  string
	URLEndpoint string
}

// NewImageKitService initialise le service ImageKit en chargeant les variables d'environnement
func NewImageKitService() (*ImageKitService, error) {
	// Chargement du fichier .env
	if err := godotenv.Load(); err != nil {
		return nil, fmt.Errorf("erreur de chargement du fichier .env : %v", err)
	}

	publicKey := os.Getenv("IMAGEKIT_PUBLIC_KEY")
	privateKey := os.Getenv("IMAGEKIT_PRIVATE_KEY")
	urlEndpoint := os.Getenv("IMAGEKIT_URL_ENDPOINT")

	// Vérification de la présence des variables d'environnement nécessaires
	if publicKey == "" || privateKey == "" || urlEndpoint == "" {
		return nil, fmt.Errorf("les variables d'environnement ImageKit sont manquantes")
	}

	return &ImageKitService{
		PublicKey:   publicKey,
		PrivateKey:  privateKey,
		URLEndpoint: urlEndpoint,
	}, nil
}

// UploadImage envoie une image à ImageKit et retourne son URL et son FileID
func (ik *ImageKitService) UploadImage(file multipart.File, fileHeader *multipart.FileHeader) (string, string, error) {
	log.Println("[ImageKit] Début de l'upload de l'image...")

	defer file.Close()

	// Lecture du fichier image
	fileBytes, err := io.ReadAll(file)
	if err != nil {
		log.Printf("[ImageKit][erreur] Lecture du fichier image : %v", err)
		return "", "", fmt.Errorf("erreur lors de la lecture du fichier image : %v", err)
	}

	// Encodage en base64 avec le type MIME
	encoded := base64.StdEncoding.EncodeToString(fileBytes)
	mimeType := fileHeader.Header.Get("Content-Type")
	encoded = fmt.Sprintf("data:%s;base64,%s", mimeType, encoded)

	// Préparation du corps de la requête multipart
	var requestBody bytes.Buffer
	writer := multipart.NewWriter(&requestBody)
	writer.WriteField("file", encoded)
	writer.WriteField("fileName", fileHeader.Filename)
	writer.WriteField("useUniqueFileName", "true")
	writer.Close()

	// Création de la requête HTTP POST
	req, err := http.NewRequest("POST", "https://upload.imagekit.io/api/v1/files/upload", &requestBody)
	if err != nil {
		log.Printf("[ImageKit][erreur] Création de la requête POST : %v", err)
		return "", "", fmt.Errorf("erreur lors de la création de la requête : %v", err)
	}
	req.SetBasicAuth(ik.PublicKey, ik.PrivateKey)
	req.Header.Set("Content-Type", writer.FormDataContentType())

	// Envoi de la requête
	client := &http.Client{}
	resp, err := client.Do(req)
	if err != nil {
		log.Printf("[ImageKit][erreur] Envoi de la requête POST : %v", err)
		return "", "", fmt.Errorf("erreur lors de l'envoi de la requête : %v", err)
	}
	defer resp.Body.Close()

	// Lecture de la réponse
	respBody, err := io.ReadAll(resp.Body)
	if err != nil {
		log.Printf("[ImageKit][erreur] Lecture de la réponse : %v", err)
		return "", "", fmt.Errorf("erreur lors de la lecture de la réponse : %v", err)
	}

	// Vérification du code de statut HTTP
	if resp.StatusCode != http.StatusOK {
		log.Printf("[ImageKit][erreur] Upload échoué (%d) : %s", resp.StatusCode, respBody)
		return "", "", fmt.Errorf("échec de l'upload : %s", respBody)
	}

	// Décodage de la réponse JSON
	type uploadResponse struct {
		URL    string `json:"url"`
		FileID string `json:"fileId"`
	}
	var result uploadResponse
	if err := json.Unmarshal(respBody, &result); err != nil {
		log.Printf("[ImageKit][erreur] Analyse de la réponse JSON : %v", err)
		return "", "", fmt.Errorf("erreur lors de l'analyse de la réponse JSON : %v", err)
	}

	log.Printf("[ImageKit] Image uploadée avec succès : URL=%s, FileID=%s", result.URL, result.FileID)
	return result.URL, result.FileID, nil
}

// DeleteImage supprime une image sur ImageKit à partir de son FileID
func (ik *ImageKitService) DeleteImage(fileID string) error {
	log.Printf("[ImageKit] Début de la suppression de l'image (FileID : %s)...", fileID)

	// Création de la requête HTTP DELETE
	req, err := http.NewRequest("DELETE", fmt.Sprintf("https://api.imagekit.io/v1/files/%s", fileID), nil)
	if err != nil {
		log.Printf("[ImageKit][erreur] Création de la requête DELETE : %v", err)
		return fmt.Errorf("erreur lors de la création de la requête DELETE : %v", err)
	}
	req.SetBasicAuth(ik.PublicKey, ik.PrivateKey)

	// Envoi de la requête
	client := &http.Client{}
	resp, err := client.Do(req)
	if err != nil {
		log.Printf("[ImageKit][erreur] Envoi de la requête DELETE : %v", err)
		return fmt.Errorf("erreur lors de l'envoi de la requête DELETE : %v", err)
	}
	defer resp.Body.Close()

	// Vérification du code de statut HTTP
	if resp.StatusCode != http.StatusOK {
		respBody, _ := io.ReadAll(resp.Body)
		log.Printf("[ImageKit][erreur] Suppression échouée (%d) : %s", resp.StatusCode, respBody)
		return fmt.Errorf("échec de la suppression : %s", respBody)
	}

	log.Printf("[ImageKit] Image supprimée avec succès (FileID : %s)", fileID)
	return nil
}
