package api

import (
	"encoding/json"
	"log"
	"net/http"

	"onlyflick/internal/handler"
	"onlyflick/internal/middleware"

	"github.com/go-chi/chi/v5"
)

// SetupRoutes configure et retourne le routeur principal de l'API OnlyFlick.
func SetupRoutes() http.Handler {
	log.Println("Setting up API routes...")

	// Router racine : applique notre CORS simple
	r := chi.NewRouter()
	r.Use(middleware.CorsMiddleware)

	// 2Subrouter : toutes les routes effectives
	sub := chi.NewRouter()

	// --- Health Check ---
	sub.Get("/health", func(w http.ResponseWriter, r *http.Request) {
		log.Println("Health check endpoint called")
		w.Write([]byte("OnlyFlick API is running"))
	})

	// --- Auth ---
	sub.Post("/register", handler.RegisterHandler)      // → 201
	sub.Post("/login", handler.LoginHandler)            // → 200 + { token }
	sub.Get("/auth/check-username", handler.CheckUsernameHandler)

	// --- Profile (auth requis) ---
	sub.Route("/profile", func(profile chi.Router) {
		profile.Use(middleware.JWTMiddleware)

		profile.Get("/", handler.ProfileHandler)
		profile.Put("/", handler.UpdateProfile)     // ajouté : support PUT
		profile.Patch("/", handler.UpdateProfile)   // on garde PATCH aussi
		profile.Delete("/", handler.DeleteAccount)
		profile.Post("/request-upgrade", handler.RequestCreatorUpgrade)

		profile.Get("/stats", handler.GetProfileStats)
		profile.Get("/posts", handler.GetUserPosts)
		profile.Post("/avatar", handler.UploadAvatar)
		profile.Patch("/bio", handler.UpdateBio)
	})

	// --- Admin only ---
	sub.Route("/admin", func(admin chi.Router) {
		admin.Use(middleware.JWTMiddlewareWithRole("admin"))

		admin.Get("/dashboard", handler.AdminDashboard)
		admin.Get("/creator-requests", handler.ListCreatorRequests)
		admin.Post("/creator-requests/{id}/approve", handler.ApproveCreatorRequest)
		admin.Post("/creator-requests/{id}/reject", handler.RejectCreatorRequest)
		admin.Delete("/users/{id}", handler.DeleteAccountByID)
		admin.Get("/creators", handler.ListCreators)
		admin.Get("/creator/{id}", handler.GetCreatorDetails)
	})

	// --- Creator only ---
	sub.Route("/creator", func(cr chi.Router) {
		cr.Use(middleware.JWTMiddlewareWithRole("creator"))
		cr.Post("/posts", handler.CreatePost)
		cr.Get("/posts", handler.ListMyPosts)
	})

	// --- Public & Subscriber posts ---
	sub.Get("/posts/all", handler.ListAllVisiblePosts)
	sub.With(middleware.JWTMiddleware).Get("/posts/recommended", handler.GetRecommendedPosts)
	sub.With(middleware.JWTMiddleware).Get("/posts/from/{creator_id}", handler.ListPostsFromCreator)
	sub.With(middleware.JWTMiddleware).Get("/posts/from/{creator_id}/subscriber-only", handler.ListSubscriberOnlyPostsFromCreator)

	// --- Posts management (creator/admin) ---
	sub.Route("/posts", func(p chi.Router) {
		p.Use(middleware.JWTMiddlewareWithRole("creator", "admin"))
		p.Post("/", handler.CreatePost)
		p.Get("/me", handler.ListMyPosts)
		p.Get("/{id}", handler.GetPostByID)
		p.Patch("/{id}", handler.UpdatePost)
		p.Delete("/{id}", handler.DeletePost)
	})

	// --- Media (creator/admin) ---
	sub.Route("/media", func(m chi.Router) {
		m.Use(middleware.JWTMiddlewareWithRole("creator", "admin"))
		m.Post("/upload", handler.UploadMedia)
		m.Delete("/{file_id}", handler.DeleteMedia)
	})

	// --- Search (auth) ---
	sub.Route("/search", func(s chi.Router) {
		s.Use(middleware.JWTMiddleware)
		s.Get("/users", handler.SearchUsersHandler)
		s.Get("/suggestions", handler.GetSearchSuggestionsHandler)
		s.Get("/stats", handler.GetSearchStatsHandler)
		s.Get("/posts", handler.SearchPostsHandler)
	})

	// --- Tags ---
	sub.Route("/tags", func(tags chi.Router) {
		tags.Get("/available", handler.GetAvailableTagsHandler)
		tags.Get("/stats", handler.GetTagsStatsHandler)
	})

	// --- Public Profiles (auth) ---
	sub.Route("/users", func(u chi.Router) {
		u.Use(middleware.JWTMiddleware)
		u.With(middleware.JWTMiddlewareWithRole("admin")).Get("/all", handler.GetAllUsersHandler)
		u.Get("/{user_id}", handler.GetUserProfileHandler)
		u.Get("/{user_id}/posts", handler.GetUserPostsHandler)
		u.Get("/", handler.SearchUsersHandler)
		u.Get("/{user_id}/followers", handler.GetUserFollowersHandler)
		u.Get("/{user_id}/following", handler.GetUserFollowingHandler)
	})

	// --- Interactions ---
	sub.Route("/interactions", func(it chi.Router) {
		it.Use(middleware.JWTMiddleware)
		it.Post("/track", handler.TrackInteractionHandler)
	})

	// --- Subscriptions ---
	sub.Route("/subscriptions", func(s chi.Router) {
		s.Use(middleware.JWTMiddlewareWithRole("subscriber", "creator", "admin"))
		s.Post("/{creator_id}", handler.Subscribe)
		s.Post("/{creator_id}/payment", handler.SubscribeWithPayment)
		s.Delete("/{creator_id}", handler.UnSubscribe)
		s.Get("/", handler.ListMySubscriptions)
		s.Get("/{creator_id}/status", handler.CheckSubscriptionStatusHandler)
	})

	// --- Comments ---
	sub.Route("/comments", func(c chi.Router) {
		c.Use(middleware.JWTMiddleware)
		c.Post("/", handler.CreateComment)
		c.Delete("/{id}", handler.DeleteComment)
		c.Get("/post/{post_id}", handler.GetComments)
	})

	// --- Likes ---
	sub.Route("/posts/{id}/likes", func(l chi.Router) {
		l.Use(middleware.JWTMiddleware)
		l.Post("/", handler.LikePost)
		l.Get("/", handler.GetPostLikes)
	})

	// --- Reports ---
	sub.Route("/reports", func(rp chi.Router) {
		rp.With(middleware.JWTMiddleware).Post("/", handler.CreateReport)
		rp.With(middleware.JWTMiddlewareWithRole("admin")).Get("/", handler.ListReports)
		rp.With(middleware.JWTMiddlewareWithRole("admin")).Get("/pending", handler.ListPendingReports)
		rp.With(middleware.JWTMiddlewareWithRole("admin")).Patch("/{id}", handler.UpdateReportStatus)
		rp.With(middleware.JWTMiddlewareWithRole("admin")).Post("/{id}/action", handler.AdminActOnReport)
	})

	// --- Conversations & WS ---
	sub.Route("/conversations", func(cs chi.Router) {
		cs.Use(middleware.JWTMiddleware)
		cs.Get("/", handler.GetMyConversations)
		cs.Post("/{receiverId}", handler.StartConversation)
		cs.Get("/{id}/messages", handler.GetMessagesInConversation)
		cs.Post("/{id}/messages", handler.SendMessageInConversation)
	})
	sub.Route("/ws", func(ws chi.Router) {
		ws.Use(middleware.WebSocketJWTMiddleware)
		ws.Get("/messages/{conversation_id}", handler.HandleMessagesWebSocket)
	})

	// --- Root JSON ---
	sub.Get("/", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(map[string]string{
			"message": "OnlyFlick API is running",
			"version": "1.0.0",
			"status":  "active",
		})
	})

	// On monte le même subrouter à la racine ET sous /api
	r.Mount("/", sub)
	r.Mount("/api", sub)

	log.Println("API routes setup complete.")
	return r
}
