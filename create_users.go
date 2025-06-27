package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"strings"
	"time"
)

const (
	ApiBase  = "http://localhost:8080"
	Password = "password123"
	Timeout  = 30 * time.Second // Timeout pour les requêtes HTTP
)

// ===== STRUCTURES DE REQUÊTE/RÉPONSE =====

type RegisterRequest struct {
	FirstName string `json:"first_name"`
	LastName  string `json:"last_name"`
	Username  string `json:"username"`
	Email     string `json:"email"`
	Password  string `json:"password"`
}

type RegisterResponse struct {
	Message  string `json:"message"`
	UserID   int64  `json:"user_id"`
	Username string `json:"username"`
	Token    string `json:"token"`
}

type LoginRequest struct {
	Email    string `json:"email"`
	Password string `json:"password"`
}

type LoginResponse struct {
	Message  string `json:"message"`
	UserID   int64  `json:"user_id"`
	Username string `json:"username"`
	Token    string `json:"token"`
}

type ErrorResponse struct {
	Error   string `json:"error"`
	Message string `json:"message"`
}

type UserData struct {
	FirstName    string
	LastName     string
	Username     string
	Email        string
	ExpectedRole string
	AvatarURL    string
	Bio          string
}

type BioUpdateRequest struct {
	Bio string `json:"bio"`
}

type AvatarUpdateRequest struct {
	AvatarURL string `json:"avatar_url"`
}

// ===== DONNÉES UTILISATEURS COMPLÈTES =====

