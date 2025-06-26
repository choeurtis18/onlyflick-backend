--
-- PostgreSQL database dump
--

-- Dumped from database version 17.5
-- Dumped by pg_dump version 17.5 (Homebrew)

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: auto_generate_username(); Type: FUNCTION; Schema: public; Owner: onlyflick_db_owner
--

CREATE FUNCTION public.auto_generate_username() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Si pas de username fourni, en générer un
    IF NEW.username IS NULL OR NEW.username = '' THEN
        NEW.username := generate_unique_username(NEW.first_name || '_' || NEW.last_name);
    END IF;
    
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.auto_generate_username() OWNER TO onlyflick_db_owner;

--
-- Name: clean_for_username(text); Type: FUNCTION; Schema: public; Owner: onlyflick_db_owner
--

CREATE FUNCTION public.clean_for_username(input_text text) RETURNS text
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Remplacer les caractères spéciaux, espaces, accents par des équivalents
    input_text := LOWER(input_text);
    input_text := TRANSLATE(input_text, 'áàäâéèëêíìïîóòöôúùüûçñ', 'aaaaeeeeiiiioooouuuucn');
    input_text := REGEXP_REPLACE(input_text, '[^a-z0-9]', '', 'g');
    
    -- S'assurer qu'il fait au moins 2 caractères
    IF LENGTH(input_text) < 2 THEN
        input_text := 'user';
    END IF;
    
    RETURN input_text;
END;
$$;


ALTER FUNCTION public.clean_for_username(input_text text) OWNER TO onlyflick_db_owner;

--
-- Name: generate_unique_username(text); Type: FUNCTION; Schema: public; Owner: onlyflick_db_owner
--

CREATE FUNCTION public.generate_unique_username(base_username text) RETURNS text
    LANGUAGE plpgsql
    AS $$
DECLARE
    counter INTEGER := 0;
    new_username TEXT;
    username_exists BOOLEAN;
BEGIN
    -- Nettoyer le username de base
    base_username := LOWER(REGEXP_REPLACE(base_username, '[^a-zA-Z0-9_]', '', 'g'));
    
    -- S'assurer qu'il fait au moins 3 caractères
    IF LENGTH(base_username) < 3 THEN
        base_username := 'user_' || base_username;
    END IF;
    
    -- Tronquer à 40 caractères pour laisser de la place pour les chiffres
    base_username := LEFT(base_username, 40);
    
    new_username := base_username;
    
    -- Boucle pour trouver un username unique
    LOOP
        SELECT EXISTS(SELECT 1 FROM users WHERE username = new_username) INTO username_exists;
        
        IF NOT username_exists THEN
            EXIT;
        END IF;
        
        counter := counter + 1;
        new_username := base_username || '_' || counter;
    END LOOP;
    
    RETURN new_username;
END;
$$;


ALTER FUNCTION public.generate_unique_username(base_username text) OWNER TO onlyflick_db_owner;

--
-- Name: init_post_metrics(); Type: FUNCTION; Schema: public; Owner: onlyflick_db_owner
--

CREATE FUNCTION public.init_post_metrics() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
	BEGIN
		INSERT INTO post_metrics (post_id, last_updated)
		VALUES (NEW.id, NOW());
		RETURN NEW;
	END;
	$$;


ALTER FUNCTION public.init_post_metrics() OWNER TO onlyflick_db_owner;

--
-- Name: update_post_metrics(); Type: FUNCTION; Schema: public; Owner: onlyflick_db_owner
--

CREATE FUNCTION public.update_post_metrics() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
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
	$$;


ALTER FUNCTION public.update_post_metrics() OWNER TO onlyflick_db_owner;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: comments; Type: TABLE; Schema: public; Owner: onlyflick_db_owner
--

