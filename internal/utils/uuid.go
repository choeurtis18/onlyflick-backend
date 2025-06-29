package utils

import (
	"github.com/google/uuid"
)

// GenerateUUID génère un UUID unique sous forme de chaîne
func GenerateUUID() string {
	return uuid.New().String()
}
