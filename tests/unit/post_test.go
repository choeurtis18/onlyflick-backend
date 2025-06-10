package unit

import (
	"onlyflick/internal/domain"
	"onlyflick/internal/repository"
	"onlyflick/internal/utils"
	"os"
	"testing"
	"time"

	"github.com/DATA-DOG/go-sqlmock"
	"github.com/stretchr/testify/assert"
)

func TestListVisiblePosts(t *testing.T) {
	// Configuration
	os.Setenv("SECRET_KEY", "12345678901234567890123456789012")
	utils.SetSecretKeyForTesting("12345678901234567890123456789012")
	defer utils.SetSecretKeyForTesting("")

	mock, cleanup := setupMockDB(t)
	defer cleanup()

	// Mock pour récupérer les posts visibles - regex flexible
	mock.ExpectQuery("SELECT.*FROM posts WHERE.*visibility.*ORDER BY").
		WillReturnRows(sqlmock.NewRows([]string{"id", "user_id", "title", "description", "media_url", "visibility", "created_at", "updated_at"}).
			AddRow(1, 123, "Post 1", "Description 1", "url1", "public", time.Now(), time.Now()).
			AddRow(2, 456, "Post 2", "Description 2", "url2", "public", time.Now(), time.Now()))

	posts, err := repository.ListVisiblePosts("guest")

	assert.NoError(t, err)
	assert.Len(t, posts, 2)
	if len(posts) > 0 {
		assert.Equal(t, "Post 1", posts[0].Title)
	}
}

func TestCreatePost(t *testing.T) {
	// Configuration
	os.Setenv("SECRET_KEY", "12345678901234567890123456789012")
	utils.SetSecretKeyForTesting("12345678901234567890123456789012")
	defer utils.SetSecretKeyForTesting("")

	mock, cleanup := setupMockDB(t)
	defer cleanup()

	post := &domain.Post{
		UserID:      123,
		Title:       "Test Post",
		Description: "Test Description",
		MediaURL:    "test-url",
		Visibility:  domain.Visibility("public"),
	}

	// Mock pour créer le post - regex plus flexible
	mock.ExpectQuery("INSERT INTO posts.*VALUES.*RETURNING").
		WithArgs(post.UserID, post.Title, post.Description, post.MediaURL, post.FileID, post.Visibility).
		WillReturnRows(sqlmock.NewRows([]string{"id", "created_at", "updated_at"}).
			AddRow(1, time.Now(), time.Now()))

	err := repository.CreatePost(post)

	assert.NoError(t, err)
	assert.Equal(t, int64(1), post.ID)
}
