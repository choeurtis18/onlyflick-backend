package performance

import (
	"onlyflick/internal/service"
	"testing"
	"time"
)

func BenchmarkHashPassword(b *testing.B) {
	password := "benchmarkpassword123"

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		service.HashPassword(password)
	}
}

func BenchmarkCheckPasswordHash(b *testing.B) {
	password := "benchmarkpassword123"
	hash, _ := service.HashPassword(password)

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		service.CheckPasswordHash(password, hash)
	}
}

func BenchmarkGenerateJWT(b *testing.B) {
	userID := int64(123)
	role := "subscriber"

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		service.GenerateJWT(userID, role)
	}
}

func TestAuthenticationLatency(t *testing.T) {
	password := "latencytest123"

	// Test de latence pour le hachage
	start := time.Now()
	hash, err := service.HashPassword(password)
	hashDuration := time.Since(start)

	if err != nil {
		t.Fatalf("Erreur de hachage: %v", err)
	}

	// Test de latence pour la vérification
	start = time.Now()
	valid := service.CheckPasswordHash(password, hash)
	checkDuration := time.Since(start)

	if !valid {
		t.Fatal("La vérification du mot de passe a échoué")
	}

	t.Logf("Latence hachage: %v", hashDuration)
	t.Logf("Latence vérification: %v", checkDuration)

	// Vérifier que les opérations sont raisonnablement rapides
	if hashDuration > 500*time.Millisecond {
		t.Errorf("Hachage trop lent: %v", hashDuration)
	}

	if checkDuration > 500*time.Millisecond {
		t.Errorf("Vérification trop lente: %v", checkDuration)
	}
}
