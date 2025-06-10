package unit

import (
	"onlyflick/internal/repository"
	"onlyflick/internal/utils"
	"os"
	"testing"

	"github.com/DATA-DOG/go-sqlmock"
	"github.com/stretchr/testify/assert"
)

func TestIsLiked(t *testing.T) {
	// Configuration
	os.Setenv("SECRET_KEY", "12345678901234567890123456789012")
	utils.SetSecretKeyForTesting("12345678901234567890123456789012")
	defer utils.SetSecretKeyForTesting("")

	mock, cleanup := setupMockDB(t)
	defer cleanup()

	userID := int64(123)
	postID := int64(456)

	// Mock pour vérifier si l'utilisateur a liké
	mock.ExpectQuery("SELECT EXISTS.*FROM likes WHERE user_id.*AND post_id").
		WithArgs(userID, postID).
		WillReturnRows(sqlmock.NewRows([]string{"exists"}).AddRow(true))

	liked, err := repository.IsLiked(userID, postID)

	assert.NoError(t, err)
	assert.True(t, liked)
}

func TestToggleLike(t *testing.T) {
	// Configuration
	os.Setenv("SECRET_KEY", "12345678901234567890123456789012")
	utils.SetSecretKeyForTesting("12345678901234567890123456789012")
	defer utils.SetSecretKeyForTesting("")

	mock, cleanup := setupMockDB(t)
	defer cleanup()

	userID := int64(123)
	postID := int64(456)

	// Mock pour vérifier si l'utilisateur a déjà liké (non liké)
	mock.ExpectQuery("SELECT EXISTS.*FROM likes WHERE user_id.*AND post_id").
		WithArgs(userID, postID).
		WillReturnRows(sqlmock.NewRows([]string{"exists"}).AddRow(false))

	// Mock pour ajouter le like
	mock.ExpectExec("INSERT INTO likes.*VALUES").
		WithArgs(userID, postID).
		WillReturnResult(sqlmock.NewResult(1, 1))

	liked, err := repository.ToggleLike(userID, postID)

	assert.NoError(t, err)
	assert.True(t, liked)
}
