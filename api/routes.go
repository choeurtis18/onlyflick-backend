package api

import (
	"log"
	"net/http"
	"onlyflick/internal/handler"
	"onlyflick/internal/middleware"

	"encoding/json"

	"github.com/go-chi/chi/v5"
	"github.com/go-chi/cors"
)

// SetupRoutes configure et retourne le routeur principal de l'API OnlyFlick.
func SetupRoutes() http.Handler {
	log.Println("Setting up API routes...")

	r := chi.NewRouter()

	r.Use(cors.Handler(cors.Options{
		AllowedOrigins:   []string{"http://localhost:55273", "http://localhost:3000", "*"},
		AllowedMethods:   []string{"GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"},
		AllowedHeaders:   []string{"Accept", "Authorization", "Content-Type", "X-CSRF-Token"},
		ExposedHeaders:   []string{"Link"},
		AllowCredentials: true,
		MaxAge:           300,
	}))

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
	r.Get("/auth/check-username", handler.CheckUsernameHandler)

	// ========================
	// Utilisateur connecté (Profile)
	// ========================
	r.Route("/profile", func(profile chi.Router) {
		profile.Use(middleware.JWTMiddleware)

		profile.Get("/", handler.ProfileHandler)
		profile.Patch("/", handler.UpdateProfile)
		profile.Delete("/", handler.DeleteAccount)
		profile.Post("/request-upgrade", handler.RequestCreatorUpgrade)

		profile.Get("/stats", handler.GetProfileStats)
		profile.Get("/posts", handler.GetUserPosts)
		profile.Post("/avatar", handler.UploadAvatar)
		profile.Patch("/bio", handler.UpdateBio)
	})

	// ========================
	// Administration (Admin uniquement)
	// ========================
	r.Route("/admin", func(admin chi.Router) {
		admin.Use(middleware.JWTMiddlewareWithRole("admin"))

		// Tableau de bord de l'admin (statistiques globales)
		admin.Get("/dashboard", handler.AdminDashboard)

		// Liste des demandes de créateurs en attente
		admin.Get("/creator-requests", handler.ListCreatorRequests)

		// Approuver ou rejeter une demande de créateur
		admin.Post("/creator-requests/{id}/approve", handler.ApproveCreatorRequest)
		admin.Post("/creator-requests/{id}/reject", handler.RejectCreatorRequest)

		// Supprimer un utilisateur par ID
		admin.Delete("/users/{id}", handler.DeleteAccountByID)

		// Liste des créateurs avec leurs statistiques
		admin.Get("/creators", handler.ListCreators)

		// Détails d'un créateur spécifique
		admin.Get("/creator/{id}", handler.GetCreatorDetails)
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
	r.With(middleware.JWTMiddleware).Get("/posts/recommended", handler.GetRecommendedPosts)
	r.With(middleware.JWTMiddleware).Get("/posts/from/{creator_id}", handler.ListPostsFromCreator)
	r.With(middleware.JWTMiddleware).Get("/posts/from/{creator_id}/subscriber-only", handler.ListSubscriberOnlyPostsFromCreator)

	// ========================
	// Gestion des posts (Creator/Admin)
	// ========================
	r.Route("/posts", func(p chi.Router) {
		p.Use(middleware.JWTMiddlewareWithRole("creator", "admin"))

		p.Post("/", handler.CreatePost)
		p.Get("/me", handler.ListMyPosts)
		p.Get("/{id}", handler.GetPostByID)

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
	// 🔍 RECHERCHE SIMPLIFIÉE (utilisateurs uniquement)
	// ========================
	r.Route("/search", func(search chi.Router) {
		search.Use(middleware.JWTMiddleware)

		// Recherche d'utilisateurs par username
		search.Get("/users", handler.SearchUsersHandler)

		// Suggestions de recherche
		search.Get("/suggestions", handler.GetSearchSuggestionsHandler)

		// Statistiques de recherche
		search.Get("/stats", handler.GetSearchStatsHandler)

		search.Get("/posts", handler.SearchPostsHandler)
	})

	// ========================
	// 🔥 NOUVEAU : Utilisateurs (profils publics)
	// ========================
	r.Route("/users", func(users chi.Router) {
		users.Use(middleware.JWTMiddleware)

		// Liste des utilisateurs (privée, admin uniquement)
		users.With(middleware.JWTMiddlewareWithRole("admin")).Get("/all", handler.GetAllUsersHandler)

		// Obtenir le profil public d'un utilisateur
		users.Get("/{user_id}", handler.GetUserProfileHandler)

		// Obtenir les posts d'un utilisateur spécifique
		users.Get("/{user_id}/posts", handler.GetUserPostsHandler)

		// Recherche alternative d'utilisateurs (si besoin)
		users.Get("/", handler.SearchUsersHandler)
	})

	// ========================
	// 🏷️ TAGS ET CATÉGORIES
	// ========================
	r.Route("/tags", func(tags chi.Router) {
		// Endpoint public pour récupérer tous les tags disponibles
		tags.Get("/available", handler.GetAvailableTagsHandler)

		// Endpoint public pour récupérer les statistiques des tags
		tags.Get("/stats", handler.GetTagsStatsHandler)
	})

	// ========================
	// 📊 TRACKING DES INTERACTIONS
	// ========================
	r.Route("/interactions", func(interactions chi.Router) {
		interactions.Use(middleware.JWTMiddleware)

		// Enregistrer une interaction utilisateur (analytics)
		interactions.Post("/track", handler.TrackInteractionHandler)
	})

	r.Route("/subscriptions", func(s chi.Router) {
		s.Use(middleware.JWTMiddlewareWithRole("subscriber", "creator", "admin"))

		// 🔥 NOUVEAU : S'abonner à un créateur (sans paiement immédiat)
		s.Post("/{creator_id}", handler.Subscribe)

		// Route pour s'abonner à un créateur avec paiement Stripe
		s.Post("/{creator_id}/payment", handler.SubscribeWithPayment)

		// Route pour se désabonner d'un créateur
		s.Delete("/{creator_id}", handler.UnSubscribe)

		// Route pour récupérer la liste des abonnements d'un utilisateur
		s.Get("/", handler.ListMySubscriptions)

		// 🔥 NOUVEAU : Vérifier le statut d'abonnement à un créateur
		s.Get("/{creator_id}/status", handler.CheckSubscriptionStatusHandler)
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

	// ========================
	// Gestion des conversations et messages
	// ========================
	r.Route("/conversations", func(mr chi.Router) {
		mr.Use(middleware.JWTMiddleware)

		mr.Get("/", handler.GetMyConversations)
		mr.Post("/{receiverId}", handler.StartConversation)

		mr.Get("/{id}/messages", handler.GetMessagesInConversation)
		mr.Post("/{id}/messages", handler.SendMessageInConversation)
	})

	// ========================
	// WebSocket pour la messagerie privée
	// ========================
	r.Route("/ws", func(wsRouter chi.Router) {
		wsRouter.Use(middleware.WebSocketJWTMiddleware)
		wsRouter.Get("/messages/{conversation_id}", handler.HandleMessagesWebSocket)
	})

	// Route racine pour éviter 404
	r.Get("/", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(map[string]string{
			"message": "OnlyFlick API is running",
			"version": "1.0.0",
			"status":  "active",
		})
	})

	log.Println("API routes setup complete.")
	return r
}
