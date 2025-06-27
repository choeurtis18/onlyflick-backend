-- seed_populate_db.sql
-- Réinitialisation et insertion de 50 utilisateurs multiculturels

-- Étape 1 : Suppression
DELETE FROM users;

-- Étape 2 : Insertion
INSERT INTO users (first_name, last_name, email, password, role, avatar_url, bio, username) VALUES
('Admin', 'Eemi', 'admin@eemi.com', '$2a$10$0wZ3KKvVcwg60YEgQHdmT.paephbgils.nz7aXMCbuTzYk6UBqpsS', 'admin', 'https://randomuser.me/api/portraits/men/10.jpg', 'Gestionnaire de la plateforme', 'admin_eemi'),
('Camille', 'Dupont', 'camille.dupont@example.com', '$2a$10$0wZ3KKvVcwg60YEgQHdmT.paephbgils.nz7aXMCbuTzYk6UBqpsS', 'subscriber', 'https://randomuser.me/api/portraits/women/10.jpg', 'Amoureuse des chats et du café.', 'sunny_camille'),
('Bastien', 'Martin', 'bastien.martin@example.com', '$2a$10$0wZ3KKvVcwg60YEgQHdmT.paephbgils.nz7aXMCbuTzYk6UBqpsS', 'creator', 'https://randomuser.me/api/portraits/men/11.jpg', 'Créateur de contenu tech.', 'the_real_bast'),
('Eva', 'Leroy', 'eva.leroy@example.com', '$2a$10$0wZ3KKvVcwg60YEgQHdmT.paephbgils.nz7aXMCbuTzYk6UBqpsS', 'subscriber', 'https://randomuser.me/api/portraits/women/12.jpg', 'Rêveuse invétérée.', 'dream_with_eva'),
('Julien', 'Moreau', 'julien.moreau@example.com', '$2a$10$0wZ3KKvVcwg60YEgQHdmT.paephbgils.nz7aXMCbuTzYk6UBqpsS', 'creator', 'https://randomuser.me/api/portraits/men/13.jpg', 'Photographe amateur.', 'xXJulXx'),
('Karine', 'Leclerc', 'karine.leclerc@example.com', '$2a$10$0wZ3KKvVcwg60YEgQHdmT.paephbgils.nz7aXMCbuTzYk6UBqpsS', 'subscriber', 'https://randomuser.me/api/portraits/women/14.jpg', 'Artiste en herbe.', 'artsy_k'),
('Amina', 'Traoré', 'amina.traore@example.com', '$2a$10$0wZ3KKvVcwg60YEgQHdmT.paephbgils.nz7aXMCbuTzYk6UBqpsS', 'subscriber', 'https://randomuser.me/api/portraits/women/15.jpg', 'Passionnée de cuisine traditionnelle.', 'amina_cuisine'),
('Mamadou', 'Soumah', 'mamadou.soumah@example.com', '$2a$10$0wZ3KKvVcwg60YEgQHdmT.paephbgils.nz7aXMCbuTzYk6UBqpsS', 'creator', 'https://randomuser.me/api/portraits/men/16.jpg', 'Conte numérique et culture.', 'mama_storyteller'),
('Fatou', 'Diallo', 'fatou.diallo@example.com', '$2a$10$0wZ3KKvVcwg60YEgQHdmT.paephbgils.nz7aXMCbuTzYk6UBqpsS', 'subscriber', 'https://randomuser.me/api/portraits/women/17.jpg', 'Danseuse et exploratrice.', 'fatou_moves'),
('Youssef', 'Benali', 'youssef.benali@example.com', '$2a$10$0wZ3KKvVcwg60YEgQHdmT.paephbgils.nz7aXMCbuTzYk6UBqpsS', 'creator', 'https://randomuser.me/api/portraits/men/18.jpg', 'Photographie de rue.', 'youss_b_photo'),
('Sara', 'Bouazizi', 'sara.bouazizi@example.com', '$2a$10$0wZ3KKvVcwg60YEgQHdmT.paephbgils.nz7aXMCbuTzYk6UBqpsS', 'subscriber', 'https://randomuser.me/api/portraits/women/19.jpg', 'Amatrice de calligraphie.', 'calligraphy_sara'),
('Ali', 'Hassan', 'ali.hassan@example.com', '$2a$10$0wZ3KKvVcwg60YEgQHdmT.paephbgils.nz7aXMCbuTzYk6UBqpsS', 'subscriber', 'https://randomuser.me/api/portraits/men/20.jpg', 'Passionné de poésie.', 'poet_ali'),
('Noura', 'Al-Farsi', 'noura.alfarsi@example.com', '$2a$10$0wZ3KKvVcwg60YEgQHdmT.paephbgils.nz7aXMCbuTzYk6UBqpsS', 'creator', 'https://randomuser.me/api/portraits/women/21.jpg', 'Food blogger.', 'noura_eats'),
('Minh', 'Nguyen', 'minh.nguyen@example.com', '$2a$10$0wZ3KKvVcwg60YEgQHdmT.paephbgils.nz7aXMCbuTzYk6UBqpsS', 'creator', 'https://randomuser.me/api/portraits/men/22.jpg', 'Voyageur et vloggeur.', 'vlog_minh'),
('Siti', 'Rahma', 'siti.rahma@example.com', '$2a$10$0wZ3KKvVcwg60YEgQHdmT.paephbgils.nz7aXMCbuTzYk6UBqpsS', 'subscriber', 'https://randomuser.me/api/portraits/women/23.jpg', 'Passionnature.', 'siti_nature'),
('Haruto', 'Sato', 'haruto.sato@example.com', '$2a$10$0wZ3KKvVcwg60YEgQHdmT.paephbgils.nz7aXMCbuTzYk6UBqpsS', 'subscriber', 'https://randomuser.me/api/portraits/men/24.jpg', 'Mint tea lover.', 'haru_tea'),
('Yuna', 'Kim', 'yuna.kim@example.com', '$2a$10$0wZ3KKvVcwg60YEgQHdmT.paephbgils.nz7aXMCbuTzYk6UBqpsS', 'creator', 'https://randomuser.me/api/portraits/women/25.jpg', 'Design numérique.', 'yuna_design'),
('Emma', 'Jensen', 'emma.jensen@example.com', '$2a$10$0wZ3KKvVcwg60YEgQHdmT.paephbgils.nz7aXMCbuTzYk6UBqpsS', 'subscriber', 'https://randomuser.me/api/portraits/women/26.jpg', 'Lectrice passionnée.', 'emma_reads'),
('Lars', 'Hansen', 'lars.hansen@example.com', '$2a$10$0wZ3KKvVcwg60YEgQHdmT.paephbgils.nz7aXMCbuTzYk6UBqpsS', 'creator', 'https://randomuser.me/api/portraits/men/27.jpg', 'Cycliste urbain.', 'lars_cycles'),
('Olga', 'Petrova', 'olga.petrova@example.com', '$2a$10$0wZ3KKvVcwg60YEgQHdmT.paephbgils.nz7aXMCbuTzYk6UBqpsS', 'subscriber', 'https://randomuser.me/api/portraits/women/28.jpg', 'Art & tradition.', 'olga_art'),
('Ivan', 'Kovalenko', 'ivan.kovalenko@example.com', '$2a$10$0wZ3KKvVcwg60YEgQHdmT.paephbgils.nz7aXMCbuTzYk6UBqpsS', 'creator', 'https://randomuser.me/api/portraits/men/29.jpg', 'Tech influencer.', 'tech_ivan'),
('Sofia', 'Gonzalez', 'sofia.gonzalez@example.com', '$2a$10$0wZ3KKvVcwg60YEgQHdmT.paephbgils.nz7aXMCbuTzYk6UBqpsS', 'subscriber', 'https://randomuser.me/api/portraits/women/30.jpg', 'Musique & danse.', 'sofia_moves'),
('Carlos', 'Ramirez', 'carlos.ramirez@example.com', '$2a$10$0wZ3KKvVcwg60YEgQHdmT.paephbgils.nz7aXMCbuTzYk6UBqpsS', 'creator', 'https://randomuser.me/api/portraits/men/31.jpg', 'Photographe voyage.', 'carlitos_photo'),
('María', 'Fernández', 'maria.fernandez@example.com', '$2a$10$0wZ3KKvVcwg60YEgQHdmT.paephbgils.nz7aXMCbuTzYk6UBqpsS', 'subscriber', 'https://randomuser.me/api/portraits/women/32.jpg', 'Food & culture.', 'maria_eats'),
('Emily', 'Smith', 'emily.smith@example.com', '$2a$10$0wZ3KKvVcwg60YEgQHdmT.paephbgils.nz7aXMCbuTzYk6UBqpsS', 'subscriber', 'https://randomuser.me/api/portraits/women/33.jpg', 'Fan de randos.', 'emily_trails'),
('Michael', 'Johnson', 'michael.johnson@example.com', '$2a$10$0wZ3KKvVcwg60YEgQHdmT.paephbgils.nz7aXMCbuTzYk6UBqpsS', 'creator', 'https://randomuser.me/api/portraits/men/34.jpg', 'Gamer & streamer.', 'mike_stream'),
('Amadou', 'Ndiaye', 'amadou.ndiaye@example.com', '$2a$10$0wZ3KKvVcwg60YEgQHdmT.paephbgils.nz7aXMCbuTzYk6UBqpsS', 'creator', 'https://randomuser.me/api/portraits/men/35.jpg', 'Musique africaine.', 'amadou_vibes'),
('Aïcha', 'Bamba', 'aicha.bamba@example.com', '$2a$10$0wZ3KKvVcwg60YEgQHdmT.paephbgils.nz7aXMCbuTzYk6UBqpsS', 'subscriber', 'https://randomuser.me/api/portraits/women/36.jpg', 'Blogueuse santé.', 'health_aicha'),
('Luca', 'Ferrari', 'luca.ferrari@example.com', '$2a$10$0wZ3KKvVcwg60YEgQHdmT.paephbgils.nz7aXMCbuTzYk6UBqpsS', 'creator', 'https://randomuser.me/api/portraits/men/37.jpg', 'Automobile & course.', 'luca_race'),
('Helena', 'Nowak', 'helena.nowak@example.com', '$2a$10$0wZ3KKvVcwg60YEgQHdmT.paephbgils.nz7aXMCbuTzYk6UBqpsS', 'subscriber', 'https://randomuser.me/api/portraits/women/38.jpg', 'DIY décor.', 'helena_deco'),
('Oliver', 'Brown', 'oliver.brown@example.com', '$2a$10$0wZ3KKvVcwg60YEgQHdmT.paephbgils.nz7aXMCbuTzYk6UBqpsS', 'subscriber', 'https://randomuser.me/api/portraits/men/39.jpg', 'Fan de foot.', 'foot_oliver'),
('Charlotte', 'Wilson', 'charlotte.wilson@example.com', '$2a$10$0wZ3KKvVcwg60YEgQHdmT.paephbgils.nz7aXMCbuTzYk6UBqpsS', 'creator', 'https://randomuser.me/api/portraits/women/40.jpg', 'Bienvenue au lifestyle.', 'charlotte_life'),
('Chen', 'Wei', 'chen.wei@example.com', '$2a$10$0wZ3KKvVcwg60YEgQHdmT.paephbgils.nz7aXMCbuTzYk6UBqpsS', 'creator', 'https://randomuser.me/api/portraits/men/41.jpg', 'Photographie mobile.', 'chen_mobile'),
('Zahra', 'Ali', 'zahra.ali@example.com', '$2a$10$0wZ3KKvVcwg60YEgQHdmT.paephbgils.nz7aXMCbuTzYk6UBqpsS', 'subscriber', 'https://randomuser.me/api/portraits/women/42.jpg', 'Calligraphie & art.', 'zahra_writes'),
('Diego', 'Martinez', 'diego.martinez@example.com', '$2a$10$0wZ3KKvVcwg60YEgQHdmT.paephbgils.nz7aXMCbuTzYk6UBqpsS', 'creator', 'https://randomuser.me/api/portraits/men/43.jpg', 'Surf & lifestyle.', 'surfer_diego'),
('Priya', 'Patel', 'priya.patel@example.com', '$2a$10$0wZ3KKvVcwg60YEgQHdmT.paephbgils.nz7aXMCbuTzYk6UBqpsS', 'subscriber', 'https://randomuser.me/api/portraits/women/44.jpg', 'Cuisine indienne.', 'priya_cooks'),
('Keiko', 'Tanaka', 'keiko.tanaka@example.com', '$2a$10$0wZ3KKvVcwg60YEgQHdmT.paephbgils.nz7aXMCbuTzYk6UBqpsS', 'creator', 'https://randomuser.me/api/portraits/women/45.jpg', 'Art traditionnel.', 'keiko_trad'),
('Ahmed', 'El-Sayed', 'ahmed.elsayed@example.com', '$2a$10$0wZ3KKvVcwg60YEgQHdmT.paephbgils.nz7aXMCbuTzYk6UBqpsS', 'subscriber', 'https://randomuser.me/api/portraits/men/46.jpg', 'Technologie arabe.', 'tech_ahmed'),
('Natalia', 'Rodriguez', 'natalia.rodriguez@example.com', '$2a$10$0wZ3KKvVcwg60YEgQHdmT.paephbgils.nz7aXMCbuTzYk6UBqpsS', 'creator', 'https://randomuser.me/api/portraits/women/47.jpg', 'Danse folklorique.', 'natalia_dance'),
('Mateo', 'Lopez', 'mateo.lopez@example.com', '$2a$10$0wZ3KKvVcwg60YEgQHdmT.paephbgils.nz7aXMCbuTzYk6UBqpsS', 'subscriber', 'https://randomuser.me/api/portraits/men/48.jpg', 'Photographe urbain.', 'mateo_street'),
('Anisa', 'Khan', 'anisa.khan@example.com', '$2a$10$0wZ3KKvVcwg60YEgQHdmT.paephbgils.nz7aXMCbuTzYk6UBqpsS', 'creator', 'https://randomuser.me/api/portraits/women/49.jpg', 'Poésie urbaine.', 'anisa_poetry'),
('Jamal', 'Abdul', 'jamal.abdul@example.com', '$2a$10$0wZ3KKvVcwg60YEgQHdmT.paephbgils.nz7aXMCbuTzYk6UBqpsS', 'subscriber', 'https://randomuser.me/api/portraits/men/50.jpg', 'Fan de football.', 'jamal_foot');



