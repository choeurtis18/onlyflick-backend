// internal/domain/search.go

package domain

import (
	"fmt"
	"time"
)

// ✅ SUPPRESSION DE TagCategory - Utilisation directe de strings
// Les tags sont maintenant gérés directement en string pour simplifier

// SortType représente les différents types de tri pour les posts
type SortType string

const (
	SortRelevance     SortType = "relevance"      // Algorithme basé sur l'historique utilisateur
	SortPopular24h    SortType = "popular_24h"    // Posts populaires dernières 24h
	SortPopularWeek   SortType = "popular_week"   // Posts populaires cette semaine
	SortPopularMonth  SortType = "popular_month"  // Posts populaires ce mois
	SortRecent        SortType = "recent"         // Posts récents par ordre chronologique
)

// InteractionType représente le type d'interaction
type InteractionType string

const (
	InteractionView        InteractionType = "view"         // Vue d'un post
	InteractionLike        InteractionType = "like"         // Like d'un post
	InteractionComment     InteractionType = "comment"      // Commentaire sur un post
	InteractionShare       InteractionType = "share"        // Partage d'un post
	InteractionProfileView InteractionType = "profile_view" // Vue d'un profil
	InteractionSearch      InteractionType = "search"       // Recherche d'un terme
	InteractionTagClick    InteractionType = "tag_click"    // Clic sur un tag
)

// UserSearchResult représente un utilisateur dans les résultats de recherche
type UserSearchResult struct {
	ID               int64  `json:"id"`
	Username         string `json:"username"`
	FirstName        string `json:"first_name"`
	LastName         string `json:"last_name"`
	FullName         string `json:"full_name"`         // Nom complet calculé
	AvatarURL        string `json:"avatar_url"`
	Bio              string `json:"bio"`
	Role             string `json:"role"`              // "subscriber", "creator", "admin"
	IsCreator        bool   `json:"is_creator"`        // true si role = "creator"
	FollowersCount   int64  `json:"followers_count"`
	PostsCount       int64  `json:"posts_count"`
	IsFollowing      bool   `json:"is_following"`      // Si l'utilisateur actuel suit cette personne
	MutualFollowers  int64  `json:"mutual_followers"`  // Nombre d'amis en commun
}

// SearchResult représente le résultat d'une recherche
type SearchResult struct {
	Posts   []PostWithDetails  `json:"posts"`
	Users   []UserSearchResult `json:"users"`
	Total   int                `json:"total"`
	HasMore bool               `json:"has_more"`
}

// PostWithDetails représente un post avec ses détails étendus pour la recherche
type PostWithDetails struct {
	ID              int64            `json:"id"`
	UserID          int64            `json:"user_id"`
	Title           string           `json:"title"`
	Description     string           `json:"description"`
	MediaURL        string           `json:"media_url"`
	FileID          string           `json:"file_id"`
	Visibility      string           `json:"visibility"`
	CreatedAt       time.Time        `json:"created_at"`
	UpdatedAt       time.Time        `json:"updated_at"`
	Author          UserSearchResult `json:"author"`           // Auteur du post
	Tags            []string         `json:"tags"`             // ✅ Tags en string maintenant
	LikesCount      int64            `json:"likes_count"`      // Nombre de likes
	CommentsCount   int64            `json:"comments_count"`   // Nombre de commentaires
	ViewsCount      int64            `json:"views_count"`      // Nombre de vues
	IsLiked         bool             `json:"is_liked"`         // Si l'utilisateur actuel a liké
	PopularityScore float64          `json:"popularity_score"` // Score de popularité calculé
	RelevanceScore  float64          `json:"relevance_score"`  // Score de pertinence pour l'utilisateur
}

// ✅ SearchRequest corrigé avec tags en string
type SearchRequest struct {
	Query        string   `json:"query"`         // Terme de recherche
	UserID       int64    `json:"user_id"`       // ID de l'utilisateur qui recherche
	Tags         []string `json:"tags"`          // ✅ Filtres par tags (string maintenant)
	SortBy       SortType `json:"sort_by"`       // Type de tri
	Limit        int      `json:"limit"`         // Nombre de résultats max
	Offset       int      `json:"offset"`        // Pagination
	SearchType   string   `json:"search_type"`   // "posts", "users", "discovery"
}

