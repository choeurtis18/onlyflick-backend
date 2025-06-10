package utils

import "os"

// Variable globale pour stocker la clé pendant les tests
var testSecretKey string

// SetSecretKeyForTesting définit la clé secrète pour les tests
func SetSecretKeyForTesting(key string) {
	testSecretKey = key
	// Forcer aussi la variable d'environnement
	os.Setenv("SECRET_KEY", key)
}

// GetSecretKeyForTesting récupère la clé secrète utilisée pour les tests
func GetSecretKeyForTesting() string {
	return testSecretKey
}

// GetEffectiveSecretKey retourne la clé effective (test ou environnement)
func GetEffectiveSecretKey() string {
	if testSecretKey != "" {
		return testSecretKey
	}
	return os.Getenv("SECRET_KEY")
}

// IsTestMode indique si nous sommes en mode test
func IsTestMode() bool {
	return testSecretKey != ""
}
