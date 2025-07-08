// internal/domain/search.go

package domain

import "time"

// TagCategory représente les catégories de tags disponibles
type TagCategory string

const (
	TagYoga         TagCategory = "yoga"
	TagWellness     TagCategory = "wellness"
	TagBeaute       TagCategory = "beaute"
	TagDiy          TagCategory = "diy"
	TagArt          TagCategory = "art"
	TagMusique      TagCategory = "musique"
	TagCuisine      TagCategory = "cuisine"
	TagMusculation  TagCategory = "musculation"
	TagMode         TagCategory = "mode"
	TagFitness      TagCategory = "fitness"
	
	// ✅ NOUVEAUX TAGS de votre base de données
	TagFootball     TagCategory = "football"    
	TagBasket       TagCategory = "basket"      
	TagCinema       TagCategory = "cinema"      
	TagActualites   TagCategory = "actualites"   
	TagMangas       TagCategory = "mangas"      
	TagMemes        TagCategory = "memes"      
	TagTech         TagCategory = "tech"
)

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
	Tags            []TagCategory    `json:"tags"`             // Tags associés
	LikesCount      int64            `json:"likes_count"`      // Nombre de likes
	CommentsCount   int64            `json:"comments_count"`   // Nombre de commentaires
	ViewsCount      int64            `json:"views_count"`      // Nombre de vues
	IsLiked         bool             `json:"is_liked"`         // Si l'utilisateur actuel a liké
	PopularityScore float64          `json:"popularity_score"` // Score de popularité calculé
	RelevanceScore  float64          `json:"relevance_score"`  // Score de pertinence pour l'utilisateur
}

// SearchRequest représente une requête de recherche
type SearchRequest struct {
	Query        string        `json:"query"`         // Terme de recherche
	UserID       int64         `json:"user_id"`       // ID de l'utilisateur qui recherche
	Tags         []TagCategory `json:"tags"`          // Filtres par tags
	SortBy       SortType      `json:"sort_by"`       // Type de tri
	Limit        int           `json:"limit"`         // Nombre de résultats max
	Offset       int           `json:"offset"`        // Pagination
	SearchType   string        `json:"search_type"`   // "posts", "users", "discovery"
}

// DiscoveryRequest représente une requête pour le feed de découverte
type DiscoveryRequest struct {
	UserID int64         `json:"user_id"`
	Tags   []TagCategory `json:"tags"`     // Filtres optionnels par tags
	SortBy SortType      `json:"sort_by"`  // Type de tri
	Limit  int           `json:"limit"`
	Offset int           `json:"offset"`
}

// PostTag représente un tag associé à un post
type PostTag struct {
	ID        int64       `json:"id"`
	PostID    int64       `json:"post_id"`
	Category  TagCategory `json:"category"`
	CreatedAt time.Time   `json:"created_at"`
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

// UserPreferences représente les préférences calculées d'un utilisateur
type UserPreferences struct {
	UserID             int64                    `json:"user_id"`
	PreferredTags      map[TagCategory]float64  `json:"preferred_tags"`        // Score par catégorie de tag
	PreferredCreators  []int64                  `json:"preferred_creators"`    // IDs des créateurs préférés
	InteractionHistory []UserInteraction        `json:"interaction_history"`   // Historique des interactions récentes
	LastUpdated        time.Time                `json:"last_updated"`
}

// TrendingTag représente un tag en tendance
type TrendingTag struct {
	Category      TagCategory `json:"category"`
	PostsCount    int64       `json:"posts_count"`      // Nombre de posts avec ce tag récemment
	GrowthRate    float64     `json:"growth_rate"`      // Taux de croissance sur la période
	TrendingScore float64     `json:"trending_score"`   // Score de tendance calculé
	Period        string      `json:"period"`           // "24h", "week", "month"
}

// ===== CONSTRUCTEURS =====

// NewPostTag crée un nouveau tag pour un post
func NewPostTag(postID int64, category TagCategory) *PostTag {
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

// ===== MÉTHODES UTILITAIRES POUR LES TAGS =====


// GetTagDisplayName retourne le nom d'affichage d'un tag
func (tc TagCategory) GetTagDisplayName() string {
	switch tc {
	case TagYoga:
		return "Yoga"
	case TagWellness:
		return "Wellness"
	case TagBeaute:
		return "Beauté"
	case TagDiy:
		return "DIY"
	case TagArt:
		return "Art"
	case TagMusique:
		return "Musique"
	case TagCuisine:
		return "Cuisine"
	case TagMusculation:
		return "Musculation"
	case TagMode:
		return "Mode"
	case TagFitness:
		return "Fitness"
	case TagFootball:
		return "Football"
	case TagBasket:
		return "Basket"
	case TagCinema:
		return "Cinéma"
	case TagActualites:
		return "Actualités"
	case TagMangas:
		return "Mangas"
	case TagMemes:
		return "Memes"
	case TagTech:
		return "Tech"
	default:
		return string(tc)
	}
}

// GetTagEmoji retourne l'emoji associé à un tag
func (tc TagCategory) GetTagEmoji() string {
	switch tc {
	case TagYoga:
		return "🧘"
	case TagWellness:
		return "🌿"
	case TagBeaute:
		return "💄"
	case TagDiy:
		return "🛠️"
	case TagArt:
		return "🎨"
	case TagMusique:
		return "🎵"
	case TagCuisine:
		return "🍽️"
	case TagMusculation:
		return "🏋️"
	case TagMode:
		return "👗"
	case TagFitness:
		return "💪"
	case TagFootball:
		return "⚽"
	case TagBasket:
		return "🏀"
	case TagCinema:
		return "🎬"
	case TagActualites:
		return "📰"
	case TagMangas:
		return "📚"
	case TagMemes:
		return "😂"
	case TagTech:
		return "💻"
	default:
		return "🏷️"
	}
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