var users = []UserData{
	// ADMINISTRATEUR
	{
		FirstName: "Alex", LastName: "Martinez", Username: "admin_onlyflick",
		Email: "admin@onlyflick.com", ExpectedRole: "admin",
		AvatarURL: "https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=400&h=400&fit=crop&crop=face",
		Bio: "Administrateur principal d'OnlyFlick. Passionné par les communautés créatives et l'innovation technologique.",
	},

	// CRÉATEURS FITNESS (3)
	{
		FirstName: "Emma", LastName: "Strong", Username: "emma_fitness",
		Email: "emma.strong@gmail.com", ExpectedRole: "creator",
		AvatarURL: "https://images.unsplash.com/photo-1544005313-94ddf0286df2?w=400&h=400&fit=crop&crop=face",
		Bio: "Coach fitness certifiée 💪 | Transformation physique | Programmes personnalisés | 5 ans d'expérience",
	},
	{
		FirstName: "Marcus", LastName: "Iron", Username: "marcus_muscle",
		Email: "marcus.iron@yahoo.com", ExpectedRole: "creator",
		AvatarURL: "https://images.unsplash.com/photo-1571019613454-1cb2f99b2d8b?w=400&h=400&fit=crop&crop=face",
		Bio: "Bodybuilder professionnel 🏆 | Champion national | Conseils nutrition et musculation | Suivi premium disponible",
	},
	{
		FirstName: "Sofia", LastName: "Zen", Username: "sofia_yoga",
		Email: "sofia.zen@outlook.com", ExpectedRole: "creator",
		AvatarURL: "https://images.unsplash.com/photo-1506629905607-beb7b5c28b8a?w=400&h=400&fit=crop&crop=face",
		Bio: "Professeure de yoga 🧘‍♀️ | Méditation & bien-être | Cours en ligne | Retraites spirituelles | Namaste ✨",
	},

	// CRÉATEURS CUISINE (3)
	{
		FirstName: "Antoine", LastName: "Delacroix", Username: "chef_antoine",
		Email: "antoine.delacroix@gmail.com", ExpectedRole: "creator",
		AvatarURL: "https://images.unsplash.com/photo-1566554273541-37a9ca77b91d?w=400&h=400&fit=crop&crop=face",
		Bio: "Chef étoilé ⭐ | Cuisine française traditionnelle et moderne | Techniques professionnelles | Recettes exclusives",
	},
	{
		FirstName: "Maria", LastName: "Rossi", Username: "mama_maria",
		Email: "maria.rossi@hotmail.com", ExpectedRole: "creator",
		AvatarURL: "https://images.unsplash.com/photo-1594736797933-d0c50ba14942?w=400&h=400&fit=crop&crop=face",
		Bio: "Nonna italienne authentique 🍝 | Recettes de famille transmises depuis 4 générations | Pasta faite maison | Amore per la cucina",
	},
	{
		FirstName: "Kenji", LastName: "Tanaka", Username: "kenji_sushi",
		Email: "kenji.tanaka@live.com", ExpectedRole: "creator",
		AvatarURL: "https://images.unsplash.com/photo-1559847844-d68e1c3a2ffc?w=400&h=400&fit=crop&crop=face",
		Bio: "Maître sushi 🍣 | 15 ans au Japon | Techniques traditionnelles | Poissons de qualité premium | Art culinaire japonais",
	},

	// CRÉATEURS ART (3)
	{
		FirstName: "Luna", LastName: "Paintwell", Username: "luna_art",
		Email: "luna.paintwell@gmail.com", ExpectedRole: "creator",
		AvatarURL: "https://images.unsplash.com/photo-1541961017774-22349e4a1262?w=400&h=400&fit=crop&crop=face",
		Bio: "Artiste peintre contemporaine 🎨 | Aquarelle & acrylique | Tutos step-by-step | Exposition en galeries | L'art pour tous",
	},
	{
		FirstName: "David", LastName: "Sculptor", Username: "david_sculpt",
		Email: "david.sculptor@yahoo.fr", ExpectedRole: "creator",
		AvatarURL: "https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=400&h=400&fit=crop&crop=face",
		Bio: "Sculpteur professionnel ⚒️ | Marbre, bronze, terre | Commandes personnalisées | Masterclass techniques | Art monumental",
	},
	{
		FirstName: "Chloe", LastName: "Handmade", Username: "chloe_diy",
		Email: "chloe.handmade@outlook.fr", ExpectedRole: "creator",
		AvatarURL: "https://images.unsplash.com/photo-1616677223600-b737e8ba0c97?w=400&h=400&fit=crop&crop=face",
		Bio: "Créatrice DIY passionnée ✂️ | Couture, tricot, déco | Zéro déchet | Upcycling | Créations uniques | Ateliers créatifs",
	},

	// CRÉATEURS MUSIQUE (3)
	{
		FirstName: "Jake", LastName: "Melody", Username: "jake_beats",
		Email: "jake.melody@gmail.com", ExpectedRole: "creator",
		AvatarURL: "https://images.unsplash.com/photo-1493225457124-a3eb161ffa5f?w=400&h=400&fit=crop&crop=face",
		Bio: "Producteur musical 🎵 | Hip-hop, R&B, Electronic | Studio pro | Beats exclusifs | Masterclass production | Collabs ouvertes",
	},
	{
		FirstName: "Elena", LastName: "Voice", Username: "elena_vocal",
		Email: "elena.voice@hotmail.fr", ExpectedRole: "creator",
		AvatarURL: "https://images.unsplash.com/photo-1494790108755-2616c85fe7fc?w=400&h=400&fit=crop&crop=face",
		Bio: "Coach vocal professionnel 🎤 | Technique, respiration, style | Tous niveaux | Préparation scène | 10 ans conservatoire",
	},
	{
		FirstName: "Max", LastName: "Guitar", Username: "max_strings",
		Email: "max.guitar@live.fr", ExpectedRole: "creator",
		AvatarURL: "https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=400&h=400&fit=crop&crop=face",
		Bio: "Guitariste virtuose 🎸 | Rock, Blues, Jazz | Tablatures exclusives | Techniques avancées | 20 ans d'expérience live",
	},

	// CRÉATEURS LIFESTYLE (3)
	{
		FirstName: "Isabelle", LastName: "Glow", Username: "isabelle_beauty",
		Email: "isabelle.glow@gmail.com", ExpectedRole: "creator",
		AvatarURL: "https://images.unsplash.com/photo-1580489944761-15a19d654956?w=400&h=400&fit=crop&crop=face",
		Bio: "MUA professionnelle 💄 | Makeup artist certifiée | Tutos beauté | Produits premium | Looks sur-mesure | Confiance en soi",
	},
	{
		FirstName: "Thomas", LastName: "Style", Username: "thomas_fashion",
		Email: "thomas.style@yahoo.fr", ExpectedRole: "creator",
		AvatarURL: "https://images.unsplash.com/photo-1560250097-0b93528c311a?w=400&h=400&fit=crop&crop=face",
		Bio: "Styliste mode homme 👔 | Personal shopper | Tendances actuelles | Conseils morphologie | Look professionnel & casual",
	},
	{
		FirstName: "Aria", LastName: "Wellness", Username: "aria_zen",
		Email: "aria.wellness@outlook.com", ExpectedRole: "creator",
		AvatarURL: "https://images.unsplash.com/photo-1438761681033-6461ffad8d80?w=400&h=400&fit=crop&crop=face",
		Bio: "Coach bien-être holistique ✨ | Développement personnel | Routines healthy | Mindset positif | Équilibre vie pro/perso",
	},

	// ABONNÉS FITNESS (12)
	{
		FirstName: "Julie", LastName: "Martin", Username: "julie_fit",
		Email: "julie.martin@gmail.com", ExpectedRole: "subscriber",
		AvatarURL: "https://images.unsplash.com/photo-1551836022-d5d88e9218df?w=400&h=400&fit=crop&crop=face",
		Bio: "Étudiante en sport 🏃‍♀️ | Passionnée de course à pied | Objectif marathon 2024",
	},
	{
		FirstName: "Pierre", LastName: "Dupont", Username: "pierre_gains",
		Email: "pierre.dupont@yahoo.fr", ExpectedRole: "subscriber",
		AvatarURL: "https://images.unsplash.com/photo-1603415526960-f7e0328c63b1?w=400&h=400&fit=crop&crop=face",
		Bio: "Ingénieur en reconversion fitness | Transformation en cours | Motivation quotidienne",
	},
	{
		FirstName: "Sarah", LastName: "Johnson", Username: "sarah_strong",
		Email: "sarah.johnson@hotmail.com", ExpectedRole: "subscriber",
		AvatarURL: "https://images.unsplash.com/photo-1607631568010-1c4fb0a8938a?w=400&h=400&fit=crop&crop=face",
		Bio: "Maman active de 2 enfants | Sport à la maison | Équilibre famille/forme",
	},
	{
		FirstName: "Alex", LastName: "Rodriguez", Username: "alex_cardio",
		Email: "alex.rodriguez@live.com", ExpectedRole: "subscriber",
		AvatarURL: "https://images.unsplash.com/photo-1507591064344-4c6ce005b128?w=400&h=400&fit=crop&crop=face",
		Bio: "Prof de gym débutant | Cherche nouveaux exercices | Passion crossfit",
	},
	{
		FirstName: "Emma", LastName: "Wilson", Username: "emma_yoga_fan",
		Email: "emma.wilson@gmail.com", ExpectedRole: "subscriber",
		AvatarURL: "https://images.unsplash.com/photo-1546015720-b8b30df5aa27?w=400&h=400&fit=crop&crop=face",
		Bio: "Pratique yoga depuis 3 ans | Recherche sérénité | Méditation quotidienne",
	},
	{
		FirstName: "Lucas", LastName: "Fit", Username: "lucas_muscles",
		Email: "lucas.fit@outlook.fr", ExpectedRole: "subscriber",
		AvatarURL: "https://images.unsplash.com/photo-1552374196-1ab2a1c593e8?w=400&h=400&fit=crop&crop=face",
		Bio: "Lycéen passionné de muscu | Rêve de devenir coach | Apprend tous les jours",
	},
	{
		FirstName: "Maya", LastName: "Zen", Username: "maya_balance",
		Email: "maya.zen@yahoo.com", ExpectedRole: "subscriber",
		AvatarURL: "https://images.unsplash.com/photo-1583195764036-6dc248ac07d9?w=400&h=400&fit=crop&crop=face",
		Bio: "Kinésithérapeute | Intéressée par le pilates | Prévention blessures",
	},
	{
		FirstName: "Tom", LastName: "Runner", Username: "tom_running",
		Email: "tom.runner@hotmail.fr", ExpectedRole: "subscriber",
		AvatarURL: "https://images.unsplash.com/photo-1558618047-3c8c76ca7d13?w=400&h=400&fit=crop&crop=face",
		Bio: "Runner amateur | 3 marathons | Objectif ultra-trail | Endurance",
	},
	{
		FirstName: "Lisa", LastName: "Power", Username: "lisa_lift",
		Email: "lisa.power@live.fr", ExpectedRole: "subscriber",
		AvatarURL: "https://images.unsplash.com/photo-1594736797933-d0c50ba14942?w=400&h=400&fit=crop&crop=face",
		Bio: "Comptable le jour, warrior la nuit | Powerlifting | Force mentale",
	},
	{
		FirstName: "Kevin", LastName: "CrossFit", Username: "kevin_wod",
		Email: "kevin.crossfit@gmail.com", ExpectedRole: "subscriber",
		AvatarURL: "https://images.unsplash.com/photo-1605296867304-46d5465a13f1?w=400&h=400&fit=crop&crop=face",
		Bio: "Accro au CrossFit | WOD quotidien | Communauté avant tout",
	},
	{
		FirstName: "Nina", LastName: "Stretch", Username: "nina_flexibility",
		Email: "nina.stretch@outlook.com", ExpectedRole: "subscriber",
		AvatarURL: "https://images.unsplash.com/photo-1544367567-0f2fcb009e0b?w=400&h=400&fit=crop&crop=face",
		Bio: "Danseuse classique | Travaille la souplesse | Grâce et élégance",
	},
	{
		FirstName: "Ben", LastName: "Cardio", Username: "ben_hiit",
		Email: "ben.cardio@yahoo.fr", ExpectedRole: "subscriber",
		AvatarURL: "https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?w=400&h=400&fit=crop&crop=face",
		Bio: "Fan de HIIT | Sessions courtes et intenses | Efficacité maximale",
	},

	// ABONNÉS CUISINE (13)
	{
		FirstName: "Marie", LastName: "Cuistot", Username: "marie_chef",
		Email: "marie.cuistot@gmail.com", ExpectedRole: "subscriber",
		AvatarURL: "https://images.unsplash.com/photo-1559847844-d68e1c3a2ffc?w=400&h=400&fit=crop&crop=face",
		Bio: "Amatrice de cuisine française | Apprend les techniques pro | Famille nombreuse à nourrir",
	},
	{
		FirstName: "Paolo", LastName: "Pasta", Username: "paolo_italy",
		Email: "paolo.pasta@hotmail.it", ExpectedRole: "subscriber",
		AvatarURL: "https://images.unsplash.com/photo-1566554273541-37a9ca77b91d?w=400&h=400&fit=crop&crop=face",
		Bio: "Italien expatrié | Nostalgie des plats de mamma | Cuisine authentique",
	},
	{
		FirstName: "Yuki", LastName: "Sashimi", Username: "yuki_japan",
		Email: "yuki.sashimi@live.jp", ExpectedRole: "subscriber",
		AvatarURL: "https://images.unsplash.com/photo-1580489944761-15a19d654956?w=400&h=400&fit=crop&crop=face",
		Bio: "Étudiante japonaise | Apprend la cuisine française | Fusion des cultures",
	},
	{
		FirstName: "Carlos", LastName: "Tacos", Username: "carlos_spice",
		Email: "carlos.tacos@outlook.mx", ExpectedRole: "subscriber",
		AvatarURL: "https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=400&h=400&fit=crop&crop=face",
		Bio: "Chef mexicain amateur | Épices et saveurs | Partage de recettes familiales",
	},
	{
		FirstName: "Sophie", LastName: "Dessert", Username: "sophie_sweet",
		Email: "sophie.dessert@yahoo.fr", ExpectedRole: "subscriber",
		AvatarURL: "https://images.unsplash.com/photo-1438761681033-6461ffad8d80?w=400&h=400&fit=crop&crop=face",
		Bio: "Pâtissière en herbe | Dent sucrée | Créations pour les anniversaires",
	},
	{
		FirstName: "Jean", LastName: "Barbecue", Username: "jean_grill",
		Email: "jean.barbecue@gmail.com", ExpectedRole: "subscriber",
		AvatarURL: "https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=400&h=400&fit=crop&crop=face",
		Bio: "Roi du barbecue | Week-ends grill | Viandes et marinades",
	},
	{
		FirstName: "Anna", LastName: "Vegan", Username: "anna_plant",
		Email: "anna.vegan@live.com", ExpectedRole: "subscriber",
		AvatarURL: "https://images.unsplash.com/photo-1541961017774-22349e4a1262?w=400&h=400&fit=crop&crop=face",
		Bio: "Cuisine végétalienne créative | Santé et éthique | Découvertes culinaires",
	},
	{
		FirstName: "Roberto", LastName: "Wine", Username: "roberto_vino",
		Email: "roberto.wine@hotmail.fr", ExpectedRole: "subscriber",
		AvatarURL: "https://images.unsplash.com/photo-1493225457124-a3eb161ffa5f?w=400&h=400&fit=crop&crop=face",
		Bio: "Sommelier amateur | Accords mets-vins | Découverte terroirs",
	},
	{
		FirstName: "Fatima", LastName: "Orient", Username: "fatima_spices",
		Email: "fatima.orient@outlook.com", ExpectedRole: "subscriber",
		AvatarURL: "https://images.unsplash.com/photo-1616677223600-b737e8ba0c97?w=400&h=400&fit=crop&crop=face",
		Bio: "Cuisine orientale traditionnelle | Épices et parfums | Transmission familiale",
	},
	{
		FirstName: "Oliver", LastName: "Bread", Username: "oliver_boulanger",
		Email: "oliver.bread@gmail.com", ExpectedRole: "subscriber",
		AvatarURL: "https://images.unsplash.com/photo-1603415526960-f7e0328c63b1?w=400&h=400&fit=crop&crop=face",
		Bio: "Boulanger amateur | Pain maison | Levain naturel | Tradition artisanale",
	},
	{
		FirstName: "Camille", LastName: "Healthy", Username: "camille_nutrition",
		Email: "camille.healthy@yahoo.com", ExpectedRole: "subscriber",
		AvatarURL: "https://images.unsplash.com/photo-1551836022-d5d88e9218df?w=400&h=400&fit=crop&crop=face",
		Bio: "Nutritionniste en formation | Cuisine santé | Équilibre alimentaire",
	},
	{
		FirstName: "Diego", LastName: "Fusion", Username: "diego_mix",
		Email: "diego.fusion@live.es", ExpectedRole: "subscriber",
		AvatarURL: "https://images.unsplash.com/photo-1558618047-3c8c76ca7d13?w=400&h=400&fit=crop&crop=face",
		Bio: "Expérimentateur culinaire | Fusion des cultures | Créativité sans limite",
	},
	{
		FirstName: "Léa", LastName: "Comfort", Username: "lea_cocooning",
		Email: "lea.comfort@hotmail.fr", ExpectedRole: "subscriber",
		AvatarURL: "https://images.unsplash.com/photo-1607631568010-1c4fb0a8938a?w=400&h=400&fit=crop&crop=face",
		Bio: "Comfort food addict | Plats réconfortants | Souvenirs d'enfance",
	},

	// ABONNÉS ART (10)
	{
		FirstName: "Vincent", LastName: "Painter", Username: "vincent_colors",
		Email: "vincent.painter@gmail.com", ExpectedRole: "subscriber",
		AvatarURL: "https://images.unsplash.com/photo-1552374196-1ab2a1c593e8?w=400&h=400&fit=crop&crop=face",
		Bio: "Peintre du dimanche | Aquarelle et huile | Paysages et portraits",
	},
	{
		FirstName: "Clara", LastName: "Sketch", Username: "clara_draw",
		Email: "clara.sketch@yahoo.fr", ExpectedRole: "subscriber",
		AvatarURL: "https://images.unsplash.com/photo-1546015720-b8b30df5aa27?w=400&h=400&fit=crop&crop=face",
		Bio: "Dessinatrice passionnée | Portraits réalistes | Crayons et fusains",
	},
	{
		FirstName: "Marco", LastName: "Sculpture", Username: "marco_clay",
		Email: "marco.sculpture@hotmail.com", ExpectedRole: "subscriber",
		AvatarURL: "https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?w=400&h=400&fit=crop&crop=face",
		Bio: "Sculpteur amateur | Terre et argile | Formes abstraites | Expression libre",
	},
	{
		FirstName: "Jade", LastName: "Ceramic", Username: "jade_pottery",
		Email: "jade.ceramic@live.com", ExpectedRole: "subscriber",
		AvatarURL: "https://images.unsplash.com/photo-1583195764036-6dc248ac07d9?w=400&h=400&fit=crop&crop=face",
		Bio: "Céramiste débutante | Poterie thérapeutique | Créations utilitaires",
	},
	{
		FirstName: "Théo", LastName: "Digital", Username: "theo_pixel",
		Email: "theo.digital@outlook.fr", ExpectedRole: "subscriber",
		AvatarURL: "https://images.unsplash.com/photo-1507591064344-4c6ce005b128?w=400&h=400&fit=crop&crop=face",
		Bio: "Graphiste numérique | Art digital | Illustrations modernes | Créativité tech",
	},
	{
		FirstName: "Rose", LastName: "Textile", Username: "rose_fabric",
		Email: "rose.textile@gmail.com", ExpectedRole: "subscriber",
		AvatarURL: "https://images.unsplash.com/photo-1544367567-0f2fcb009e0b?w=400&h=400&fit=crop&crop=face",
		Bio: "Créatrice textile | Broderie et couture | Upcycling mode | Fait main",
	},
	{
		FirstName: "Hugo", LastName: "Photo", Username: "hugo_lens",
		Email: "hugo.photo@yahoo.com", ExpectedRole: "subscriber",
		AvatarURL: "https://images.unsplash.com/photo-1605296867304-46d5465a13f1?w=400&h=400&fit=crop&crop=face",
		Bio: "Photographe amateur | Nature et street | Lumière et composition | Stories visuelles",
	},
	{
		FirstName: "Manon", LastName: "Jewelry", Username: "manon_bijoux",
		Email: "manon.jewelry@hotmail.fr", ExpectedRole: "subscriber",
		AvatarURL: "https://images.unsplash.com/photo-1571019613454-1cb2f99b2d8b?w=400&h=400&fit=crop&crop=face",
		Bio: "Bijoutière artisanale | Métaux précieux | Créations personnalisées | Élégance",
	},
	{
		FirstName: "Arthur", LastName: "Graffiti", Username: "arthur_street",
		Email: "arthur.graffiti@live.fr", ExpectedRole: "subscriber",
		AvatarURL: "https://images.unsplash.com/photo-1560250097-0b93528c311a?w=400&h=400&fit=crop&crop=face",
		Bio: "Street artist | Culture urbaine | Fresques et tags | Art accessible",
	},
	{
		FirstName: "Inès", LastName: "Calligraphy", Username: "ines_letters",
		Email: "ines.calligraphy@outlook.com", ExpectedRole: "subscriber",
		AvatarURL: "https://images.unsplash.com/photo-1494790108755-2616c85fe7fc?w=400&h=400&fit=crop&crop=face",
		Bio: "Calligraphe moderne | Lettres et typographie | Invitations sur-mesure | Élégance scripte",
	},

	// ABONNÉS MUSIQUE (10)
	{
		FirstName: "Julien", LastName: "Bass", Username: "julien_groove",
		Email: "julien.bass@gmail.com", ExpectedRole: "subscriber",
		AvatarURL: "https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=400&h=400&fit=crop&crop=face",
		Bio: "Bassiste amateur | Groove et rythme | Session musicien | Funk et soul",
	},
	{
		FirstName: "Melody", LastName: "Piano", Username: "melody_keys",
		Email: "melody.piano@yahoo.fr", ExpectedRole: "subscriber",
		AvatarURL: "https://images.unsplash.com/photo-1551836022-d5d88e9218df?w=400&h=400&fit=crop&crop=face",
		Bio: "Pianiste classique | Conservatoire 10 ans | Compositions personnelles | Émotions musicales",
	},
	{
		FirstName: "Raphaël", LastName: "Drums", Username: "raphael_beat",
		Email: "raphael.drums@hotmail.com", ExpectedRole: "subscriber",
		AvatarURL: "https://images.unsplash.com/photo-1566554273541-37a9ca77b91d?w=400&h=400&fit=crop&crop=face",
		Bio: "Batteur énergique | Rock et metal | Rythmes complexes | Énergie pure",
	},
	{
		FirstName: "Stella", LastName: "Voice", Username: "stella_song",
		Email: "stella.voice@live.com", ExpectedRole: "subscriber",
		AvatarURL: "https://images.unsplash.com/photo-1580489944761-15a19d654956?w=400&h=400&fit=crop&crop=face",
		Bio: "Chanteuse en herbe | Soul et jazz | Scène ouverte | Voix du cœur",
	},
	{
		FirstName: "Dylan", LastName: "Producer", Username: "dylan_mix",
		Email: "dylan.producer@outlook.fr", ExpectedRole: "subscriber",
		AvatarURL: "https://images.unsplash.com/photo-1603415526960-f7e0328c63b1?w=400&h=400&fit=crop&crop=face",
		Bio: "Producteur bedroom | Lo-fi et chill | Home studio | Beats nocturnes",
	},
	{
		FirstName: "Amélie", LastName: "Violin", Username: "amelie_strings",
		Email: "amelie.violin@gmail.com", ExpectedRole: "subscriber",
		AvatarURL: "https://images.unsplash.com/photo-1607631568010-1c4fb0a8938a?w=400&h=400&fit=crop&crop=face",
		Bio: "Violoniste passionnée | Musique classique et folk | Orchestres amateurs | Mélodie pure",
	},
	{
		FirstName: "Sam", LastName: "Electronic", Username: "sam_synth",
		Email: "sam.electronic@yahoo.com", ExpectedRole: "subscriber",
		AvatarURL: "https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=400&h=400&fit=crop&crop=face",
		Bio: "Electronic music lover | Synthés et machines | Techno underground | Nuits dansantes",
	},
	{
		FirstName: "Luna", LastName: "Harp", Username: "luna_harpe",
		Email: "luna.harp@hotmail.fr", ExpectedRole: "subscriber",
		AvatarURL: "https://images.unsplash.com/photo-1438761681033-6461ffad8d80?w=400&h=400&fit=crop&crop=face",
		Bio: "Harpiste celtique | Musiques du monde | Méditation musicale | Sons cristallins",
	},
	{
		FirstName: "Oscar", LastName: "Rap", Username: "oscar_flow",
		Email: "oscar.rap@live.fr", ExpectedRole: "subscriber",
		AvatarURL: "https://images.unsplash.com/photo-1558618047-3c8c76ca7d13?w=400&h=400&fit=crop&crop=face",
		Bio: "Rappeur en devenir | Textes engagés | Battle et freestyle | Flow authentique",
	},
	{
		FirstName: "Zoe", LastName: "Folk", Username: "zoe_acoustic",
		Email: "zoe.folk@outlook.com", ExpectedRole: "subscriber",
		AvatarURL: "https://images.unsplash.com/photo-1616677223600-b737e8ba0c97?w=400&h=400&fit=crop&crop=face",
		Bio: "Guitare folk | Chansons intimistes | Nature et sincérité | Acoustic sessions",
	},

	// ABONNÉS LIFESTYLE (10)
	{
		FirstName: "Chloé", LastName: "Beauty", Username: "chloe_makeup",
		Email: "chloe.beauty@gmail.com", ExpectedRole: "subscriber",
		AvatarURL: "https://images.unsplash.com/photo-1541961017774-22349e4a1262?w=400&h=400&fit=crop&crop=face",
		Bio: "Makeup addict | Nouveautés beauté | Tutos débutante | Confiance en soi",
	},
	{
		FirstName: "Maxime", LastName: "Style", Username: "maxime_outfit",
		Email: "maxime.style@yahoo.fr", ExpectedRole: "subscriber",
		AvatarURL: "https://images.unsplash.com/photo-1493225457124-a3eb161ffa5f?w=400&h=400&fit=crop&crop=face",
		Bio: "Fashion victim | Tendances mode | Looks quotidiens | Style personnel",
	},
	{
		FirstName: "Anaïs", LastName: "Skincare", Username: "anais_glow",
		Email: "anais.skincare@hotmail.com", ExpectedRole: "subscriber",
		AvatarURL: "https://images.unsplash.com/photo-1546015720-b8b30df5aa27?w=400&h=400&fit=crop&crop=face",
		Bio: "Routine skincare | Peau sensible | Produits naturels | Glow naturel",
	},
	{
		FirstName: "Romain", LastName: "Grooming", Username: "romain_beard",
		Email: "romain.grooming@live.com", ExpectedRole: "subscriber",
		AvatarURL: "https://images.unsplash.com/photo-1552374196-1ab2a1c593e8?w=400&h=400&fit=crop&crop=face",
		Bio: "Soin barbe et cheveux | Barbershop culture | Style masculin | Élégance moderne",
	},
	{
		FirstName: "Lila", LastName: "Wellness", Username: "lila_mindful",
		Email: "lila.wellness@outlook.fr", ExpectedRole: "subscriber",
		AvatarURL: "https://images.unsplash.com/photo-1583195764036-6dc248ac07d9?w=400&h=400&fit=crop&crop=face",
		Bio: "Lifestyle sain | Méditation et yoga | Développement personnel | Équilibre intérieur",
	},
	{
		FirstName: "Nathan", LastName: "Fashion", Username: "nathan_trends",
		Email: "nathan.fashion@gmail.com", ExpectedRole: "subscriber",
		AvatarURL: "https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=400&h=400&fit=crop&crop=face",
		Bio: "Fashion blogger | Streetwear et luxury | Collaborations marques | Influence style",
	},
	{
		FirstName: "Iris", LastName: "Nails", Username: "iris_nailart",
		Email: "iris.nails@yahoo.com", ExpectedRole: "subscriber",
		AvatarURL: "https://images.unsplash.com/photo-1571019613454-1cb2f99b2d8b?w=400&h=400&fit=crop&crop=face",
		Bio: "Nail art passionnée | Manucures créatives | Couleurs et motifs | Détails précieux",
	},
	{
		FirstName: "Axel", LastName: "Fitness", Username: "axel_aesthetic",
		Email: "axel.fitness@hotmail.fr", ExpectedRole: "subscriber",
		AvatarURL: "https://images.unsplash.com/photo-1605296867304-46d5465a13f1?w=400&h=400&fit=crop&crop=face",
		Bio: "Aesthetic lifestyle | Men physique | Nutrition et training | Corps et esprit",
	},
	{
		FirstName: "Célia", LastName: "Hair", Username: "celia_coiffure",
		Email: "celia.hair@live.fr", ExpectedRole: "subscriber",
		AvatarURL: "https://images.unsplash.com/photo-1594736797933-d0c50ba14942?w=400&h=400&fit=crop&crop=face",
		Bio: "Coiffure et couleur | Tendances capillaires | Soins naturels | Beauté des cheveux",
	},
	{
		FirstName: "Bastien", LastName: "Minimal", Username: "bastien_simple",
		Email: "bastien.minimal@outlook.com", ExpectedRole: "subscriber",
		AvatarURL: "https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=400&h=400&fit=crop&crop=face",
		Bio: "Style minimaliste | Garde-robe capsule | Qualité over quantité | Simplicité chic",
	},

	// UTILISATEURS VARIÉS (10)
	{
		FirstName: "Margot", LastName: "Student", Username: "margot_etude",
		Email: "margot.student@gmail.com", ExpectedRole: "subscriber",
		AvatarURL: "https://images.unsplash.com/photo-1544005313-94ddf0286df2?w=400&h=400&fit=crop&crop=face",
		Bio: "Étudiante en marketing | Créativité et innovation | Stage en startup | Futur entrepreneur",
	},
	{
		FirstName: "Fabien", LastName: "Tech", Username: "fabien_code",
		Email: "fabien.tech@yahoo.fr", ExpectedRole: "subscriber",
		AvatarURL: "https://images.unsplash.com/photo-1506629905607-beb7b5c28b8a?w=400&h=400&fit=crop&crop=face",
		Bio: "Développeur fullstack | Code et café | Open source | Tech for good",
	},
	{
		FirstName: "Elsa", LastName: "Travel", Username: "elsa_voyage",
		Email: "elsa.travel@hotmail.com", ExpectedRole: "subscriber",
		AvatarURL: "https://images.unsplash.com/photo-1559847844-d68e1c3a2ffc?w=400&h=400&fit=crop&crop=face",
		Bio: "Voyageuse solo | 30 pays visités | Cultures et rencontres | Aventures authentiques",
	},
	{
		FirstName: "Jordan", LastName: "Gamer", Username: "jordan_play",
		Email: "jordan.gamer@live.com", ExpectedRole: "subscriber",
		AvatarURL: "https://images.unsplash.com/photo-1560250097-0b93528c311a?w=400&h=400&fit=crop&crop=face",
		Bio: "Gamer passionné | Esport et streaming | Communauté gaming | Compétition amicale",
	},
	{
		FirstName: "Victoire", LastName: "Book", Username: "victoire_lecture",
		Email: "victoire.book@outlook.fr", ExpectedRole: "subscriber",
		AvatarURL: "https://images.unsplash.com/photo-1544367567-0f2fcb009e0b?w=400&h=400&fit=crop&crop=face",
		Bio: "Dévoreuse de livres | Fantasy et romance | Chroniques littéraires | Univers imaginaires",
	},
	{
		FirstName: "Gaëtan", LastName: "Nature", Username: "gaetan_outdoor",
		Email: "gaetan.nature@gmail.com", ExpectedRole: "subscriber",
		AvatarURL: "https://images.unsplash.com/photo-1507591064344-4c6ce005b128?w=400&h=400&fit=crop&crop=face",
		Bio: "Amoureux de nature | Randonnée et camping | Écologie pratique | Vie simple",
	},
	{
		FirstName: "Océane", LastName: "Marine", Username: "oceane_mer",
		Email: "oceane.marine@yahoo.com", ExpectedRole: "subscriber",
		AvatarURL: "https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?w=400&h=400&fit=crop&crop=face",
		Bio: "Biologiste marine | Protection océans | Plongée sous-marine | Conscience environnementale",
	},
	{
		FirstName: "Florian", LastName: "Business", Username: "florian_entrepreneur",
		Email: "florian.business@hotmail.fr", ExpectedRole: "subscriber",
		AvatarURL: "https://images.unsplash.com/photo-1566554273541-37a9ca77b91d?w=400&h=400&fit=crop&crop=face",
		Bio: "Jeune entrepreneur | Startup fintech | Innovation et disruption | Networking actif",
	},
	{
		FirstName: "Pauline", LastName: "Parent", Username: "pauline_maman",
		Email: "pauline.parent@live.fr", ExpectedRole: "subscriber",
		AvatarURL: "https://images.unsplash.com/photo-1607631568010-1c4fb0a8938a?w=400&h=400&fit=crop&crop=face",
		Bio: "Maman de 3 enfants | Organisation familiale | Activités créatives | Éducation positive",
	},
	{
		FirstName: "Valentin", LastName: "Sports", Username: "valentin_match",
		Email: "valentin.sports@outlook.com", ExpectedRole: "subscriber",
		AvatarURL: "https://images.unsplash.com/photo-1558618047-3c8c76ca7d13?w=400&h=400&fit=crop&crop=face",
		Bio: "Fan de sports | Football et tennis | Supporter passionné | Esprit d'équipe",
	},
}

