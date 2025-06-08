package service

import (
	"fmt"
	"log"
	"onlyflick/internal/config"
	"time"

	"github.com/golang-jwt/jwt"
	"golang.org/x/crypto/bcrypt"
)

// =====================
// Gestion des mots de passe
// =====================

// HashPassword génère un hash sécurisé pour un mot de passe donné.
func HashPassword(password string) (string, error) {
	log.Println("[AuthService] Hachage du mot de passe en cours")
	bytes, err := bcrypt.GenerateFromPassword([]byte(password), bcrypt.DefaultCost)
	if err != nil {
		log.Printf("[AuthService] Erreur lors du hachage du mot de passe : %v\n", err)
	}
	return string(bytes), err
}

// CheckPasswordHash vérifie si le mot de passe correspond au hash stocké.
func CheckPasswordHash(password, hash string) bool {
	log.Println("[AuthService] Vérification du mot de passe en cours")
	err := bcrypt.CompareHashAndPassword([]byte(hash), []byte(password))
	if err != nil {
		log.Printf("[AuthService] Mot de passe incorrect : %v\n", err)
	}
	return err == nil
}

// =====================
// Gestion des JWT
// =====================

// jwtSecret contient la clé secrète utilisée pour signer les tokens JWT.
var jwtSecret = []byte(config.SecretKey)

// GenerateJWT génère un token JWT pour un utilisateur donné avec une expiration de 24h.
func GenerateJWT(userID int64, role string) (string, error) {
	log.Printf("[AuthService] Génération du JWT pour l'utilisateur ID : %d, rôle : %s\n", userID, role)

	claims := jwt.MapClaims{
		"sub":  userID,
		"role": role,
		"exp":  time.Now().Add(time.Hour * 24).Unix(), // Expiration dans 24 heures
		"iat":  time.Now().Unix(),
	}

	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	log.Println("[AuthService] Signature du JWT avec la clé secrète")
	signedToken, err := token.SignedString(jwtSecret)
	if err != nil {
		log.Printf("[AuthService] Erreur lors de la signature du JWT : %v\n", err)
	}
	return signedToken, err
}

// ValidateJWT valide et parse un token JWT.
// Retourne le token si valide, sinon une erreur.
func ValidateJWT(tokenString string) (*jwt.Token, error) {
	log.Println("[AuthService] Validation du JWT en cours")
	token, err := jwt.Parse(tokenString, func(token *jwt.Token) (interface{}, error) {
		// Vérifie que le token utilise bien l'algorithme HS256
		if _, ok := token.Method.(*jwt.SigningMethodHMAC); !ok {
			log.Println("[AuthService] Méthode de signature invalide détectée")
			return nil, fmt.Errorf("méthode de signature invalide")
		}
		return jwtSecret, nil
	})

	if err != nil {
		log.Printf("[AuthService] Erreur lors de la validation du JWT : %v\n", err)
	}
	return token, err
}
