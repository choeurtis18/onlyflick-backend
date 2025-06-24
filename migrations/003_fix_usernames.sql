-- Migration pour corriger les usernames des utilisateurs
CREATE OR REPLACE FUNCTION clean_for_username(input_text TEXT)
RETURNS TEXT AS $$
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
$$ LANGUAGE plpgsql;

-- Recréer les usernames au bon format : firstname_lastname_id
UPDATE users SET username = 
    clean_for_username(first_name) || '_' || 
    clean_for_username(last_name) || '_' || 
    id::text;

-- Vérifier qu'il n'y a pas de doublons (normalement impossible avec l'ID à la fin)
WITH duplicate_usernames AS (
    SELECT username, COUNT(*) as count
    FROM users 
    GROUP BY username 
    HAVING COUNT(*) > 1
)
SELECT 
    CASE 
        WHEN EXISTS (SELECT 1 FROM duplicate_usernames) 
        THEN 'ATTENTION: Des doublons existent!'
        ELSE 'OK: Tous les usernames sont uniques'
    END as status;

-- Afficher les nouveaux usernames pour vérification
SELECT 
    id,
    first_name,
    last_name, 
    username,
    role,
    'Longueur: ' || LENGTH(username) as info
FROM users 
ORDER BY id;

-- Statistiques finales
SELECT 
    'Statistiques Usernames' as titre,
    COUNT(*) as total_utilisateurs,
    MIN(LENGTH(username)) as longueur_min,
    MAX(LENGTH(username)) as longueur_max,
    AVG(LENGTH(username))::INTEGER as longueur_moyenne
FROM users;