// ===== CLIENT HTTP CONFIGURÉ =====

func createHTTPClient() *http.Client {
	return &http.Client{
		Timeout: Timeout,
	}
}

// ===== FONCTIONS UTILITAIRES =====

func checkAPIHealth() bool {
	log.Println("🔍 Vérification de l'accessibilité de l'API...")
	
	client := createHTTPClient()
	resp, err := client.Get(ApiBase + "/health")
	if err != nil {
		log.Printf("❌ API non accessible: %v", err)
		return false
	}
	defer resp.Body.Close()

	if resp.StatusCode == 200 {
		body, _ := io.ReadAll(resp.Body)
		log.Printf("✅ API accessible: %s", string(body))
		return true
	} else {
		log.Printf("❌ API non accessible (status: %d)", resp.StatusCode)
		return false
	}
}

func makeAPIRequest(method, endpoint string, data interface{}, token string) (*http.Response, error) {
	var reqBody io.Reader
	
	if data != nil {
		jsonData, err := json.Marshal(data)
		if err != nil {
			return nil, fmt.Errorf("erreur marshalling JSON: %w", err)
		}
		reqBody = bytes.NewBuffer(jsonData)
	}

	req, err := http.NewRequest(method, ApiBase+endpoint, reqBody)
	if err != nil {
		return nil, fmt.Errorf("erreur création requête: %w", err)
	}

	req.Header.Set("Content-Type", "application/json")
	if token != "" {
		req.Header.Set("Authorization", "Bearer "+token)
	}

	client := createHTTPClient()
	return client.Do(req)
}

