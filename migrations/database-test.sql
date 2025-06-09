-- =====================
-- DROP + RESET (optionnel, utile pour développement)
-- =====================
DROP TABLE IF EXISTS messages, conversations, reports, likes, comments, subscriptions, posts, creator_requests, users CASCADE;

-- ===================== USERS =====================
CREATE TABLE users (
	id SERIAL PRIMARY KEY,
	first_name TEXT NOT NULL,
	last_name TEXT NOT NULL,
	email TEXT NOT NULL UNIQUE,
	password TEXT NOT NULL,
	role VARCHAR(20) NOT NULL DEFAULT 'subscriber',
	created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ===================== CREATOR REQUESTS =====================
CREATE TABLE creator_requests (
	id SERIAL PRIMARY KEY,
	user_id BIGINT NOT NULL UNIQUE REFERENCES users(id) ON DELETE CASCADE,
	status VARCHAR(20) NOT NULL DEFAULT 'pending',
	created_at TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP,
	updated_at TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- ===================== POSTS =====================
CREATE TABLE posts (
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

-- ===================== SUBSCRIPTIONS =====================
CREATE TABLE subscriptions (
	id SERIAL PRIMARY KEY,
	subscriber_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
	creator_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
	created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
	UNIQUE(subscriber_id, creator_id)
);

-- ===================== COMMENTS =====================
CREATE TABLE comments (
	id SERIAL PRIMARY KEY,
	user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
	post_id BIGINT NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
	content TEXT NOT NULL,
	created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
	updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ===================== LIKES =====================
CREATE TABLE likes (
	user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
	post_id BIGINT NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
	created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
	PRIMARY KEY (user_id, post_id)
);

-- ===================== REPORTS =====================
CREATE TABLE reports (
	id SERIAL PRIMARY KEY,
	user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
	content_type VARCHAR(20) NOT NULL,
	content_id BIGINT NOT NULL,
	reason TEXT NOT NULL,
	status VARCHAR(20) NOT NULL DEFAULT 'pending',
	created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
	updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ===================== CONVERSATIONS =====================
CREATE TABLE conversations (
	id SERIAL PRIMARY KEY,
	creator_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
	subscriber_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
	created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
	UNIQUE(creator_id, subscriber_id)
);

-- ===================== MESSAGES =====================
CREATE TABLE messages (
	id SERIAL PRIMARY KEY,
	conversation_id BIGINT NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
	sender_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
	content TEXT NOT NULL,
	created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- =====================
-- INSERT FAKE USERS
-- =====================
INSERT INTO users (first_name, last_name, email, password, role) VALUES
('Admin', 'OnlyFlick', 'admin-onlyflick@yopmail.com', '$2a$10$0wZ3KKvVcwg60YEgQHdmT.paephbgils.nz7aXMCbuTzYk6UBqpsS', 'admin'),
('Creator', 'OnlyFlick', 'creator-onlyflick@yopmail.com', '$2a$10$0wZ3KKvVcwg60YEgQHdmT.paephbgils.nz7aXMCbuTzYk6UBqpsS', 'creator'),
('User', 'OnlyFlick', 'user-onlyflick@yopmail.com', '$2a$10$0wZ3KKvVcwg60YEgQHdmT.paephbgils.nz7aXMCbuTzYk6UBqpsS', 'subscriber'),
('Alice', 'OnlyFlick', 'alice-onlyflick@yopmail.com', '$2a$10$0wZ3KKvVcwg60YEgQHdmT.paephbgils.nz7aXMCbuTzYk6UBqpsS', 'subscriber');

-- =====================
-- SUBSCRIPTIONS
-- =====================
INSERT INTO subscriptions (subscriber_id, creator_id) VALUES
(3, 2),
(4, 2);

-- =====================
-- POSTS
-- =====================
INSERT INTO posts (user_id, title, description, media_url) VALUES
(2, 'Premier post', 'Description du post 1', 'https://dummyimage.com/600x400'),
(2, 'Deuxième post', 'Description du post 2', 'https://dummyimage.com/600x400');

-- =====================
-- COMMENTS
-- =====================
INSERT INTO comments (user_id, post_id, content) VALUES
(3, 1, 'Super contenu !'),
(4, 1, 'Merci pour le partage');

-- =====================
-- LIKES
-- =====================
INSERT INTO likes (user_id, post_id) VALUES
(3, 1),
(4, 1);

-- =====================
-- REPORTS
-- =====================
INSERT INTO reports (user_id, content_type, content_id, reason) VALUES
(3, 'post', 1, 'Inapproprié'),
(4, 'comment', 1, 'Spam');

-- =====================
-- CREATOR REQUESTS
-- =====================
INSERT INTO creator_requests (user_id, status) VALUES
(4, 'pending');

-- =====================
-- CONVERSATIONS
-- =====================
INSERT INTO conversations (creator_id, subscriber_id) VALUES
(2, 3),
(2, 4);

-- =====================
-- MESSAGES
-- =====================
INSERT INTO messages (conversation_id, sender_id, content) VALUES
(1, 2, 'Bienvenue sur OnlyFlick!'),
(1, 3, 'Merci, content d’être ici!'),
(2, 4, 'Salut le créateur!'),
(2, 2, 'Bienvenue Alice!');
