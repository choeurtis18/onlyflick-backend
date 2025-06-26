package database

import (
	"log"
)

// RunMigrations lance toutes les migrations de la base de données dans l'ordre.
func RunMigrations() {
	log.Println("🚀 [MIGRATIONS] Démarrage des migrations de la base de données...")

	// Migrations existantes
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

	// NOUVELLES MIGRATIONS POUR LE SYSTÈME DE RECHERCHE
	runUsersUpdateMigration()        // Mise à jour table users avec username, avatar_url, bio
	runPostTagsMigration()           // Table des tags pour posts
	runUserInteractionsMigration()   // Table des interactions utilisateur
	runPostMetricsMigration()        // Table des métriques de posts
	runPostMetricsTriggersMigration() // Triggers pour mise à jour automatique

	log.Println("✅ [MIGRATIONS] Toutes les migrations ont été exécutées avec succès.")
	log.Println("🚀 [MIGRATIONS] La base de données est prête à l'emploi avec le système de recherche.")
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

// ===================== NOUVELLES MIGRATIONS POUR LE SYSTÈME DE RECHERCHE =====================

// ===================== MISE À JOUR TABLE USERS =====================

// runUsersUpdateMigration ajoute les colonnes manquantes à la table users
func runUsersUpdateMigration() {
	log.Println("➡️  [users_update] Mise à jour de la table 'users'...")

	query := `
	-- Ajout de la colonne username si elle n'existe pas
	DO $$
	BEGIN
		IF NOT EXISTS (
			SELECT 1 FROM information_schema.columns
			WHERE table_name='users' AND column_name='username'
		) THEN
			ALTER TABLE users ADD COLUMN username VARCHAR(50) UNIQUE;
		END IF;
	END$$;

	-- Ajout de la colonne avatar_url si elle n'existe pas
	DO $$
	BEGIN
		IF NOT EXISTS (
			SELECT 1 FROM information_schema.columns
			WHERE table_name='users' AND column_name='avatar_url'
		) THEN
			ALTER TABLE users ADD COLUMN avatar_url TEXT;
		END IF;
	END$$;

	-- Ajout de la colonne bio si elle n'existe pas
	DO $$
	BEGIN
		IF NOT EXISTS (
			SELECT 1 FROM information_schema.columns
			WHERE table_name='users' AND column_name='bio'
		) THEN
			ALTER TABLE users ADD COLUMN bio TEXT;
		END IF;
	END$$;

	-- Ajout de la colonne updated_at si elle n'existe pas
	DO $$
	BEGIN
		IF NOT EXISTS (
			SELECT 1 FROM information_schema.columns
			WHERE table_name='users' AND column_name='updated_at'
		) THEN
			ALTER TABLE users ADD COLUMN updated_at TIMESTAMPTZ DEFAULT NOW();
		END IF;
	END$$;

	-- Index pour améliorer les performances de recherche d'utilisateurs
	CREATE INDEX IF NOT EXISTS idx_users_username ON users(username);
	CREATE INDEX IF NOT EXISTS idx_users_role ON users(role);
	`

	_, err := DB.Exec(query)
	if err != nil {
		log.Fatalf("❌ [users_update] Échec de la mise à jour de la table 'users' : %v", err)
	}
	log.Println("✅ [users_update] Table 'users' mise à jour avec succès.")
}

// ===================== POST TAGS =====================

// runPostTagsMigration crée la table 'post_tags' si elle n'existe pas.
func runPostTagsMigration() {
	log.Println("➡️  [post_tags] Migration de la table 'post_tags'...")

	query := `
	CREATE TABLE IF NOT EXISTS post_tags (
		id SERIAL PRIMARY KEY,
		post_id BIGINT NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
		category VARCHAR(50) NOT NULL,
		created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
		UNIQUE(post_id, category)
	);

	-- Index pour améliorer les performances de recherche par tag
	CREATE INDEX IF NOT EXISTS idx_post_tags_category ON post_tags(category);
	CREATE INDEX IF NOT EXISTS idx_post_tags_post_id ON post_tags(post_id);
	`

	_, err := DB.Exec(query)
	if err != nil {
		log.Fatalf("❌ [post_tags] Échec de la migration de la table 'post_tags' : %v", err)
	}
	log.Println("✅ [post_tags] Table 'post_tags' migrée avec succès.")
}

// ===================== USER INTERACTIONS =====================

// runUserInteractionsMigration crée la table 'user_interactions' si elle n'existe pas.
func runUserInteractionsMigration() {
	log.Println("➡️  [user_interactions] Migration de la table 'user_interactions'...")

	query := `
	CREATE TABLE IF NOT EXISTS user_interactions (
		id SERIAL PRIMARY KEY,
		user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
		interaction_type VARCHAR(50) NOT NULL,
		content_type VARCHAR(50) NOT NULL,
		content_id BIGINT NOT NULL,
		content_meta TEXT DEFAULT '',
		score DECIMAL(5,2) NOT NULL DEFAULT 0.0,
		created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
	);

	-- Index pour améliorer les performances de recherche d'interactions
	CREATE INDEX IF NOT EXISTS idx_user_interactions_user_id ON user_interactions(user_id);
	CREATE INDEX IF NOT EXISTS idx_user_interactions_type ON user_interactions(interaction_type);
	CREATE INDEX IF NOT EXISTS idx_user_interactions_content ON user_interactions(content_type, content_id);
	CREATE INDEX IF NOT EXISTS idx_user_interactions_created_at ON user_interactions(created_at DESC);
	`

	_, err := DB.Exec(query)
	if err != nil {
		log.Fatalf("❌ [user_interactions] Échec de la migration de la table 'user_interactions' : %v", err)
	}
	log.Println("✅ [user_interactions] Table 'user_interactions' migrée avec succès.")
}

// ===================== POST METRICS =====================

// runPostMetricsMigration crée la table 'post_metrics' si elle n'existe pas.
func runPostMetricsMigration() {
	log.Println("➡️  [post_metrics] Migration de la table 'post_metrics'...")

	query := `
	CREATE TABLE IF NOT EXISTS post_metrics (
		post_id BIGINT PRIMARY KEY REFERENCES posts(id) ON DELETE CASCADE,
		views_count BIGINT NOT NULL DEFAULT 0,
		likes_count BIGINT NOT NULL DEFAULT 0,
		comments_count BIGINT NOT NULL DEFAULT 0,
		shares_count BIGINT NOT NULL DEFAULT 0,
		popularity_score DECIMAL(10,2) NOT NULL DEFAULT 0.0,
		trending_score DECIMAL(10,2) NOT NULL DEFAULT 0.0,
		last_updated TIMESTAMPTZ NOT NULL DEFAULT NOW()
	);

	-- Index pour améliorer les performances de tri par popularité
	CREATE INDEX IF NOT EXISTS idx_post_metrics_popularity ON post_metrics(popularity_score DESC);
	CREATE INDEX IF NOT EXISTS idx_post_metrics_trending ON post_metrics(trending_score DESC);
	CREATE INDEX IF NOT EXISTS idx_post_metrics_updated ON post_metrics(last_updated DESC);
	`

	_, err := DB.Exec(query)
	if err != nil {
		log.Fatalf("❌ [post_metrics] Échec de la migration de la table 'post_metrics' : %v", err)
	}
	log.Println("✅ [post_metrics] Table 'post_metrics' migrée avec succès.")
}

// ===================== TRIGGERS POUR MISE À JOUR AUTOMATIQUE DES MÉTRIQUES =====================

// runPostMetricsTriggersMigration crée les triggers pour mettre à jour automatiquement les métriques
func runPostMetricsTriggersMigration() {
	log.Println("➡️  [post_metrics_triggers] Création des triggers de mise à jour des métriques...")

	query := `
	-- Fonction pour mettre à jour les métriques d'un post
	CREATE OR REPLACE FUNCTION update_post_metrics()
	RETURNS TRIGGER AS $$
	BEGIN
		-- Initialiser ou mettre à jour les métriques du post
		INSERT INTO post_metrics (post_id, last_updated)
		VALUES (
			CASE 
				WHEN TG_TABLE_NAME = 'likes' THEN COALESCE(NEW.post_id, OLD.post_id)
				WHEN TG_TABLE_NAME = 'comments' THEN COALESCE(NEW.post_id, OLD.post_id)
				ELSE NULL
			END,
			NOW()
		)
		ON CONFLICT (post_id) 
		DO UPDATE SET last_updated = NOW();

		-- Recalculer les métriques
		UPDATE post_metrics 
		SET 
			likes_count = (
				SELECT COUNT(*) 
				FROM likes 
				WHERE post_id = CASE 
					WHEN TG_TABLE_NAME = 'likes' THEN COALESCE(NEW.post_id, OLD.post_id)
					WHEN TG_TABLE_NAME = 'comments' THEN COALESCE(NEW.post_id, OLD.post_id)
					ELSE NULL
				END
			),
			comments_count = (
				SELECT COUNT(*) 
				FROM comments 
				WHERE post_id = CASE 
					WHEN TG_TABLE_NAME = 'likes' THEN COALESCE(NEW.post_id, OLD.post_id)
					WHEN TG_TABLE_NAME = 'comments' THEN COALESCE(NEW.post_id, OLD.post_id)
					ELSE NULL
				END
			),
			views_count = (
				SELECT COUNT(*) 
				FROM user_interactions 
				WHERE content_type = 'post' 
				AND content_id = CASE 
					WHEN TG_TABLE_NAME = 'likes' THEN COALESCE(NEW.post_id, OLD.post_id)
					WHEN TG_TABLE_NAME = 'comments' THEN COALESCE(NEW.post_id, OLD.post_id)
					ELSE NULL
				END
				AND interaction_type = 'view'
			)
		WHERE post_id = CASE 
			WHEN TG_TABLE_NAME = 'likes' THEN COALESCE(NEW.post_id, OLD.post_id)
			WHEN TG_TABLE_NAME = 'comments' THEN COALESCE(NEW.post_id, OLD.post_id)
			ELSE NULL
		END;

		-- Recalculer le score de popularité
		UPDATE post_metrics 
		SET popularity_score = (likes_count * 1.0 + comments_count * 2.0 + views_count * 0.1)
		WHERE post_id = CASE 
			WHEN TG_TABLE_NAME = 'likes' THEN COALESCE(NEW.post_id, OLD.post_id)
			WHEN TG_TABLE_NAME = 'comments' THEN COALESCE(NEW.post_id, OLD.post_id)
			ELSE NULL
		END;

		RETURN COALESCE(NEW, OLD);
	END;
	$$ LANGUAGE plpgsql;

	-- Trigger sur les likes
	DROP TRIGGER IF EXISTS trigger_update_post_metrics_likes ON likes;
	CREATE TRIGGER trigger_update_post_metrics_likes
		AFTER INSERT OR DELETE ON likes
		FOR EACH ROW EXECUTE FUNCTION update_post_metrics();

	-- Trigger sur les commentaires
	DROP TRIGGER IF EXISTS trigger_update_post_metrics_comments ON comments;
	CREATE TRIGGER trigger_update_post_metrics_comments
		AFTER INSERT OR DELETE ON comments
		FOR EACH ROW EXECUTE FUNCTION update_post_metrics();

	-- Trigger pour initialiser les métriques lors de la création d'un post
	CREATE OR REPLACE FUNCTION init_post_metrics()
	RETURNS TRIGGER AS $$
	BEGIN
		INSERT INTO post_metrics (post_id, last_updated)
		VALUES (NEW.id, NOW());
		RETURN NEW;
	END;
	$$ LANGUAGE plpgsql;

	DROP TRIGGER IF EXISTS trigger_init_post_metrics ON posts;
	CREATE TRIGGER trigger_init_post_metrics
		AFTER INSERT ON posts
		FOR EACH ROW EXECUTE FUNCTION init_post_metrics();
	`

	_, err := DB.Exec(query)
	if err != nil {
		log.Fatalf("❌ [post_metrics_triggers] Échec de la création des triggers : %v", err)
	}
	log.Println("✅ [post_metrics_triggers] Triggers de mise à jour des métriques créés avec succès.")
}