// ===== FONCTIONS PRINCIPALES =====

func createUser(userData UserData) (bool, *RegisterResponse) {
	reqData := RegisterRequest{
		FirstName: userData.FirstName,
		LastName:  userData.LastName,
		Username:  userData.Username,
		Email:     userData.Email,
		Password:  Password,
	}

	resp, err := makeAPIRequest("POST", "/register", reqData, "")
	if err != nil {
		log.Printf("❌ %s: %v", userData.Username, err)
		return false, nil
	}
	defer resp.Body.Close()

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		log.Printf("❌ %s: Erreur lecture réponse - %v", userData.Username, err)
		return false, nil
	}

	if resp.StatusCode == 201 {
		var registerResp RegisterResponse
		if err := json.Unmarshal(body, &registerResp); err != nil {
			log.Printf("❌ %s: Erreur parsing réponse - %v", userData.Username, err)
			return false, nil
		}
		log.Printf("✅ %s créé (ID: %d)", userData.Username, registerResp.UserID)
		return true, &registerResp
	} else {
		var errorResp ErrorResponse
		if err := json.Unmarshal(body, &errorResp); err != nil {
			log.Printf("❌ %s: Erreur %d - %s", userData.Username, resp.StatusCode, string(body))
		} else {
			log.Printf("❌ %s: %s", userData.Username, errorResp.Message)
		}
		return false, nil
	}
}

