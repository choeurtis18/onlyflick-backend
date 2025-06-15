package domain

// Structure pour les statistiques créateurs
type CreatorStats struct {
	ID               int64  `json:"id"`
	FirstName        string `json:"first_name"`
	LastName         string `json:"last_name"`
	SubscribersCount int64  `json:"subscribers_count"`
	PostsCount       int64  `json:"posts_count"`
	LikesCount       int64  `json:"likes_count"`
}

// Structure pour les détails d'un créateur
type CreatorDetails struct {
	ID          int64  `json:"id"`
	FirstName   string `json:"first_name"`
	LastName    string `json:"last_name"`
	Email       string `json:"email"`
	Subscribers []User `json:"subscribers"`
	Posts       []Post `json:"posts"`
	TotalLikes  int64  `json:"total_likes"`
}

// Structure pour les statistiques globales
type GlobalStats struct {
	TotalUsers   int64 `json:"total_users"`
	TotalPosts   int64 `json:"total_posts"`
	TotalReports int64 `json:"total_reports"`
	TotalRevenue int64 `json:"total_revenue"`
}
