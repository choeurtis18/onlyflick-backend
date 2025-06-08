package api

import (
	"log"
	"net/http"
	"onlyflick/internal/handler"
	"onlyflick/internal/middleware"

	"github.com/go-chi/chi/v5"
)

// SetupRoutes configure et retourne le routeur principal de l'API OnlyFlick.
func SetupRoutes() http.Handler {
	log.Println("Setting up API routes...")

	r := chi.NewRouter()

	// ========================
	// Health Check
	// ========================
	r.Get("/health", func(w http.ResponseWriter, r *http.Request) {
		log.Println("Health check endpoint called")
		w.Write([]byte("✅ OnlyFlick API is running"))
	})

	// ========================
	// Authentification
	// ========================
	r.Post("/register", handler.RegisterHandler)
	r.Post("/login", handler.LoginHandler)

	// ========================
	// Utilisateur connecté (Profile)
	// ========================
	r.Route("/profile", func(profile chi.Router) {
		profile.Use(middleware.JWTMiddleware)

		profile.Get("/", handler.ProfileHandler)
		profile.Patch("/", handler.UpdateProfile)
		profile.Delete("/", handler.DeleteAccount)
		profile.Post("/request-upgrade", handler.RequestCreatorUpgrade)
	})

	// ========================
	// Administration (Admin uniquement)
	// ========================
	r.Route("/admin", func(admin chi.Router) {
		admin.Use(middleware.JWTMiddlewareWithRole("admin"))

		admin.Get("/dashboard", handler.AdminDashboard)
		admin.Get("/creator-requests", handler.ListCreatorRequests)
		admin.Post("/creator-requests/{id}/approve", handler.ApproveCreatorRequest)
		admin.Post("/creator-requests/{id}/reject", handler.RejectCreatorRequest)
		admin.Delete("/users/{id}", handler.DeleteAccountByID)
	})

	// ========================
	// Créateur (Creator uniquement)
	// ========================
	r.Route("/creator", func(creator chi.Router) {
		creator.Use(middleware.JWTMiddlewareWithRole("creator"))

		creator.Post("/posts", handler.CreatePost)
		creator.Get("/posts", handler.ListMyPosts)
	})

	// ========================
	// Posts publics et abonnés
	// ========================
	r.Get("/posts/all", handler.ListAllVisiblePosts)
	r.With(middleware.JWTMiddleware).Get("/posts/from/{creator_id}", handler.ListPostsFromCreator)
	r.With(middleware.JWTMiddleware).Get("/posts/from/{creator_id}/subscriber-only", handler.ListSubscriberOnlyPostsFromCreator)

	// ========================
	// Gestion des posts (Creator/Admin)
	// ========================
	r.Route("/posts", func(p chi.Router) {
		p.Use(middleware.JWTMiddlewareWithRole("creator", "admin"))

		p.Post("/", handler.CreatePost)
		p.Get("/me", handler.ListMyPosts)
		p.Get("/{id}", handler.GetPostByID) // TODO: sécurisation

		p.Patch("/{id}", handler.UpdatePost)
		p.Delete("/{id}", handler.DeletePost)
	})

	// ========================
	// Gestion des médias (Creator/Admin)
	// ========================
	r.Route("/media", func(media chi.Router) {
		media.Use(middleware.JWTMiddlewareWithRole("creator", "admin"))
		media.Post("/upload", handler.UploadMedia)
		media.Delete("/{file_id}", handler.DeleteMedia)
	})

	// ========================
	// Abonnements (Subscriber/Creator/Admin)
	// ========================
	r.Route("/subscriptions", func(s chi.Router) {
		s.Use(middleware.JWTMiddlewareWithRole("subscriber", "creator", "admin"))

		s.Post("/{creator_id}", handler.Subscribe)
		s.Delete("/{creator_id}", handler.UnSubscribe)
		s.Get("/", handler.ListMySubscriptions)
	})

	// ========================
	// Commentaires (utilisateurs connectés)
	// ========================
	r.Route("/comments", func(c chi.Router) {
		c.Use(middleware.JWTMiddleware)
		c.Post("/", handler.CreateComment)
		c.Delete("/{id}", handler.DeleteComment)
		c.Get("/post/{post_id}", handler.GetComments)
	})

	// ========================
	// Likes sur les posts (utilisateurs connectés)
	// ========================
	r.Route("/posts/{id}/likes", func(like chi.Router) {
		like.Use(middleware.JWTMiddleware)
		like.Post("/", handler.LikePost)
		like.Get("/", handler.GetPostLikes)
	})

	// ========================
	// Signalements (Reports)
	// ========================
	r.Route("/reports", func(rep chi.Router) {
		// Création de signalement (utilisateur connecté)
		rep.With(middleware.JWTMiddleware).Post("/", handler.CreateReport)

		// Gestion des signalements (admin)
		rep.With(middleware.JWTMiddlewareWithRole("admin")).Get("/", handler.ListReports)
		rep.With(middleware.JWTMiddlewareWithRole("admin")).Get("/pending", handler.ListPendingReports)
		rep.With(middleware.JWTMiddlewareWithRole("admin")).Patch("/{id}", handler.UpdateReportStatus)
		rep.With(middleware.JWTMiddlewareWithRole("admin")).Post("/{id}/action", handler.AdminActOnReport)
	})

	log.Println("API routes setup complete.")
	return r
}