func updateUserBio(bio, token string) bool {
	reqData := BioUpdateRequest{Bio: bio}
	
	resp, err := makeAPIRequest("PATCH", "/profile/bio", reqData, token)
	if err != nil {
		return false
	}
	defer resp.Body.Close()

	return resp.StatusCode == 200
}

func updateUserProfile(userData UserData, token string) bool {
	success := true
	
	// Mise à jour de l'avatar via l'endpoint profile principal
	if userData.AvatarURL != "" {
		avatarData := map[string]interface{}{
			"avatar_url": userData.AvatarURL,
		}
		
		resp, err := makeAPIRequest("PATCH", "/profile", avatarData, token)
		if err != nil {
			log.Printf("❌ %s: Erreur requête avatar - %v", userData.Username, err)
			success = false
		} else {
			defer resp.Body.Close()
			if resp.StatusCode == 200 {
				log.Printf("🖼️ %s: Avatar mis à jour (%s)", userData.Username, userData.AvatarURL)
			} else {
				body, _ := io.ReadAll(resp.Body)
				log.Printf("❌ %s: Erreur avatar (status %d) - %s", userData.Username, resp.StatusCode, string(body))
				success = false
			}
		}
		
		// Petite pause entre avatar et bio
		time.Sleep(50 * time.Millisecond)
	}

	// Mise à jour de la bio
	if userData.Bio != "" {
		if updateUserBio(userData.Bio, token) {
			log.Printf("📝 %s: Bio mise à jour", userData.Username)
		} else {
			log.Printf("❌ %s: Erreur mise à jour bio", userData.Username)
			success = false
		}
	}

	if success && userData.AvatarURL != "" && userData.Bio != "" {
		log.Printf("✨ %s: Profil complet mis à jour (avatar + bio)", userData.Username)
	}
	
	return success
}