CREATE TABLE public.comments (
    id integer NOT NULL,
    user_id bigint NOT NULL,
    post_id bigint NOT NULL,
    content text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.comments OWNER TO onlyflick_db_owner;

--
-- Name: comments_id_seq; Type: SEQUENCE; Schema: public; Owner: onlyflick_db_owner
--

CREATE SEQUENCE public.comments_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.comments_id_seq OWNER TO onlyflick_db_owner;

--
-- Name: comments_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: onlyflick_db_owner
--

ALTER SEQUENCE public.comments_id_seq OWNED BY public.comments.id;


--
-- Name: conversations; Type: TABLE; Schema: public; Owner: onlyflick_db_owner
--

CREATE TABLE public.conversations (
    id integer NOT NULL,
    creator_id bigint NOT NULL,
    subscriber_id bigint NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.conversations OWNER TO onlyflick_db_owner;

--
-- Name: conversations_id_seq; Type: SEQUENCE; Schema: public; Owner: onlyflick_db_owner
--

CREATE SEQUENCE public.conversations_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.conversations_id_seq OWNER TO onlyflick_db_owner;

--
-- Name: conversations_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: onlyflick_db_owner
--

ALTER SEQUENCE public.conversations_id_seq OWNED BY public.conversations.id;


--
-- Name: creator_requests; Type: TABLE; Schema: public; Owner: onlyflick_db_owner
--

CREATE TABLE public.creator_requests (
    id integer NOT NULL,
    user_id bigint NOT NULL,
    status character varying(20) DEFAULT 'pending'::character varying NOT NULL,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.creator_requests OWNER TO onlyflick_db_owner;

--
-- Name: creator_requests_id_seq; Type: SEQUENCE; Schema: public; Owner: onlyflick_db_owner
--

CREATE SEQUENCE public.creator_requests_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.creator_requests_id_seq OWNER TO onlyflick_db_owner;

--
-- Name: creator_requests_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: onlyflick_db_owner
--

ALTER SEQUENCE public.creator_requests_id_seq OWNED BY public.creator_requests.id;


--
-- Name: likes; Type: TABLE; Schema: public; Owner: onlyflick_db_owner
--

CREATE TABLE public.likes (
    user_id bigint NOT NULL,
    post_id bigint NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.likes OWNER TO onlyflick_db_owner;

--
-- Name: messages; Type: TABLE; Schema: public; Owner: onlyflick_db_owner
--

CREATE TABLE public.messages (
    id integer NOT NULL,
    conversation_id bigint NOT NULL,
    sender_id bigint NOT NULL,
    content text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.messages OWNER TO onlyflick_db_owner;

--
-- Name: messages_id_seq; Type: SEQUENCE; Schema: public; Owner: onlyflick_db_owner
--

CREATE SEQUENCE public.messages_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.messages_id_seq OWNER TO onlyflick_db_owner;

--
-- Name: messages_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: onlyflick_db_owner
--

ALTER SEQUENCE public.messages_id_seq OWNED BY public.messages.id;


--
-- Name: payments; Type: TABLE; Schema: public; Owner: onlyflick_db_owner
--

CREATE TABLE public.payments (
    id integer NOT NULL,
    subscription_id bigint NOT NULL,
    stripe_payment_id text NOT NULL,
    payer_id text NOT NULL,
    start_at timestamp with time zone DEFAULT now() NOT NULL,
    end_at timestamp with time zone NOT NULL,
    amount integer NOT NULL,
    status character varying(20) NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.payments OWNER TO onlyflick_db_owner;

--
-- Name: payments_id_seq; Type: SEQUENCE; Schema: public; Owner: onlyflick_db_owner
--

CREATE SEQUENCE public.payments_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.payments_id_seq OWNER TO onlyflick_db_owner;

--
-- Name: payments_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: onlyflick_db_owner
--

ALTER SEQUENCE public.payments_id_seq OWNED BY public.payments.id;


--
-- Name: post_metrics; Type: TABLE; Schema: public; Owner: onlyflick_db_owner
--

CREATE TABLE public.post_metrics (
    post_id bigint NOT NULL,
    views_count bigint DEFAULT 0 NOT NULL,
    likes_count bigint DEFAULT 0 NOT NULL,
    comments_count bigint DEFAULT 0 NOT NULL,
    shares_count bigint DEFAULT 0 NOT NULL,
    popularity_score numeric(10,2) DEFAULT 0.0 NOT NULL,
    trending_score numeric(10,2) DEFAULT 0.0 NOT NULL,
    last_updated timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.post_metrics OWNER TO onlyflick_db_owner;

--
-- Name: post_tags; Type: TABLE; Schema: public; Owner: onlyflick_db_owner
--

CREATE TABLE public.post_tags (
    id integer NOT NULL,
    post_id bigint NOT NULL,
    category character varying(50) NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.post_tags OWNER TO onlyflick_db_owner;

--
-- Name: post_tags_id_seq; Type: SEQUENCE; Schema: public; Owner: onlyflick_db_owner
--

CREATE SEQUENCE public.post_tags_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.post_tags_id_seq OWNER TO onlyflick_db_owner;

--
-- Name: post_tags_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: onlyflick_db_owner
--

ALTER SEQUENCE public.post_tags_id_seq OWNED BY public.post_tags.id;


--
-- Name: posts; Type: TABLE; Schema: public; Owner: onlyflick_db_owner
--

CREATE TABLE public.posts (
    id integer NOT NULL,
    user_id bigint NOT NULL,
    title text NOT NULL,
    description text,
    media_url text NOT NULL,
    file_id text,
    visibility character varying(20) DEFAULT 'public'::character varying NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    image_url character varying(255),
    video_url character varying(255)
);


ALTER TABLE public.posts OWNER TO onlyflick_db_owner;

--
-- Name: posts_id_seq; Type: SEQUENCE; Schema: public; Owner: onlyflick_db_owner
--

CREATE SEQUENCE public.posts_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.posts_id_seq OWNER TO onlyflick_db_owner;

--
-- Name: posts_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: onlyflick_db_owner
--

ALTER SEQUENCE public.posts_id_seq OWNED BY public.posts.id;


--
-- Name: reports; Type: TABLE; Schema: public; Owner: onlyflick_db_owner
--

CREATE TABLE public.reports (
    id integer NOT NULL,
    user_id bigint NOT NULL,
    content_type character varying(20) NOT NULL,
    content_id bigint NOT NULL,
    reason text NOT NULL,
    status character varying(20) DEFAULT 'pending'::character varying NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.reports OWNER TO onlyflick_db_owner;

--
-- Name: reports_id_seq; Type: SEQUENCE; Schema: public; Owner: onlyflick_db_owner
--

CREATE SEQUENCE public.reports_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.reports_id_seq OWNER TO onlyflick_db_owner;

--
-- Name: reports_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: onlyflick_db_owner
--

ALTER SEQUENCE public.reports_id_seq OWNED BY public.reports.id;


--
-- Name: subscriptions; Type: TABLE; Schema: public; Owner: onlyflick_db_owner
--

CREATE TABLE public.subscriptions (
    id integer NOT NULL,
    subscriber_id bigint NOT NULL,
    creator_id bigint NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    end_at timestamp with time zone DEFAULT (now() + '1 mon'::interval) NOT NULL,
    status boolean DEFAULT true NOT NULL
);


ALTER TABLE public.subscriptions OWNER TO onlyflick_db_owner;

--
-- Name: subscriptions_id_seq; Type: SEQUENCE; Schema: public; Owner: onlyflick_db_owner
--

CREATE SEQUENCE public.subscriptions_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.subscriptions_id_seq OWNER TO onlyflick_db_owner;

--
-- Name: subscriptions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: onlyflick_db_owner
--

ALTER SEQUENCE public.subscriptions_id_seq OWNED BY public.subscriptions.id;


--
-- Name: user_interactions; Type: TABLE; Schema: public; Owner: onlyflick_db_owner
--

CREATE TABLE public.user_interactions (
    id integer NOT NULL,
    user_id bigint NOT NULL,
    interaction_type character varying(50) NOT NULL,
    content_type character varying(50) NOT NULL,
    content_id bigint NOT NULL,
    content_meta text DEFAULT ''::text,
    score numeric(5,2) DEFAULT 0.0 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.user_interactions OWNER TO onlyflick_db_owner;

--
-- Name: user_interactions_id_seq; Type: SEQUENCE; Schema: public; Owner: onlyflick_db_owner
--

CREATE SEQUENCE public.user_interactions_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.user_interactions_id_seq OWNER TO onlyflick_db_owner;

--
-- Name: user_interactions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: onlyflick_db_owner
--

ALTER SEQUENCE public.user_interactions_id_seq OWNED BY public.user_interactions.id;


--
-- Name: users; Type: TABLE; Schema: public; Owner: onlyflick_db_owner
--

CREATE TABLE public.users (
    id integer NOT NULL,
    first_name text NOT NULL,
    last_name text NOT NULL,
    email text NOT NULL,
    password text NOT NULL,
    role character varying(20) DEFAULT 'subscriber'::character varying NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    avatar_url character varying(255),
    bio text,
    updated_at timestamp without time zone DEFAULT now(),
    username character varying(50) NOT NULL
);


ALTER TABLE public.users OWNER TO onlyflick_db_owner;

--
-- Name: users_id_seq; Type: SEQUENCE; Schema: public; Owner: onlyflick_db_owner
--

CREATE SEQUENCE public.users_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.users_id_seq OWNER TO onlyflick_db_owner;

--
-- Name: users_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: onlyflick_db_owner
--

ALTER SEQUENCE public.users_id_seq OWNED BY public.users.id;


--
-- Name: comments id; Type: DEFAULT; Schema: public; Owner: onlyflick_db_owner
--

ALTER TABLE ONLY public.comments ALTER COLUMN id SET DEFAULT nextval('public.comments_id_seq'::regclass);


--
-- Name: conversations id; Type: DEFAULT; Schema: public; Owner: onlyflick_db_owner
--

ALTER TABLE ONLY public.conversations ALTER COLUMN id SET DEFAULT nextval('public.conversations_id_seq'::regclass);


--
-- Name: creator_requests id; Type: DEFAULT; Schema: public; Owner: onlyflick_db_owner
--

ALTER TABLE ONLY public.creator_requests ALTER COLUMN id SET DEFAULT nextval('public.creator_requests_id_seq'::regclass);


--
-- Name: messages id; Type: DEFAULT; Schema: public; Owner: onlyflick_db_owner
--

ALTER TABLE ONLY public.messages ALTER COLUMN id SET DEFAULT nextval('public.messages_id_seq'::regclass);


--
-- Name: payments id; Type: DEFAULT; Schema: public; Owner: onlyflick_db_owner
--

ALTER TABLE ONLY public.payments ALTER COLUMN id SET DEFAULT nextval('public.payments_id_seq'::regclass);


--
-- Name: post_tags id; Type: DEFAULT; Schema: public; Owner: onlyflick_db_owner
--

ALTER TABLE ONLY public.post_tags ALTER COLUMN id SET DEFAULT nextval('public.post_tags_id_seq'::regclass);


--
-- Name: posts id; Type: DEFAULT; Schema: public; Owner: onlyflick_db_owner
--

ALTER TABLE ONLY public.posts ALTER COLUMN id SET DEFAULT nextval('public.posts_id_seq'::regclass);


--
-- Name: reports id; Type: DEFAULT; Schema: public; Owner: onlyflick_db_owner
--

ALTER TABLE ONLY public.reports ALTER COLUMN id SET DEFAULT nextval('public.reports_id_seq'::regclass);


--
-- Name: subscriptions id; Type: DEFAULT; Schema: public; Owner: onlyflick_db_owner
--

ALTER TABLE ONLY public.subscriptions ALTER COLUMN id SET DEFAULT nextval('public.subscriptions_id_seq'::regclass);


--
-- Name: user_interactions id; Type: DEFAULT; Schema: public; Owner: onlyflick_db_owner
--

ALTER TABLE ONLY public.user_interactions ALTER COLUMN id SET DEFAULT nextval('public.user_interactions_id_seq'::regclass);


--
-- Name: users id; Type: DEFAULT; Schema: public; Owner: onlyflick_db_owner
--

ALTER TABLE ONLY public.users ALTER COLUMN id SET DEFAULT nextval('public.users_id_seq'::regclass);


--
-- Name: comments comments_pkey; Type: CONSTRAINT; Schema: public; Owner: onlyflick_db_owner
--

ALTER TABLE ONLY public.comments
    ADD CONSTRAINT comments_pkey PRIMARY KEY (id);


--
-- Name: conversations conversations_creator_id_subscriber_id_key; Type: CONSTRAINT; Schema: public; Owner: onlyflick_db_owner
--

ALTER TABLE ONLY public.conversations
    ADD CONSTRAINT conversations_creator_id_subscriber_id_key UNIQUE (creator_id, subscriber_id);


--
-- Name: conversations conversations_pkey; Type: CONSTRAINT; Schema: public; Owner: onlyflick_db_owner
--

ALTER TABLE ONLY public.conversations
    ADD CONSTRAINT conversations_pkey PRIMARY KEY (id);


--
-- Name: creator_requests creator_requests_pkey; Type: CONSTRAINT; Schema: public; Owner: onlyflick_db_owner
--

ALTER TABLE ONLY public.creator_requests
    ADD CONSTRAINT creator_requests_pkey PRIMARY KEY (id);


--
-- Name: creator_requests creator_requests_user_id_key; Type: CONSTRAINT; Schema: public; Owner: onlyflick_db_owner
--

ALTER TABLE ONLY public.creator_requests
    ADD CONSTRAINT creator_requests_user_id_key UNIQUE (user_id);


--
-- Name: likes likes_pkey; Type: CONSTRAINT; Schema: public; Owner: onlyflick_db_owner
--

ALTER TABLE ONLY public.likes
    ADD CONSTRAINT likes_pkey PRIMARY KEY (user_id, post_id);


--
-- Name: messages messages_pkey; Type: CONSTRAINT; Schema: public; Owner: onlyflick_db_owner
--

ALTER TABLE ONLY public.messages
    ADD CONSTRAINT messages_pkey PRIMARY KEY (id);


--
-- Name: payments payments_pkey; Type: CONSTRAINT; Schema: public; Owner: onlyflick_db_owner
--

ALTER TABLE ONLY public.payments
    ADD CONSTRAINT payments_pkey PRIMARY KEY (id);


--
-- Name: post_metrics post_metrics_pkey; Type: CONSTRAINT; Schema: public; Owner: onlyflick_db_owner
--

ALTER TABLE ONLY public.post_metrics
    ADD CONSTRAINT post_metrics_pkey PRIMARY KEY (post_id);


--
-- Name: post_tags post_tags_pkey; Type: CONSTRAINT; Schema: public; Owner: onlyflick_db_owner
--

ALTER TABLE ONLY public.post_tags
    ADD CONSTRAINT post_tags_pkey PRIMARY KEY (id);


--
-- Name: post_tags post_tags_post_id_category_key; Type: CONSTRAINT; Schema: public; Owner: onlyflick_db_owner
--

ALTER TABLE ONLY public.post_tags
    ADD CONSTRAINT post_tags_post_id_category_key UNIQUE (post_id, category);


--
-- Name: posts posts_pkey; Type: CONSTRAINT; Schema: public; Owner: onlyflick_db_owner
--

ALTER TABLE ONLY public.posts
    ADD CONSTRAINT posts_pkey PRIMARY KEY (id);


--
-- Name: reports reports_pkey; Type: CONSTRAINT; Schema: public; Owner: onlyflick_db_owner
--

ALTER TABLE ONLY public.reports
    ADD CONSTRAINT reports_pkey PRIMARY KEY (id);


--
-- Name: subscriptions subscriptions_pkey; Type: CONSTRAINT; Schema: public; Owner: onlyflick_db_owner
--

ALTER TABLE ONLY public.subscriptions
    ADD CONSTRAINT subscriptions_pkey PRIMARY KEY (id);


--
-- Name: subscriptions subscriptions_subscriber_id_creator_id_key; Type: CONSTRAINT; Schema: public; Owner: onlyflick_db_owner
--

ALTER TABLE ONLY public.subscriptions
    ADD CONSTRAINT subscriptions_subscriber_id_creator_id_key UNIQUE (subscriber_id, creator_id);


--
-- Name: user_interactions user_interactions_pkey; Type: CONSTRAINT; Schema: public; Owner: onlyflick_db_owner
--

ALTER TABLE ONLY public.user_interactions
    ADD CONSTRAINT user_interactions_pkey PRIMARY KEY (id);


--
-- Name: users users_email_key; Type: CONSTRAINT; Schema: public; Owner: onlyflick_db_owner
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_email_key UNIQUE (email);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: onlyflick_db_owner
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: idx_likes_post; Type: INDEX; Schema: public; Owner: onlyflick_db_owner
--

CREATE INDEX idx_likes_post ON public.likes USING btree (post_id);


--
-- Name: idx_post_metrics_popularity; Type: INDEX; Schema: public; Owner: onlyflick_db_owner
--

CREATE INDEX idx_post_metrics_popularity ON public.post_metrics USING btree (popularity_score DESC);


--
-- Name: idx_post_metrics_trending; Type: INDEX; Schema: public; Owner: onlyflick_db_owner
--

CREATE INDEX idx_post_metrics_trending ON public.post_metrics USING btree (trending_score DESC);


--
-- Name: idx_post_metrics_updated; Type: INDEX; Schema: public; Owner: onlyflick_db_owner
--

CREATE INDEX idx_post_metrics_updated ON public.post_metrics USING btree (last_updated DESC);


--
-- Name: idx_post_tags_category; Type: INDEX; Schema: public; Owner: onlyflick_db_owner
--

CREATE INDEX idx_post_tags_category ON public.post_tags USING btree (category);


--
-- Name: idx_post_tags_post_id; Type: INDEX; Schema: public; Owner: onlyflick_db_owner
--

CREATE INDEX idx_post_tags_post_id ON public.post_tags USING btree (post_id);


--
-- Name: idx_posts_created_at; Type: INDEX; Schema: public; Owner: onlyflick_db_owner
--

CREATE INDEX idx_posts_created_at ON public.posts USING btree (created_at DESC);


--
-- Name: idx_posts_user_visibility; Type: INDEX; Schema: public; Owner: onlyflick_db_owner
--

CREATE INDEX idx_posts_user_visibility ON public.posts USING btree (user_id, visibility);


--
-- Name: idx_subscriptions_creator; Type: INDEX; Schema: public; Owner: onlyflick_db_owner
--

CREATE INDEX idx_subscriptions_creator ON public.subscriptions USING btree (creator_id);


--
-- Name: idx_user_interactions_content; Type: INDEX; Schema: public; Owner: onlyflick_db_owner
--

CREATE INDEX idx_user_interactions_content ON public.user_interactions USING btree (content_type, content_id);


--
-- Name: idx_user_interactions_created_at; Type: INDEX; Schema: public; Owner: onlyflick_db_owner
--

CREATE INDEX idx_user_interactions_created_at ON public.user_interactions USING btree (created_at DESC);


--
-- Name: idx_user_interactions_type; Type: INDEX; Schema: public; Owner: onlyflick_db_owner
--

CREATE INDEX idx_user_interactions_type ON public.user_interactions USING btree (interaction_type);


--
-- Name: idx_user_interactions_user_id; Type: INDEX; Schema: public; Owner: onlyflick_db_owner
--

CREATE INDEX idx_user_interactions_user_id ON public.user_interactions USING btree (user_id);


--
-- Name: idx_users_role; Type: INDEX; Schema: public; Owner: onlyflick_db_owner
--

CREATE INDEX idx_users_role ON public.users USING btree (role);


--
-- Name: idx_users_username; Type: INDEX; Schema: public; Owner: onlyflick_db_owner
--

CREATE INDEX idx_users_username ON public.users USING btree (username);


--
-- Name: users trigger_auto_username; Type: TRIGGER; Schema: public; Owner: onlyflick_db_owner
--

CREATE TRIGGER trigger_auto_username BEFORE INSERT ON public.users FOR EACH ROW EXECUTE FUNCTION public.auto_generate_username();


--
-- Name: posts trigger_init_post_metrics; Type: TRIGGER; Schema: public; Owner: onlyflick_db_owner
--

CREATE TRIGGER trigger_init_post_metrics AFTER INSERT ON public.posts FOR EACH ROW EXECUTE FUNCTION public.init_post_metrics();


--
-- Name: comments trigger_update_post_metrics_comments; Type: TRIGGER; Schema: public; Owner: onlyflick_db_owner
--

CREATE TRIGGER trigger_update_post_metrics_comments AFTER INSERT OR DELETE ON public.comments FOR EACH ROW EXECUTE FUNCTION public.update_post_metrics();


--
-- Name: likes trigger_update_post_metrics_likes; Type: TRIGGER; Schema: public; Owner: onlyflick_db_owner
--

CREATE TRIGGER trigger_update_post_metrics_likes AFTER INSERT OR DELETE ON public.likes FOR EACH ROW EXECUTE FUNCTION public.update_post_metrics();


--
-- Name: comments comments_post_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: onlyflick_db_owner
--

ALTER TABLE ONLY public.comments
    ADD CONSTRAINT comments_post_id_fkey FOREIGN KEY (post_id) REFERENCES public.posts(id) ON DELETE CASCADE;


--
-- Name: comments comments_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: onlyflick_db_owner
--

ALTER TABLE ONLY public.comments
    ADD CONSTRAINT comments_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: conversations conversations_creator_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: onlyflick_db_owner
--

ALTER TABLE ONLY public.conversations
    ADD CONSTRAINT conversations_creator_id_fkey FOREIGN KEY (creator_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: conversations conversations_subscriber_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: onlyflick_db_owner
--

ALTER TABLE ONLY public.conversations
    ADD CONSTRAINT conversations_subscriber_id_fkey FOREIGN KEY (subscriber_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: creator_requests creator_requests_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: onlyflick_db_owner
--

ALTER TABLE ONLY public.creator_requests
    ADD CONSTRAINT creator_requests_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: likes likes_post_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: onlyflick_db_owner
--

ALTER TABLE ONLY public.likes
    ADD CONSTRAINT likes_post_id_fkey FOREIGN KEY (post_id) REFERENCES public.posts(id) ON DELETE CASCADE;


--
-- Name: likes likes_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: onlyflick_db_owner
--

ALTER TABLE ONLY public.likes
    ADD CONSTRAINT likes_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: messages messages_conversation_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: onlyflick_db_owner
--

ALTER TABLE ONLY public.messages
    ADD CONSTRAINT messages_conversation_id_fkey FOREIGN KEY (conversation_id) REFERENCES public.conversations(id) ON DELETE CASCADE;


--
-- Name: messages messages_sender_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: onlyflick_db_owner
--

ALTER TABLE ONLY public.messages
    ADD CONSTRAINT messages_sender_id_fkey FOREIGN KEY (sender_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: payments payments_subscription_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: onlyflick_db_owner
--

ALTER TABLE ONLY public.payments
    ADD CONSTRAINT payments_subscription_id_fkey FOREIGN KEY (subscription_id) REFERENCES public.subscriptions(id) ON DELETE CASCADE;


--
-- Name: post_metrics post_metrics_post_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: onlyflick_db_owner
--

ALTER TABLE ONLY public.post_metrics
    ADD CONSTRAINT post_metrics_post_id_fkey FOREIGN KEY (post_id) REFERENCES public.posts(id) ON DELETE CASCADE;


--
-- Name: post_tags post_tags_post_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: onlyflick_db_owner
--

ALTER TABLE ONLY public.post_tags
    ADD CONSTRAINT post_tags_post_id_fkey FOREIGN KEY (post_id) REFERENCES public.posts(id) ON DELETE CASCADE;


--
-- Name: posts posts_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: onlyflick_db_owner
--

ALTER TABLE ONLY public.posts
    ADD CONSTRAINT posts_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: reports reports_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: onlyflick_db_owner
--

ALTER TABLE ONLY public.reports
    ADD CONSTRAINT reports_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: subscriptions subscriptions_creator_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: onlyflick_db_owner
--

ALTER TABLE ONLY public.subscriptions
    ADD CONSTRAINT subscriptions_creator_id_fkey FOREIGN KEY (creator_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: subscriptions subscriptions_subscriber_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: onlyflick_db_owner
--

ALTER TABLE ONLY public.subscriptions
    ADD CONSTRAINT subscriptions_subscriber_id_fkey FOREIGN KEY (subscriber_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: user_interactions user_interactions_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: onlyflick_db_owner
--

ALTER TABLE ONLY public.user_interactions
    ADD CONSTRAINT user_interactions_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- PostgreSQL database dump complete
--