// ✅ DiscoveryRequest corrigé avec tags en string
type DiscoveryRequest struct {
	UserID int64    `json:"user_id"`
	Tags   []string `json:"tags"`     // ✅ Filtres optionnels par tags (string maintenant)
	SortBy SortType `json:"sort_by"`  // Type de tri
	Limit  int      `json:"limit"`
	Offset int      `json:"offset"`
}

// ✅ PostTag simplifié avec string
type PostTag struct {
	ID        int64     `json:"id"`
	PostID    int64     `json:"post_id"`
	Category  string    `json:"category"`  // ✅ String au lieu de TagCategory
	CreatedAt time.Time `json:"created_at"`
}

// UserInteraction représente une interaction utilisateur pour l'algorithme de recommandation
type UserInteraction struct {
	ID              int64           `json:"id"`
	UserID          int64           `json:"user_id"`
	InteractionType InteractionType `json:"interaction_type"`
	ContentType     string          `json:"content_type"`    // "post", "user", "tag"
	ContentID       int64           `json:"content_id"`      // ID du post, user ou tag
	ContentMeta     string          `json:"content_meta"`    // Métadonnées supplémentaires (ex: tag category)
	Score           float64         `json:"score"`           // Score d'interaction (1.0=like, 2.0=comment, 0.5=view)
	CreatedAt       time.Time       `json:"created_at"`
}

// PostMetrics représente les métriques d'un post pour le calcul de popularité
type PostMetrics struct {
	PostID          int64     `json:"post_id"`
	ViewsCount      int64     `json:"views_count"`
	LikesCount      int64     `json:"likes_count"`
	CommentsCount   int64     `json:"comments_count"`
	SharesCount     int64     `json:"shares_count"`
	PopularityScore float64   `json:"popularity_score"`
	TrendingScore   float64   `json:"trending_score"`     // Score de tendance (pic récent d'activité)
	LastUpdated     time.Time `json:"last_updated"`
}

// ✅ UserPreferences simplifié avec map[string]float64
type UserPreferences struct {
	UserID             int64                 `json:"user_id"`
	PreferredTags      map[string]float64    `json:"preferred_tags"`        // ✅ Score par tag (string)
	PreferredCreators  []int64               `json:"preferred_creators"`    // IDs des créateurs préférés
	InteractionHistory []UserInteraction     `json:"interaction_history"`   // Historique des interactions récentes
	LastUpdated        time.Time             `json:"last_updated"`
}

// ✅ TrendingTag simplifié avec string
type TrendingTag struct {
	Category      string  `json:"category"`         // ✅ String au lieu de TagCategory
	PostsCount    int64   `json:"posts_count"`      // Nombre de posts avec ce tag récemment
	GrowthRate    float64 `json:"growth_rate"`      // Taux de croissance sur la période
	TrendingScore float64 `json:"trending_score"`   // Score de tendance calculé
	Period        string  `json:"period"`           // "24h", "week", "month"
}

// ===== CONSTRUCTEURS =====

// ✅ NewPostTag corrigé avec string
func NewPostTag(postID int64, category string) *PostTag {
	return &PostTag{
		PostID:    postID,
		Category:  category,
		CreatedAt: time.Now(),
	}
}

// NewUserInteraction crée une nouvelle interaction utilisateur
func NewUserInteraction(userID int64, interactionType InteractionType, contentType string, contentID int64, contentMeta string, score float64) *UserInteraction {
	return &UserInteraction{
		UserID:          userID,
		InteractionType: interactionType,
		ContentType:     contentType,
		ContentID:       contentID,
		ContentMeta:     contentMeta,
		Score:           score,
		CreatedAt:       time.Now(),
	}
}

// NewPostMetrics crée de nouvelles métriques pour un post
func NewPostMetrics(postID int64) *PostMetrics {
	return &PostMetrics{
		PostID:      postID,
		LastUpdated: time.Now(),
	}
}

// ===== FONCTIONS UTILITAIRES POUR LES TAGS =====

// ✅ GetValidBackendTags retourne la liste des tags valides
func GetValidBackendTags() []string {
	return []string{
		"wellness",
		"beaute",
		"art",
		"musique",
		"cuisine",
		"football",
		"basket",
		"mode",
		"cinema",
		"actualites",
		"mangas",
		"memes",
		"tech",
	}
}

// ✅ IsValidTag vérifie si un tag est valide
func IsValidTag(tag string) bool {
	validTags := map[string]bool{
		"wellness":    true,
		"beaute":      true,
		"art":         true,
		"musique":     true,
		"cuisine":     true,
		"football":    true,
		"basket":      true,
		"mode":        true,
		"cinema":      true,
		"actualites":  true,
		"mangas":      true,
		"memes":       true,
		"tech":        true,
	}
	
	return validTags[tag]
}

