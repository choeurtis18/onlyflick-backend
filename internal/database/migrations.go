package database

import (
	"log"
)

// RunMigrations lance toutes les migrations de la base de données dans l'ordre.
func RunMigrations() {
	log.Println("🚀 [MIGRATIONS] Démarrage des migrations de la base de données...")

	runUsersMigration()
	runCreatorRequestMigration()
	runPostsMigration()
	runSubscriptionsMigration()
	runCommentsMigration()
	runLikesMigration()
	runReportsMigration()
	runConversationsMigration()
	runMessagesMigration()
	runPaymentsMigration()

	log.Println("✅ [MIGRATIONS] Toutes les migrations ont été exécutées avec succès.")
	log.Println("🚀 [MIGRATIONS] La base de données est prête à l'emploi.")
}

// ===================== USERS =====================

// runUsersMigration crée la table 'users' si elle n'existe pas.
func runUsersMigration() {
	log.Println("➡️  [users] Migration de la table 'users'...")

	query := `
	CREATE TABLE IF NOT EXISTS users (
		id SERIAL PRIMARY KEY,
		first_name TEXT NOT NULL,
		last_name TEXT NOT NULL,
		email TEXT NOT NULL UNIQUE,
		password TEXT NOT NULL,
		role VARCHAR(20) NOT NULL DEFAULT 'subscriber',
		created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
	);
	`

	_, err := DB.Exec(query)
	if err != nil {
		log.Fatalf("❌ [users] Échec de la migration de la table 'users' : %v", err)
	}
	log.Println("✅ [users] Table 'users' migrée avec succès.")
}

// ===================== CREATOR REQUESTS =====================

// runCreatorRequestMigration crée la table 'creator_requests' si elle n'existe pas.
func runCreatorRequestMigration() {
	log.Println("➡️  [creator_requests] Migration de la table 'creator_requests'...")

	query := `
	CREATE TABLE IF NOT EXISTS creator_requests (
		id SERIAL PRIMARY KEY,
		user_id BIGINT NOT NULL UNIQUE REFERENCES users(id) ON DELETE CASCADE,
		status VARCHAR(20) NOT NULL DEFAULT 'pending',
		created_at TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP,
		updated_at TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP
	);
	`

	_, err := DB.Exec(query)
	if err != nil {
		log.Fatalf("❌ [creator_requests] Échec de la migration de la table 'creator_requests' : %v", err)
	}
	log.Println("✅ [creator_requests] Table 'creator_requests' migrée avec succès.")
}

// ===================== POSTS =====================

// runPostsMigration crée la table 'posts' si elle n'existe pas.
func runPostsMigration() {
	log.Println("➡️  [posts] Migration de la table 'posts'...")

	query := `
	CREATE TABLE IF NOT EXISTS posts (
		id SERIAL PRIMARY KEY,
		user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
		title TEXT NOT NULL,
		description TEXT,
		media_url TEXT NOT NULL,
		file_id TEXT DEFAULT NULL,
		visibility VARCHAR(20) NOT NULL DEFAULT 'public',
		created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
		updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
	);

	-- Ajout de la colonne file_id si elle n'existe pas (idempotent)
	DO $$
	BEGIN
		IF NOT EXISTS (
			SELECT 1 FROM information_schema.columns
			WHERE table_name='posts' AND column_name='file_id'
		) THEN
			ALTER TABLE posts ADD COLUMN file_id TEXT DEFAULT NULL;
		END IF;
	END$$;
	`

	_, err := DB.Exec(query)
	if err != nil {
		log.Fatalf("❌ [posts] Échec de la migration de la table 'posts' : %v", err)
	}
	log.Println("✅ [posts] Table 'posts' migrée avec succès.")
}

// runSubscriptionsMigration crée la table 'subscriptions' si elle n'existe pas.
func runSubscriptionsMigration() {
	log.Println("➡️  [subscriptions] Migration de la table 'subscriptions'...")

	query := `
	CREATE TABLE IF NOT EXISTS subscriptions (
		id SERIAL PRIMARY KEY,
		subscriber_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
		creator_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
		created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
		end_at TIMESTAMPTZ NOT NULL DEFAULT NOW() + INTERVAL '1 month',
		status BOOLEAN NOT NULL DEFAULT TRUE,
		UNIQUE(subscriber_id, creator_id)
	);`

	_, err := DB.Exec(query)
	if err != nil {
		log.Fatalf("❌ [subscriptions] Échec de la migration de la table 'subscriptions' : %v", err)
	}
	log.Println("✅ [subscriptions] Table 'subscriptions' migrée avec succès.")
}