func testAdminLogin() (bool, string) {
	log.Println("🔐 Test de connexion admin...")
	
	reqData := LoginRequest{
		Email:    "admin@onlyflick.com",
		Password: Password,
	}

	resp, err := makeAPIRequest("POST", "/login", reqData, "")
	if err != nil {
		log.Printf("❌ Test admin: %v", err)
		return false, ""
	}
	defer resp.Body.Close()

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		log.Printf("❌ Test admin: Erreur lecture réponse - %v", err)
		return false, ""
	}

	if resp.StatusCode == 200 {
		var loginResp LoginResponse
		if err := json.Unmarshal(body, &loginResp); err != nil {
			log.Printf("❌ Test admin: Erreur parsing réponse - %v", err)
			return false, ""
		}
		log.Printf("✅ Connexion admin réussie! (User ID: %d)", loginResp.UserID)
		log.Printf("🔑 Token: %s...", loginResp.Token[:min(20, len(loginResp.Token))])
		return true, loginResp.Token
	} else {
		var errorResp ErrorResponse
		if err := json.Unmarshal(body, &errorResp); err != nil {
			log.Printf("❌ Test admin: Erreur %d - %s", resp.StatusCode, string(body))
		} else {
			log.Printf("❌ Test admin: %s", errorResp.Message)
		}
		return false, ""
	}
}

