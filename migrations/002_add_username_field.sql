-- Ajouter la colonne username
ALTER TABLE users ADD COLUMN IF NOT EXISTS username VARCHAR(50);

-- Créer des usernames uniques pour les utilisateurs existants
-- Format: firstname_lastname_id (en minuscules, sans espaces)
UPDATE users SET username = LOWER(
    REGEXP_REPLACE(
        CONCAT(
            REGEXP_REPLACE(first_name, '[^a-zA-Z0-9]', '', 'g'),
            '_',
            REGEXP_REPLACE(last_name, '[^a-zA-Z0-9]', '', 'g'),
            '_',
            id::text
        ),
        '[^a-zA-Z0-9_]', '', 'g'
    )
)
WHERE username IS NULL;

-- Alternative plus simple si la requête ci-dessus pose problème
-- UPDATE users SET username = 'user_' || id WHERE username IS NULL;

-- Ajouter la contrainte UNIQUE après avoir rempli les valeurs
ALTER TABLE users ADD CONSTRAINT IF NOT EXISTS uk_users_username UNIQUE (username);

-- Index pour les recherches par username (performance)
CREATE INDEX IF NOT EXISTS idx_users_username ON users(username);

-- Contraintes de validation pour le username
ALTER TABLE users ADD CONSTRAINT IF NOT EXISTS chk_username_format 
CHECK (
    username ~ '^[a-zA-Z0-9_]{3,50}$' AND  -- Alphanumeric + underscore, 3-50 chars
    username NOT LIKE '\_%' AND           -- Ne commence pas par underscore
    username NOT LIKE '%\_' AND           -- Ne finit pas par underscore
    username NOT LIKE '%\_\_%'            -- Pas de double underscore
);

-- Rendre la colonne NOT NULL maintenant qu'elle est remplie
ALTER TABLE users ALTER COLUMN username SET NOT NULL;

-- Fonction pour générer un username unique (utile pour les nouveaux utilisateurs)
CREATE OR REPLACE FUNCTION generate_unique_username(base_username TEXT)
RETURNS TEXT AS $$
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
$$ LANGUAGE plpgsql;

-- Trigger pour générer automatiquement un username lors de l'insertion
CREATE OR REPLACE FUNCTION auto_generate_username()
RETURNS TRIGGER AS $$
BEGIN
    -- Si pas de username fourni, en générer un
    IF NEW.username IS NULL OR NEW.username = '' THEN
        NEW.username := generate_unique_username(NEW.first_name || '_' || NEW.last_name);
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Appliquer le trigger
DROP TRIGGER IF EXISTS trigger_auto_username ON users;
CREATE TRIGGER trigger_auto_username
    BEFORE INSERT ON users
    FOR EACH ROW
    EXECUTE FUNCTION auto_generate_username();

-- Quelques exemples de mise à jour pour rendre les usernames plus lisibles
-- (Optionnel - seulement si vous voulez des usernames plus propres)
UPDATE users SET username = 'admin_' || id WHERE role = 'admin' AND username LIKE '%admin%';
UPDATE users SET username = 'creator_' || id WHERE role = 'creator' AND username NOT LIKE 'admin%';

-- Vérification finale
SELECT 
    'Username Statistics' as info,
    COUNT(*) as total_users,
    COUNT(DISTINCT username) as unique_usernames,
    COUNT(*) - COUNT(DISTINCT username) as duplicates,
    MIN(LENGTH(username)) as min_length,
    MAX(LENGTH(username)) as max_length
FROM users;

-- Afficher quelques exemples
SELECT 
    id, 
    first_name, 
    last_name, 
    username, 
    role 
FROM users 
ORDER BY id 
LIMIT 10;