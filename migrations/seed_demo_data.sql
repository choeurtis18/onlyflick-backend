-- Création de 50 utilisateurs
DO $$
BEGIN
  FOR i IN 1..50 LOOP
    INSERT INTO users (first_name, last_name, email, password, role, created_at, username)
    VALUES (
      'User'||i,
      'Test',
      'user'||i||'@demo.com',
      'demo_pass',
      CASE WHEN i <= 20 THEN 'creator' ELSE 'subscriber' END,
      NOW(),
      'user'||i
    );
  END LOOP;
END $$;

-- Création de 100 posts pour les créateurs
DO $$
DECLARE
  creator_id BIGINT;
BEGIN
  FOR i IN 1..100 LOOP
    SELECT id INTO creator_id FROM users WHERE role = 'creator' ORDER BY RANDOM() LIMIT 1;
    INSERT INTO posts (user_id, title, description, media_url, visibility, created_at, updated_at)
    VALUES (
      creator_id,
      'Post '||i,
      'Description du post '||i,
      'https://picsum.photos/200?image='||(i+10),
      'public',
      NOW() - (i || ' days')::interval,
      NOW() - (i || ' days')::interval
    );
  END LOOP;
END $$;

-- Attribution de tags aléatoires
DO $$
DECLARE
  post_id BIGINT;
  tag TEXT;
  tags TEXT[] := ARRAY['sport', 'art', 'food', 'tech', 'fashion'];
BEGIN
  FOR post_id IN SELECT id FROM posts LOOP
    FOR i IN 1..2 LOOP
      tag := tags[1 + floor(random() * array_length(tags, 1))];
      INSERT INTO post_tags (post_id, category) VALUES (post_id, tag) ON CONFLICT DO NOTHING;
    END LOOP;
  END LOOP;
END $$;

-- Création de likes aléatoires
DO $$
DECLARE
  sub_id BIGINT;
  post_id BIGINT;
BEGIN
  FOR sub_id IN SELECT id FROM users WHERE role = 'subscriber' LOOP
    FOR i IN 1..5 LOOP
      SELECT id INTO post_id FROM posts ORDER BY RANDOM() LIMIT 1;
      INSERT INTO likes (user_id, post_id) VALUES (sub_id, post_id) ON CONFLICT DO NOTHING;
    END LOOP;
  END LOOP;
END $$;

-- Création de vues (interactions)
DO $$
DECLARE
  sub_id BIGINT;
  post_id BIGINT;
BEGIN
  FOR sub_id IN SELECT id FROM users WHERE role = 'subscriber' LOOP
    FOR i IN 1..8 LOOP
      SELECT id INTO post_id FROM posts ORDER BY RANDOM() LIMIT 1;
      INSERT INTO user_interactions (user_id, interaction_type, content_type, content_id, score)
      VALUES (sub_id, 'view', 'post', post_id, 0.1);
    END LOOP;
  END LOOP;
END $$;
