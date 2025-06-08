package utils

import (
	"crypto/aes"
	"crypto/cipher"
	"crypto/rand"
	"encoding/base64"
	"errors"
	"io"
	"log"
	"onlyflick/internal/config"
)

// Encrypt chiffre une chaîne de caractères en utilisant AES-GCM et retourne le résultat encodé en base64.
// Retourne une erreur en cas d'échec.
func Encrypt(plainText string) (string, error) {
	// Création du bloc AES à partir de la clé secrète
	block, err := aes.NewCipher([]byte(config.SecretKey))
	if err != nil {
		log.Printf("[Chiffrement] Erreur lors de la création du bloc AES : %v", err)
		return "", err
	}

	// Création du mode GCM
	aesGCM, err := cipher.NewGCM(block)
	if err != nil {
		log.Printf("[Chiffrement] Erreur lors de la création du mode GCM : %v", err)
		return "", err
	}

	// Génération du nonce aléatoire
	nonce := make([]byte, aesGCM.NonceSize())
	if _, err := io.ReadFull(rand.Reader, nonce); err != nil {
		log.Printf("[Chiffrement] Erreur lors de la génération du nonce : %v", err)
		return "", err
	}
	log.Printf("[Chiffrement] Nonce généré de taille %d octets", len(nonce))

	// Chiffrement du texte en clair
	cipherText := aesGCM.Seal(nonce, nonce, []byte(plainText), nil)
	log.Printf("[Chiffrement] Texte chiffré, taille totale (nonce + données) : %d octets", len(cipherText))

	// Encodage en base64
	encoded := base64.StdEncoding.EncodeToString(cipherText)
	log.Printf("[Chiffrement] Texte chiffré encodé en base64, taille : %d caractères", len(encoded))

	return encoded, nil
}

// Decrypt déchiffre une chaîne encodée en base64 chiffrée avec AES-GCM.
// Retourne le texte en clair ou une erreur.
func Decrypt(encrypted string) (string, error) {
	// Décodage base64
	cipherData, err := base64.StdEncoding.DecodeString(encrypted)
	if err != nil {
		log.Printf("[Déchiffrement] Erreur lors du décodage base64 : %v", err)
		return "", err
	}

	// Création du bloc AES à partir de la clé secrète
	block, err := aes.NewCipher([]byte(config.SecretKey))
	if err != nil {
		log.Printf("[Déchiffrement] Erreur lors de la création du bloc AES : %v", err)
		return "", err
	}

	// Création du mode GCM
	aesGCM, err := cipher.NewGCM(block)
	if err != nil {
		log.Printf("[Déchiffrement] Erreur lors de la création du mode GCM : %v", err)
		return "", err
	}

	nonceSize := aesGCM.NonceSize()
	if len(cipherData) < nonceSize {
		log.Printf("[Déchiffrement] Données chiffrées trop courtes : %d octets", len(cipherData))
		return "", errors.New("invalid ciphertext")
	}

	// Séparation du nonce et du texte chiffré
	nonce, cipherText := cipherData[:nonceSize], cipherData[nonceSize:]
	log.Printf("[Déchiffrement] Nonce extrait de taille %d octets", len(nonce))
	log.Printf("[Déchiffrement] Données à déchiffrer de taille %d octets", len(cipherText))

	// Déchiffrement
	plainText, err := aesGCM.Open(nil, nonce, cipherText, nil)
	if err != nil {
		log.Printf("[Déchiffrement] Erreur lors du déchiffrement : %v", err)
		return "", err
	}

	log.Printf("[Déchiffrement] Texte déchiffré avec succès, taille : %d octets", len(plainText))
	return string(plainText), nil
}
