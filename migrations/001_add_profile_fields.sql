-- Migration pour ajouter des champs de profil et des fonctionnalités de posts
ALTER TABLE users ADD COLUMN IF NOT EXISTS avatar_url VARCHAR(255);
ALTER TABLE users ADD COLUMN IF NOT EXISTS bio TEXT;
ALTER TABLE users ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP DEFAULT NOW();

-- Mettre à jour les enregistrements existants
UPDATE users SET updated_at = created_at WHERE updated_at IS NULL;

-- Vérifier que les colonnes pour les posts existent
ALTER TABLE posts ADD COLUMN IF NOT EXISTS image_url VARCHAR(255);
ALTER TABLE posts ADD COLUMN IF NOT EXISTS video_url VARCHAR(255);
ALTER TABLE posts ADD COLUMN IF NOT EXISTS visibility VARCHAR(20) DEFAULT 'public';

-- Mettre à jour les posts existants
UPDATE posts SET visibility = 'public' WHERE visibility IS NULL OR visibility = '';

-- Index essentiels pour les performances
CREATE INDEX IF NOT EXISTS idx_posts_user_visibility ON posts(user_id, visibility);
CREATE INDEX IF NOT EXISTS idx_posts_created_at ON posts(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_subscriptions_creator ON subscriptions(creator_id);
CREATE INDEX IF NOT EXISTS idx_likes_post ON likes(post_id);

-- Contraintes de validation
ALTER TABLE posts ADD CONSTRAINT IF NOT EXISTS chk_posts_visibility 
CHECK (visibility IN ('public', 'subscriber', 'draft'));

ALTER TABLE users ADD CONSTRAINT IF NOT EXISTS chk_users_bio_length 
CHECK (char_length(bio) <= 500);

-- Quelques données de test (optionnel)
UPDATE users SET 
    avatar_url = 'https://i.pravatar.cc/150?img=' || (id % 20 + 1),
    bio = CASE 
        WHEN role = 'creator' THEN 'Créateur de contenu passionné ! Suivez-moi pour plus 🎨'
        WHEN role = 'admin' THEN 'Administrateur de la plateforme'
        ELSE 'Utilisateur OnlyFlick'
    END
WHERE avatar_url IS NULL;

-- Vérification que tout s'est bien passé
SELECT 
    'users' as table_name,
    COUNT(*) as total_rows,
    COUNT(avatar_url) as rows_with_avatar,
    COUNT(bio) as rows_with_bio
FROM users
UNION ALL
SELECT 
    'posts' as table_name,
    COUNT(*) as total_rows,
    COUNT(image_url) as rows_with_image,
    COUNT(CASE WHEN visibility = 'public' THEN 1 END) as public_posts
FROM posts;