func min(a, b int) int {
	if a < b {
		return a
	}
	return b
}

func printPhaseHeader(title string) {
	log.Println("")
	log.Println("=" + strings.Repeat("=", 50))
	log.Printf("  %s", title)
	log.Println("=" + strings.Repeat("=", 50))
	log.Println("")
}

func printStatistics() {
	adminCount := 0
	creatorCount := 0
	subscriberCount := 0

	for _, user := range users {
		switch user.ExpectedRole {
		case "admin":
			adminCount++
		case "creator":
			creatorCount++
		case "subscriber":
			subscriberCount++
		}
	}

	log.Printf("📊 Répartition des utilisateurs:")
	log.Printf("   👑 Administrateurs: %d", adminCount)
	log.Printf("   🎨 Créateurs: %d", creatorCount)
	log.Printf("   👥 Abonnés: %d", subscriberCount)
	log.Printf("   📈 Total: %d utilisateurs", len(users))
}

// ===== FONCTION PRINCIPALE =====

func main() {
	log.Println("🚀 OnlyFlick - Script de création des utilisateurs")
	log.Printf("🌐 API Backend: %s", ApiBase)
	log.Printf("🔒 Mot de passe par défaut: %s", Password)
	
	printStatistics()

	// Vérifier que l'API est accessible
	if !checkAPIHealth() {
		log.Fatal("❌ Impossible de joindre l'API OnlyFlick - Vérifiez que le backend est démarré")
	}

	// PHASE 1: Création des utilisateurs
	printPhaseHeader("PHASE 1: CRÉATION DES UTILISATEURS")

	successCount := 0
	failedCount := 0
	userTokens := make(map[string]string) // Stocker les tokens pour mise à jour profils

	for i, user := range users {
		log.Printf("[%d/%d] 👤 Création de %s (%s)...", 
			i+1, len(users), user.Username, user.ExpectedRole)

		success, response := createUser(user)
		if success && response != nil {
			successCount++
			userTokens[user.Email] = response.Token
		} else {
			failedCount++
		}

		// Pause entre les requêtes pour éviter de surcharger l'API
		if i < len(users)-1 {
			time.Sleep(100 * time.Millisecond)
		}
	}

	log.Println("")
	log.Printf("📊 Résultats Phase 1:")
	log.Printf("✅ Succès: %d/%d (%.1f%%)", successCount, len(users), float64(successCount)/float64(len(users))*100)
	log.Printf("❌ Échecs: %d/%d (%.1f%%)", failedCount, len(users), float64(failedCount)/float64(len(users))*100)

	// PHASE 2: Mise à jour des profils
	if len(userTokens) > 0 {
		printPhaseHeader("PHASE 2: MISE À JOUR DES PROFILS")

		profileUpdated := 0
		profileFailed := 0

		for _, user := range users {
			if token, exists := userTokens[user.Email]; exists {
				log.Printf("🎨 Mise à jour profil %s...", user.Username)
				
				if updateUserProfile(user, token) {
					profileUpdated++
				} else {
					profileFailed++
				}

				// Pause entre les mises à jour
				time.Sleep(100 * time.Millisecond)
			}
		}

		log.Println("")
		log.Printf("📊 Résultats Phase 2:")
		log.Printf("✅ Profils mis à jour: %d/%d", profileUpdated, len(userTokens))
		log.Printf("❌ Échecs mise à jour: %d/%d", profileFailed, len(userTokens))
	}

	// PHASE 3: Test connexion admin
	printPhaseHeader("PHASE 3: VALIDATION CONNEXION ADMIN")
	
	adminSuccess, adminToken := testAdminLogin()
	if adminSuccess {
		log.Printf("✅ Connexion admin validée")
		log.Printf("🔑 Token admin disponible pour tests")
	} else {
		log.Printf("❌ Échec connexion admin")
	}

	// RÉSUMÉ FINAL
	printPhaseHeader("RÉSUMÉ FINAL")
	
	log.Printf("🎉 Script terminé avec succès!")
	log.Printf("👥 Utilisateurs créés: %d/%d", successCount, len(users))
	log.Printf("🎨 Profils configurés: %d", len(userTokens))
	log.Printf("🔐 Connexion admin: %v", adminSuccess)
	
	log.Println("")
	log.Println("📋 PROCHAINES ÉTAPES:")
	log.Println("1. 🌐 Connectez-vous avec: admin@onlyflick.com / password123")
	log.Println("2. 👑 Promouvoir les créateurs via interface admin")
	log.Println("3. 📝 Créer du contenu varié (Étape 2)")
	log.Println("4. 📱 Tester l'application Flutter")
	
	if adminSuccess && len(adminToken) > 0 {
		log.Println("")
		log.Printf("🔑 Token admin pour tests API: %s", adminToken[:min(50, len(adminToken))])
	}
	
	log.Println("")
	log.Println("✨ Base de données OnlyFlick prête pour le développement Flutter!")
}