// ✅ GetTagDisplayName retourne le nom d'affichage d'un tag
func GetTagDisplayName(tag string) string {
	displayNames := map[string]string{
		"wellness":    "Wellness",
		"beaute":      "Beauté",
		"art":         "Art",
		"musique":     "Musique",
		"cuisine":     "Cuisine",
		"football":    "Football",
		"basket":      "Basketball",
		"mode":        "Mode",
		"cinema":      "Cinéma",
		"actualites":  "Actualités",
		"mangas":      "Mangas",
		"memes":       "Memes",
		"tech":        "Tech",
	}
	
	if displayName, exists := displayNames[tag]; exists {
		return displayName
	}
	return tag
}

// ✅ GetTagEmoji retourne l'emoji associé à un tag
func GetTagEmoji(tag string) string {
	emojis := map[string]string{
		"wellness":    "🧘",
		"beaute":      "💄",
		"art":         "🎨",
		"musique":     "🎵",
		"cuisine":     "🍳",
		"football":    "⚽",
		"basket":      "🏀",
		"mode":        "👗",
		"cinema":      "🎬",
		"actualites":  "📰",
		"mangas":      "📚",
		"memes":       "😂",
		"tech":        "💻",
	}
	
	if emoji, exists := emojis[tag]; exists {
		return emoji
	}
	return "🏷️"
}

// ===== MÉTHODES UTILITAIRES POUR LES MÉTRIQUES =====

// CalculatePopularityScore calcule le score de popularité d'un post
func (pm *PostMetrics) CalculatePopularityScore() {
	// Algorithme de scoring : pondération des différentes interactions
	likeWeight := 1.0
	commentWeight := 2.0
	shareWeight := 3.0
	viewWeight := 0.1
	
	pm.PopularityScore = float64(pm.LikesCount)*likeWeight +
		float64(pm.CommentsCount)*commentWeight +
		float64(pm.SharesCount)*shareWeight +
		float64(pm.ViewsCount)*viewWeight
}

// CalculateTrendingScore calcule le score de tendance basé sur l'activité récente
func (pm *PostMetrics) CalculateTrendingScore(hoursAgo float64) {
	// Score de tendance basé sur la récence des interactions
	timeFactor := 1.0 / (1.0 + hoursAgo/24.0) // Décroissance sur 24h
	pm.TrendingScore = pm.PopularityScore * timeFactor
}

// ===== MÉTHODES UTILITAIRES POUR LES UTILISATEURS =====

// GetDisplayName retourne le nom d'affichage de l'utilisateur
func (usr *UserSearchResult) GetDisplayName() string {
	if usr.FullName != "" {
		return usr.FullName
	}
	if usr.FirstName != "" && usr.LastName != "" {
		return usr.FirstName + " " + usr.LastName
	}
	if usr.FirstName != "" {
		return usr.FirstName
	}
	return usr.Username
}

// ===== FONCTIONS DE VALIDATION =====

// ValidateSearchRequest valide une requête de recherche
func (sr *SearchRequest) Validate() error {
	if sr.UserID <= 0 {
		return fmt.Errorf("user ID is required")
	}
	
	if sr.Limit <= 0 || sr.Limit > 100 {
		sr.Limit = 20 // Valeur par défaut
	}
	
	if sr.Offset < 0 {
		sr.Offset = 0
	}
	
	// Valider les tags
	validTags := []string{}
	for _, tag := range sr.Tags {
		if IsValidTag(tag) {
			validTags = append(validTags, tag)
		}
	}
	sr.Tags = validTags
	
	return nil
}

// ValidateDiscoveryRequest valide une requête de découverte
func (dr *DiscoveryRequest) Validate() error {
	if dr.UserID <= 0 {
		return fmt.Errorf("user ID is required")
	}
	
	if dr.Limit <= 0 || dr.Limit > 100 {
		dr.Limit = 20 // Valeur par défaut
	}
	
	if dr.Offset < 0 {
		dr.Offset = 0
	}
	
	// Valider les tags
	validTags := []string{}
	for _, tag := range dr.Tags {
		if IsValidTag(tag) {
			validTags = append(validTags, tag)
		}
	}
	dr.Tags = validTags
	
	return nil
}