// ===================== COMMENTS =====================

// runCommentsMigration crée la table 'comments' si elle n'existe pas.
func runCommentsMigration() {
	log.Println("➡️  [comments] Migration de la table 'comments'...")

	query := `
	CREATE TABLE IF NOT EXISTS comments (
		id SERIAL PRIMARY KEY,
		user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
		post_id BIGINT NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
		content TEXT NOT NULL,
		created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
		updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
	);
	`

	_, err := DB.Exec(query)
	if err != nil {
		log.Fatalf("❌ [comments] Échec de la migration de la table 'comments' : %v", err)
	}
	log.Println("✅ [comments] Table 'comments' migrée avec succès.")
}

// ===================== LIKES =====================

// runLikesMigration crée la table 'likes' si elle n'existe pas.
func runLikesMigration() {
	log.Println("➡️  [likes] Migration de la table 'likes'...")

	query := `
	CREATE TABLE IF NOT EXISTS likes (
		user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
		post_id BIGINT NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
		created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
		PRIMARY KEY (user_id, post_id)
	);
	`

	_, err := DB.Exec(query)
	if err != nil {
		log.Fatalf("❌ [likes] Échec de la migration de la table 'likes' : %v", err)
	}
	log.Println("✅ [likes] Table 'likes' migrée avec succès.")
}

// ===================== REPORTS =====================

// runReportsMigration crée la table 'reports' si elle n'existe pas.
func runReportsMigration() {
	log.Println("➡️  [reports] Migration de la table 'reports'...")

	query := `
	CREATE TABLE IF NOT EXISTS reports (
		id SERIAL PRIMARY KEY,
		user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
		content_type VARCHAR(20) NOT NULL,
		content_id BIGINT NOT NULL,
		reason TEXT NOT NULL,
		status VARCHAR(20) NOT NULL DEFAULT 'pending',
		created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
		updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
	);
	`

	_, err := DB.Exec(query)
	if err != nil {
		log.Fatalf("❌ [reports] Échec de la migration de la table 'reports' : %v", err)
	}
	log.Println("✅ [reports] Table 'reports' migrée avec succès.")
}

//
// ===================== CONVERSATIONS =====================

// runConversationsMigration crée la table 'conversations' si elle n'existe pas.
func runConversationsMigration() {
	log.Println("➡️  [conversations] Migration de la table 'conversations'...")

	query := `
	CREATE TABLE IF NOT EXISTS conversations (
		id SERIAL PRIMARY KEY,
		creator_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
		subscriber_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
		created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
		UNIQUE(creator_id, subscriber_id)
	);`

	if _, err := DB.Exec(query); err != nil {
		log.Fatalf("❌ [conversations] Échec de la migration : %v", err)
	}

	log.Println("✅ [conversations] Table 'conversations' migrée avec succès.")
}

//
// ===================== MESSAGES =====================

// runMessagesMigration crée la table 'messages' si elle n'existe pas.
func runMessagesMigration() {
	log.Println("➡️  [messages] Migration de la table 'messages'...")

	query := `
	CREATE TABLE IF NOT EXISTS messages (
		id SERIAL PRIMARY KEY,
		conversation_id BIGINT NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
		sender_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
		content TEXT NOT NULL,
		created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
	);`

	if _, err := DB.Exec(query); err != nil {
		log.Fatalf("❌ [messages] Échec de la migration : %v", err)
	}

	log.Println("✅ [messages] Table 'messages' migrée avec succès.")
}

//
// ===================== PAYMENTS =====================

// runPaymentsMigration crée la table 'payments' si elle n'existe pas.
func runPaymentsMigration() {
	log.Println("➡️  [payments] Migration de la table 'payments'...")

	query := `
	CREATE TABLE IF NOT EXISTS payments (
		id SERIAL PRIMARY KEY,
		subscription_id BIGINT NOT NULL REFERENCES subscriptions(id) ON DELETE CASCADE,
		stripe_payment_id TEXT NOT NULL,
		payer_id TEXT NOT NULL,
		start_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
		end_at TIMESTAMPTZ NOT NULL,
		amount INT NOT NULL,
		status VARCHAR(20) NOT NULL,
		created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
	);
	`

	_, err := DB.Exec(query)
	if err != nil {
		log.Fatalf("❌ [payments] Échec de la migration de la table 'payments' : %v", err)
	}
	log.Println("✅ [payments] Table 'payments' migrée avec succès.")
}
