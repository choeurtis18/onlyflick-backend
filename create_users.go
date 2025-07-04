// create_users_clean.go
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
	Timeout  = 30 * time.Second
)

// ===== STRUCTURES =====

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
	FirstName     string
	LastName      string
	Username      string
	Email         string
	ExpectedRole  string
	AvatarURL     string
	Bio           string
	CategoryFocus string
}

type BioUpdateRequest struct {
	Bio string `json:"bio"`
}

// ===== DONNÉES UTILISATEURS AVEC VRAIES CATÉGORIES =====

var users = []UserData{
	// ======================================
	// 👑 ADMINISTRATEUR
	// ======================================
	{
		FirstName: "Alex", LastName: "Martinez", Username: "admin_onlyflick",
		Email: "admin@onlyflick.com", ExpectedRole: "admin",
		AvatarURL: "https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=400&h=400&fit=crop&crop=face",
		Bio: "Administrateur principal d'OnlyFlick. Passionné par les communautés créatives et l'innovation technologique.",
		CategoryFocus: "admin",
	},

	// ======================================
	// 🌿 CATÉGORIE WELLNESS
	// ======================================
	{
		FirstName: "Sofia", LastName: "Wellness", Username: "sofia_wellness",
		Email: "sofia.wellness@outlook.com", ExpectedRole: "creator",
		AvatarURL: "https://images.unsplash.com/photo-1506629905607-beb7b5c28b8a?w=400&h=400&fit=crop&crop=face",
		Bio: "Coach bien-être holistique 🌿 | Méditation & mindfulness | Équilibre vie-travail | Développement personnel | Habitudes saines",
		CategoryFocus: "wellness",
	},
	{
		FirstName: "Emma", LastName: "Mindful", Username: "emma_mindful",
		Email: "emma.mindful@gmail.com", ExpectedRole: "subscriber",
		AvatarURL: "https://images.unsplash.com/photo-1546015720-b8b30df5aa27?w=400&h=400&fit=crop&crop=face",
		Bio: "Pratique méditation quotidienne | Recherche sérénité | Bien-être mental | Lifestyle healthy",
		CategoryFocus: "wellness",
	},
	{
		FirstName: "Maya", LastName: "Zen", Username: "maya_zen",
		Email: "maya.zen@yahoo.com", ExpectedRole: "subscriber",
		AvatarURL: "https://images.unsplash.com/photo-1583195764036-6dc248ac07d9?w=400&h=400&fit=crop&crop=face",
		Bio: "Kinésithérapeute | Intéressée par la prévention | Bien-être physique et mental | Équilibre quotidien",
		CategoryFocus: "wellness",
	},

	// ======================================
	// 💄 CATÉGORIE BEAUTÉ
	// ======================================
	{
		FirstName: "Isabelle", LastName: "Beauty", Username: "isabelle_beauty",
		Email: "isabelle.beauty@gmail.com", ExpectedRole: "creator",
		AvatarURL: "https://images.unsplash.com/photo-1580489944761-15a19d654956?w=400&h=400&fit=crop&crop=face",
		Bio: "MUA professionnelle 💄 | Makeup artist certifiée | Tutos beauté | Produits premium | Looks sur-mesure | Confiance en soi",
		CategoryFocus: "beaute",
	},
	{
		FirstName: "Chloé", LastName: "Makeup", Username: "chloe_makeup",
		Email: "chloe.makeup@gmail.com", ExpectedRole: "subscriber",
		AvatarURL: "https://images.unsplash.com/photo-1541961017774-22349e4a1262?w=400&h=400&fit=crop&crop=face",
		Bio: "Makeup addict | Nouveautés beauté | Tutos débutante | Confiance en soi | Glam quotidien",
		CategoryFocus: "beaute",
	},
	{
		FirstName: "Anaïs", LastName: "Skincare", Username: "anais_skincare",
		Email: "anais.skincare@hotmail.com", ExpectedRole: "subscriber",
		AvatarURL: "https://images.unsplash.com/photo-1546015720-b8b30df5aa27?w=400&h=400&fit=crop&crop=face",
		Bio: "Routine skincare | Peau sensible | Produits naturels | Glow naturel | Korean skincare lover",
		CategoryFocus: "beaute",
	},

	// ======================================
	// 🎨 CATÉGORIE ART
	// ======================================
	{
		FirstName: "Luna", LastName: "Art", Username: "luna_art",
		Email: "luna.art@gmail.com", ExpectedRole: "creator",
		AvatarURL: "https://images.unsplash.com/photo-1541961017774-22349e4a1262?w=400&h=400&fit=crop&crop=face",
		Bio: "Artiste peintre contemporaine 🎨 | Aquarelle & acrylique | Tutos step-by-step | Exposition en galeries | L'art pour tous",
		CategoryFocus: "art",
	},
	{
		FirstName: "David", LastName: "Artist", Username: "david_artist",
		Email: "david.artist@yahoo.fr", ExpectedRole: "creator",
		AvatarURL: "https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=400&h=400&fit=crop&crop=face",
		Bio: "Sculpteur professionnel ⚒️ | Marbre, bronze, terre | Commandes personnalisées | Masterclass techniques | Art monumental",
		CategoryFocus: "art",
	},
	{
		FirstName: "Vincent", LastName: "Painter", Username: "vincent_painter",
		Email: "vincent.painter@gmail.com", ExpectedRole: "subscriber",
		AvatarURL: "https://images.unsplash.com/photo-1552374196-1ab2a1c593e8?w=400&h=400&fit=crop&crop=face",
		Bio: "Peintre du dimanche | Aquarelle et huile | Paysages et portraits | Passion créative",
		CategoryFocus: "art",
	},

	// ======================================
	// 🎵 CATÉGORIE MUSIQUE
	// ======================================
	{
		FirstName: "Jake", LastName: "Music", Username: "jake_music",
		Email: "jake.music@gmail.com", ExpectedRole: "creator",
		AvatarURL: "https://images.unsplash.com/photo-1493225457124-a3eb161ffa5f?w=400&h=400&fit=crop&crop=face",
		Bio: "Producteur musical 🎵 | Hip-hop, R&B, Electronic | Studio pro | Beats exclusifs | Masterclass production | Collabs ouvertes",
		CategoryFocus: "musique",
	},
	{
		FirstName: "Elena", LastName: "Voice", Username: "elena_voice",
		Email: "elena.voice@hotmail.fr", ExpectedRole: "creator",
		AvatarURL: "https://images.unsplash.com/photo-1494790108755-2616c85fe7fc?w=400&h=400&fit=crop&crop=face",
		Bio: "Coach vocal professionnel 🎤 | Technique, respiration, style | Tous niveaux | Préparation scène | 10 ans conservatoire",
		CategoryFocus: "musique",
	},
	{
		FirstName: "Max", LastName: "Guitar", Username: "max_guitar",
		Email: "max.guitar@live.fr", ExpectedRole: "subscriber",
		AvatarURL: "https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=400&h=400&fit=crop&crop=face",
		Bio: "Guitariste amateur | Rock, Blues, Jazz | Apprentissage continu | Passion musique",
		CategoryFocus: "musique",
	},

	// ======================================
	// 🍽️ CATÉGORIE CUISINE
	// ======================================
	{
		FirstName: "Antoine", LastName: "Chef", Username: "chef_antoine",
		Email: "antoine.chef@gmail.com", ExpectedRole: "creator",
		AvatarURL: "https://images.unsplash.com/photo-1566554273541-37a9ca77b91d?w=400&h=400&fit=crop&crop=face",
		Bio: "Chef professionnel ⭐ | Cuisine française traditionnelle et moderne | Techniques professionnelles | Recettes exclusives",
		CategoryFocus: "cuisine",
	},
	{
		FirstName: "Maria", LastName: "Cook", Username: "maria_cook",
		Email: "maria.cook@hotmail.com", ExpectedRole: "creator",
		AvatarURL: "https://images.unsplash.com/photo-1594736797933-d0c50ba14942?w=400&h=400&fit=crop&crop=face",
		Bio: "Passionnée de cuisine du monde 🍝 | Recettes de famille | Cuisine faite maison | Partage culinaire",
		CategoryFocus: "cuisine",
	},
	{
		FirstName: "Paolo", LastName: "Kitchen", Username: "paolo_kitchen",
		Email: "paolo.kitchen@hotmail.it", ExpectedRole: "subscriber",
		AvatarURL: "https://images.unsplash.com/photo-1566554273541-37a9ca77b91d?w=400&h=400&fit=crop&crop=face",
		Bio: "Amateur de cuisine italienne | Apprentissage techniques | Passion gastronomiqu",
		CategoryFocus: "cuisine",
	},

	// ======================================
	// ⚽ CATÉGORIE FOOTBALL
	// ======================================
	{
		FirstName: "Marcus", LastName: "Football", Username: "marcus_football",
		Email: "marcus.football@yahoo.com", ExpectedRole: "creator",
		AvatarURL: "https://images.unsplash.com/photo-1571019613454-1cb2f99b2d8b?w=400&h=400&fit=crop&crop=face",
		Bio: "Ex-footballeur professionnel ⚽ | Entraîneur diplômé | Analyses tactiques | Techniques | Passion du ballon rond",
		CategoryFocus: "football",
	},
	{
		FirstName: "Pierre", LastName: "Soccer", Username: "pierre_soccer",
		Email: "pierre.soccer@yahoo.fr", ExpectedRole: "subscriber",
		AvatarURL: "https://images.unsplash.com/photo-1603415526960-f7e0328c63b1?w=400&h=400&fit=crop&crop=face",
		Bio: "Supporter passionné | Analyses matchs | Statistiques | Amoureux du football français",
		CategoryFocus: "football",
	},

	// ======================================
	// 🏀 CATÉGORIE BASKET
	// ======================================
	{
		FirstName: "Kevin", LastName: "Basket", Username: "kevin_basket",
		Email: "kevin.basket@gmail.com", ExpectedRole: "creator",
		AvatarURL: "https://images.unsplash.com/photo-1605296867304-46d5465a13f1?w=400&h=400&fit=crop&crop=face",
		Bio: "Coach basketball 🏀 | Techniques de tir | Tactiques équipe | NBA fan | Formation jeunes",
		CategoryFocus: "basket",
	},
	{
		FirstName: "Mike", LastName: "Hoops", Username: "mike_hoops",
		Email: "mike.hoops@live.com", ExpectedRole: "subscriber",
		AvatarURL: "https://images.unsplash.com/photo-1558618047-3c8c76ca7d13?w=400&h=400&fit=crop&crop=face",
		Bio: "Joueur amateur | Streetball | Analyses NBA | Passion du basket depuis toujours",
		CategoryFocus: "basket",
	},

	// ======================================
	// 👗 CATÉGORIE MODE
	// ======================================
	{
		FirstName: "Thomas", LastName: "Fashion", Username: "thomas_fashion",
		Email: "thomas.fashion@yahoo.fr", ExpectedRole: "creator",
		AvatarURL: "https://images.unsplash.com/photo-1560250097-0b93528c311a?w=400&h=400&fit=crop&crop=face",
		Bio: "Styliste mode 👔 | Personal shopper | Tendances actuelles | Conseils morphologie | Look professionnel & casual",
		CategoryFocus: "mode",
	},
	{
		FirstName: "Maxime", LastName: "Style", Username: "maxime_style",
		Email: "maxime.style@yahoo.fr", ExpectedRole: "subscriber",
		AvatarURL: "https://images.unsplash.com/photo-1493225457124-a3eb161ffa5f?w=400&h=400&fit=crop&crop=face",
		Bio: "Fashion enthusiast | Tendances mode | Looks quotidiens | Style personnel | Streetwear lover",
		CategoryFocus: "mode",
	},

	// ======================================
	// 🎬 CATÉGORIE CINÉMA
	// ======================================
	{
		FirstName: "Julien", LastName: "Cinema", Username: "julien_cinema",
		Email: "julien.cinema@gmail.com", ExpectedRole: "creator",
		AvatarURL: "https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=400&h=400&fit=crop&crop=face",
		Bio: "Critique cinéma 🎬 | Analyses films | Festivals | Histoire du cinéma | Découvertes et classiques",
		CategoryFocus: "cinema",
	},
	{
		FirstName: "Sarah", LastName: "Movies", Username: "sarah_movies",
		Email: "sarah.movies@hotmail.com", ExpectedRole: "subscriber",
		AvatarURL: "https://images.unsplash.com/photo-1607631568010-1c4fb0a8938a?w=400&h=400&fit=crop&crop=face",
		Bio: "Cinéphile passionnée | Films indépendants | Critiques personnelles | Séries TV addict",
		CategoryFocus: "cinema",
	},

	// ======================================
	// 📰 CATÉGORIE ACTUALITÉS
	// ======================================
	{
		FirstName: "Julie", LastName: "News", Username: "julie_news",
		Email: "julie.news@gmail.com", ExpectedRole: "creator",
		AvatarURL: "https://images.unsplash.com/photo-1551836022-d5d88e9218df?w=400&h=400&fit=crop&crop=face",
		Bio: "Journaliste 📰 | Analyses politiques | Actualités internationales | Fact-checking | Information vérifiée",
		CategoryFocus: "actualites",
	},
	{
		FirstName: "Tom", LastName: "Actu", Username: "tom_actu",
		Email: "tom.actu@hotmail.fr", ExpectedRole: "subscriber",
		AvatarURL: "https://images.unsplash.com/photo-1558618047-3c8c76ca7d13?w=400&h=400&fit=crop&crop=face",
		Bio: "Passionné d'actualités | Politique française | Économie | Suiveur des grands événements",
		CategoryFocus: "actualites",
	},

	// ======================================
	// 📚 CATÉGORIE MANGAS
	// ======================================
	{
		FirstName: "Akira", LastName: "Manga", Username: "akira_manga",
		Email: "akira.manga@gmail.com", ExpectedRole: "creator",
		AvatarURL: "https://images.unsplash.com/photo-1560250097-0b93528c311a?w=400&h=400&fit=crop&crop=face",
		Bio: "Otaku expert 📚 | Reviews mangas | Analyses cultures japonaise | Recommendations | News anime",
		CategoryFocus: "mangas",
	},
	{
		FirstName: "Yuki", LastName: "Otaku", Username: "yuki_otaku",
		Email: "yuki.otaku@live.com", ExpectedRole: "subscriber",
		AvatarURL: "https://images.unsplash.com/photo-1544005313-94ddf0286df2?w=400&h=400&fit=crop&crop=face",
		Bio: "Fan de mangas shonen | Collectionneur | Cosplay amateur | Passion Japon",
		CategoryFocus: "mangas",
	},

	// ======================================
	// 😂 CATÉGORIE MEMES
	// ======================================
	{
		FirstName: "Jordan", LastName: "Memes", Username: "jordan_memes",
		Email: "jordan.memes@live.com", ExpectedRole: "creator",
		AvatarURL: "https://images.unsplash.com/photo-1560250097-0b93528c311a?w=400&h=400&fit=crop&crop=face",
		Bio: "Créateur de memes 😂 | Humour internet | Viral content | Tendances réseaux sociaux | Rire garantı",
		CategoryFocus: "memes",
	},
	{
		FirstName: "Alex", LastName: "Funny", Username: "alex_funny",
		Email: "alex.funny@outlook.fr", ExpectedRole: "subscriber",
		AvatarURL: "https://images.unsplash.com/photo-1506629905607-beb7b5c28b8a?w=400&h=400&fit=crop&crop=face",
		Bio: "Fan d'humour | Partage de memes | Culture internet | Rire au quotidien",
		CategoryFocus: "memes",
	},

	// ======================================
	// 💻 CATÉGORIE TECH
	// ======================================
	{
		FirstName: "Fabien", LastName: "Tech", Username: "fabien_tech",
		Email: "fabien.tech@yahoo.fr", ExpectedRole: "creator",
		AvatarURL: "https://images.unsplash.com/photo-1506629905607-beb7b5c28b8a?w=400&h=400&fit=crop&crop=face",
		Bio: "Développeur senior 💻 | Nouvelles technologies | Tutoriels code | Open source | Innovation tech",
		CategoryFocus: "tech",
	},
	{
		FirstName: "Emma", LastName: "Code", Username: "emma_code",
		Email: "emma.code@hotmail.com", ExpectedRole: "subscriber",
		AvatarURL: "https://images.unsplash.com/photo-1559847844-d68e1c3a2ffc?w=400&h=400&fit=crop&crop=face",
		Bio: "Étudiante en informatique | Apprentissage programmation | Passion nouvelles technos",
		CategoryFocus: "tech",
	},

	// ======================================
	// 🌟 UTILISATEURS GÉNÉRAUX
	// ======================================
	{
		FirstName: "Margot", LastName: "Student", Username: "margot_student",
		Email: "margot.student@gmail.com", ExpectedRole: "subscriber",
		AvatarURL: "https://images.unsplash.com/photo-1544005313-94ddf0286df2?w=400&h=400&fit=crop&crop=face",
		Bio: "Étudiante en marketing | Créativité et innovation | Stage en startup | Futur entrepreneur",
		CategoryFocus: "wellness",
	},
	{
		FirstName: "Elsa", LastName: "Travel", Username: "elsa_travel",
		Email: "elsa.travel@hotmail.com", ExpectedRole: "subscriber",
		AvatarURL: "https://images.unsplash.com/photo-1559847844-d68e1c3a2ffc?w=400&h=400&fit=crop&crop=face",
		Bio: "Voyageuse solo | 30 pays visités | Cultures et rencontres | Aventures authentiques",
		CategoryFocus: "actualites",
	},
	{
		FirstName: "Victoire", LastName: "Book", Username: "victoire_book",
		Email: "victoire.book@outlook.fr", ExpectedRole: "subscriber",
		AvatarURL: "https://images.unsplash.com/photo-1544367567-0f2fcb009e0b?w=400&h=400&fit=crop&crop=face",
		Bio: "Dévoreuse de livres | Fantasy et romance | Chroniques littéraires | Univers imaginaires",
		CategoryFocus: "mangas",
	},
}

// Script d'EXTENSION - Plus d'utilisateurs par catégorie
// À ajouter APRÈS le premier script pour enrichir la base de données

var additionalUsers = []UserData{
	// ======================================
	// 🌿 WELLNESS - Ajout de 5 utilisateurs
	// ======================================
	{
		FirstName: "Luna", LastName: "Meditation", Username: "luna_meditation",
		Email: "luna.meditation@gmail.com", ExpectedRole: "creator",
		AvatarURL: "https://images.unsplash.com/photo-1594736797933-d0c50ba14942?w=400&h=400&fit=crop&crop=face",
		Bio: "Instructrice méditation 🧘‍♀️ | Mindfulness | Réduction stress | Paix intérieure | 8 ans d'expérience",
		CategoryFocus: "wellness",
	},
	{
		FirstName: "Gabriel", LastName: "Mindset", Username: "gabriel_mindset",
		Email: "gabriel.mindset@outlook.com", ExpectedRole: "subscriber",
		AvatarURL: "https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=400&h=400&fit=crop&crop=face",
		Bio: "Coach de vie | Développement personnel | Habitudes positives | Transformation mentale",
		CategoryFocus: "wellness",
	},
	{
		FirstName: "Océane", LastName: "Breathe", Username: "oceane_breathe",
		Email: "oceane.breathe@yahoo.fr", ExpectedRole: "subscriber",
		AvatarURL: "https://images.unsplash.com/photo-1438761681033-6461ffad8d80?w=400&h=400&fit=crop&crop=face",
		Bio: "Pratique respiration | Yoga pranayama | Gestion du stress | Énergie vitale",
		CategoryFocus: "wellness",
	},
	{
		FirstName: "Tom", LastName: "Balance", Username: "tom_balance",
		Email: "tom.balance@live.fr", ExpectedRole: "subscriber",
		AvatarURL: "https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=400&h=400&fit=crop&crop=face",
		Bio: "Entrepreneur | Équilibre vie-travail | Productivity hacks | Bien-être au travail",
		CategoryFocus: "wellness",
	},
	{
		FirstName: "Iris", LastName: "Calm", Username: "iris_calm",
		Email: "iris.calm@hotmail.com", ExpectedRole: "subscriber",
		AvatarURL: "https://images.unsplash.com/photo-1607631568010-1c4fb0a8938a?w=400&h=400&fit=crop&crop=face",
		Bio: "Psychologue | Techniques de relaxation | Gestion anxiété | Sérénité quotidienne",
		CategoryFocus: "wellness",
	},

	// ======================================
	// 💄 BEAUTÉ - Ajout de 6 utilisateurs
	// ======================================
	{
		FirstName: "Camille", LastName: "Glow", Username: "camille_glow",
		Email: "camille.glow@gmail.com", ExpectedRole: "creator",
		AvatarURL: "https://images.unsplash.com/photo-1580489944761-15a19d654956?w=400&h=400&fit=crop&crop=face",
		Bio: "Esthéticienne professionnelle ✨ | Soins du visage | Peau parfaite | Protocoles anti-âge | Beauty expert",
		CategoryFocus: "beaute",
	},
	{
		FirstName: "Léa", LastName: "Makeup", Username: "lea_makeup",
		Email: "lea.makeup@outlook.fr", ExpectedRole: "subscriber",
		AvatarURL: "https://images.unsplash.com/photo-1544367567-0f2fcb009e0b?w=400&h=400&fit=crop&crop=face",
		Bio: "Beauty addict | Nouveautés cosmétiques | Reviews produits | Maquillage quotidien",
		CategoryFocus: "beaute",
	},
	{
		FirstName: "Jade", LastName: "Natural", Username: "jade_natural",
		Email: "jade.natural@yahoo.com", ExpectedRole: "subscriber",
		AvatarURL: "https://images.unsplash.com/photo-1541961017774-22349e4a1262?w=400&h=400&fit=crop&crop=face",
		Bio: "Cosmétiques naturels | DIY beauté | Zéro déchet | Beauté éco-responsable",
		CategoryFocus: "beaute",
	},
	{
		FirstName: "Mélanie", LastName: "Hair", Username: "melanie_hair",
		Email: "melanie.hair@live.com", ExpectedRole: "subscriber",
		AvatarURL: "https://images.unsplash.com/photo-1616677223600-b737e8ba0c97?w=400&h=400&fit=crop&crop=face",
		Bio: "Coiffeuse passionnée | Soins capillaires | Coiffures tendances | Cheveux sains",
		CategoryFocus: "beaute",
	},
	{
		FirstName: "Sarah", LastName: "Nails", Username: "sarah_nails",
		Email: "sarah.nails@hotmail.fr", ExpectedRole: "subscriber",
		AvatarURL: "https://images.unsplash.com/photo-1551836022-d5d88e9218df?w=400&h=400&fit=crop&crop=face",
		Bio: "Nail art créative | Manucure tendance | Ongles parfaits | Techniques pro",
		CategoryFocus: "beaute",
	},
	{
		FirstName: "Émilie", LastName: "Skincare", Username: "emilie_skincare",
		Email: "emilie.skincare@gmail.com", ExpectedRole: "subscriber",
		AvatarURL: "https://images.unsplash.com/photo-1559847844-d68e1c3a2ffc?w=400&h=400&fit=crop&crop=face",
		Bio: "Dermatologue | Routine skincare médicale | Acné et problèmes de peau | Conseils experts",
		CategoryFocus: "beaute",
	},

	// ======================================
	// 🎨 ART - Ajout de 7 utilisateurs
	// ======================================
	{
		FirstName: "Pablo", LastName: "Modern", Username: "pablo_modern",
		Email: "pablo.modern@gmail.com", ExpectedRole: "creator",
		AvatarURL: "https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=400&h=400&fit=crop&crop=face",
		Bio: "Artiste contemporain 🎨 | Art moderne | Installations | Galeries internationales | Vision avant-gardiste",
		CategoryFocus: "art",
	},
	{
		FirstName: "Maya", LastName: "Digital", Username: "maya_digital",
		Email: "maya.digital@outlook.com", ExpectedRole: "creator",
		AvatarURL: "https://images.unsplash.com/photo-1583195764036-6dc248ac07d9?w=400&h=400&fit=crop&crop=face",
		Bio: "Artiste numérique 💻 | NFT creator | Art génératif | Fusion tech-art | Créations immersives",
		CategoryFocus: "art",
	},
	{
		FirstName: "Théo", LastName: "Street", Username: "theo_street",
		Email: "theo.street@yahoo.fr", ExpectedRole: "subscriber",
		AvatarURL: "https://images.unsplash.com/photo-1507591064344-4c6ce005b128?w=400&h=400&fit=crop&crop=face",
		Bio: "Street artist | Graffiti légal | Art urbain | Expression libre | Culture underground",
		CategoryFocus: "art",
	},
	{
		FirstName: "Alice", LastName: "Photo", Username: "alice_photo",
		Email: "alice.photo@live.fr", ExpectedRole: "subscriber",
		AvatarURL: "https://images.unsplash.com/photo-1494790108755-2616c85fe7fc?w=400&h=400&fit=crop&crop=face",
		Bio: "Photographe portrait | Lumière naturelle | Émotions captées | Moments authentiques",
		CategoryFocus: "art",
	},
	{
		FirstName: "Marco", LastName: "Ceramics", Username: "marco_ceramics",
		Email: "marco.ceramics@hotmail.com", ExpectedRole: "subscriber",
		AvatarURL: "https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?w=400&h=400&fit=crop&crop=face",
		Bio: "Céramiste amateur | Poterie artisanale | Terre et feu | Créations utilitaires uniques",
		CategoryFocus: "art",
	},
	{
		FirstName: "Élise", LastName: "Illustration", Username: "elise_illustration",
		Email: "elise.illustration@gmail.com", ExpectedRole: "subscriber",
		AvatarURL: "https://images.unsplash.com/photo-1546015720-b8b30df5aa27?w=400&h=400&fit=crop&crop=face",
		Bio: "Illustratrice freelance | BD et animation | Univers colorés | Storytelling visuel",
		CategoryFocus: "art",
	},
	{
		FirstName: "Raphaël", LastName: "Sculpture", Username: "raphael_sculpture",
		Email: "raphael.sculpture@outlook.fr", ExpectedRole: "subscriber",
		AvatarURL: "https://images.unsplash.com/photo-1605296867304-46d5465a13f1?w=400&h=400&fit=crop&crop=face",
		Bio: "Sculpteur sur bois | Artisanat traditionnel | Créations sur mesure | Passion du détail",
		CategoryFocus: "art",
	},

	// ======================================
	// 🎵 MUSIQUE - Ajout de 8 utilisateurs
	// ======================================
	{
		FirstName: "Léo", LastName: "Producer", Username: "leo_producer",
		Email: "leo.producer@gmail.com", ExpectedRole: "creator",
		AvatarURL: "https://images.unsplash.com/photo-1493225457124-a3eb161ffa5f?w=400&h=400&fit=crop&crop=face",
		Bio: "Producteur électro 🎛️ | House & Techno | Clubs & festivals | Basses puissantes | Nuits endiablées",
		CategoryFocus: "musique",
	},
	{
		FirstName: "Sofia", LastName: "Piano", Username: "sofia_piano",
		Email: "sofia.piano@outlook.com", ExpectedRole: "creator",
		AvatarURL: "https://images.unsplash.com/photo-1506629905607-beb7b5c28b8a?w=400&h=400&fit=crop&crop=face",
		Bio: "Pianiste concertiste 🎹 | Classique & jazz | Conservatoire | Concerts | Émotions au clavier",
		CategoryFocus: "musique",
	},
	{
		FirstName: "Dylan", LastName: "Rock", Username: "dylan_rock",
		Email: "dylan.rock@yahoo.com", ExpectedRole: "subscriber",
		AvatarURL: "https://images.unsplash.com/photo-1552374196-1ab2a1c593e8?w=400&h=400&fit=crop&crop=face",
		Bio: "Guitariste rock | Groupe local | Riffs puissants | Concerts sauvages | Rock n'roll attitude",
		CategoryFocus: "musique",
	},
	{
		FirstName: "Nina", LastName: "Voice", Username: "nina_voice",
		Email: "nina.voice@live.fr", ExpectedRole: "subscriber",
		AvatarURL: "https://images.unsplash.com/photo-1438761681033-6461ffad8d80?w=400&h=400&fit=crop&crop=face",
		Bio: "Chanteuse soul | Voix puissante | Open mic | Reprises émouvantes | Passion vocale",
		CategoryFocus: "musique",
	},
	{
		FirstName: "Alex", LastName: "Drums", Username: "alex_drums",
		Email: "alex.drums@hotmail.fr", ExpectedRole: "subscriber",
		AvatarURL: "https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=400&h=400&fit=crop&crop=face",
		Bio: "Batteur polyvalent | Rythmes complexes | Sessions studio | Groove infectieux",
		CategoryFocus: "musique",
	},
	{
		FirstName: "Inès", LastName: "Violin", Username: "ines_violin",
		Email: "ines.violin@gmail.com", ExpectedRole: "subscriber",
		AvatarURL: "https://images.unsplash.com/photo-1607631568010-1c4fb0a8938a?w=400&h=400&fit=crop&crop=face",
		Bio: "Violoniste classique | Quatuor à cordes | Mélodies sublimes | Technique parfaite",
		CategoryFocus: "musique",
	},
	{
		FirstName: "Karim", LastName: "Rap", Username: "karim_rap",
		Email: "karim.rap@yahoo.fr", ExpectedRole: "subscriber",
		AvatarURL: "https://images.unsplash.com/photo-1558618047-3c8c76ca7d13?w=400&h=400&fit=crop&crop=face",
		Bio: "Rappeur underground | Textes conscients | Flow unique | Battles locales | Authenticité",
		CategoryFocus: "musique",
	},
	{
		FirstName: "Clara", LastName: "Electronic", Username: "clara_electronic",
		Email: "clara.electronic@outlook.fr", ExpectedRole: "subscriber",
		AvatarURL: "https://images.unsplash.com/photo-1616677223600-b737e8ba0c97?w=400&h=400&fit=crop&crop=face",
		Bio: "DJ amateur | Musique électro | Sets nocturnes | Ambiances magiques | Dancefloor",
		CategoryFocus: "musique",
	},

	// ======================================
	// 🍽️ CUISINE - Ajout de 7 utilisateurs
	// ======================================
	{
		FirstName: "Pierre", LastName: "Pastry", Username: "pierre_pastry",
		Email: "pierre.pastry@gmail.com", ExpectedRole: "creator",
		AvatarURL: "https://images.unsplash.com/photo-1566554273541-37a9ca77b91d?w=400&h=400&fit=crop&crop=face",
		Bio: "Pâtissier expert 🧁 | Desserts signatures | Techniques avancées | École de pâtisserie | Gourmandise sublime",
		CategoryFocus: "cuisine",
	},
	{
		FirstName: "Yuki", LastName: "Sushi", Username: "yuki_sushi",
		Email: "yuki.sushi@live.jp", ExpectedRole: "subscriber",
		AvatarURL: "https://images.unsplash.com/photo-1559847844-d68e1c3a2ffc?w=400&h=400&fit=crop&crop=face",
		Bio: "Apprentie sushi | Traditions japonaises | Poissons frais | Précision au couteau",
		CategoryFocus: "cuisine",
	},
	{
		FirstName: "Carlos", LastName: "Spice", Username: "carlos_spice",
		Email: "carlos.spice@outlook.mx", ExpectedRole: "subscriber",
		AvatarURL: "https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=400&h=400&fit=crop&crop=face",
		Bio: "Cuisine mexicaine | Épices authentiques | Recettes familiales | Saveurs explosives",
		CategoryFocus: "cuisine",
	},
	{
		FirstName: "Amélie", LastName: "Vegan", Username: "amelie_vegan",
		Email: "amelie.vegan@yahoo.fr", ExpectedRole: "subscriber",
		AvatarURL: "https://images.unsplash.com/photo-1544005313-94ddf0286df2?w=400&h=400&fit=crop&crop=face",
		Bio: "Cuisine végane | Alternatives créatives | Nutrition santé | Planète et bien-être",
		CategoryFocus: "cuisine",
	},
	{
		FirstName: "Luca", LastName: "Pizza", Username: "luca_pizza",
		Email: "luca.pizza@hotmail.it", ExpectedRole: "subscriber",
		AvatarURL: "https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=400&h=400&fit=crop&crop=face",
		Bio: "Pizzaiolo passionné | Four à bois | Pâte traditionnelle | Naples authentique",
		CategoryFocus: "cuisine",
	},
	{
		FirstName: "Fatima", LastName: "Morocco", Username: "fatima_morocco",
		Email: "fatima.morocco@live.ma", ExpectedRole: "subscriber",
		AvatarURL: "https://images.unsplash.com/photo-1583195764036-6dc248ac07d9?w=400&h=400&fit=crop&crop=face",
		Bio: "Cuisine marocaine | Tajines parfumés | Épices du souk | Traditions familiales",
		CategoryFocus: "cuisine",
	},
	{
		FirstName: "Henri", LastName: "Wine", Username: "henri_wine",
		Email: "henri.wine@gmail.com", ExpectedRole: "subscriber",
		AvatarURL: "https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=400&h=400&fit=crop&crop=face",
		Bio: "Sommelier amateur | Accords mets-vins | Dégustation | Vignobles français",
		CategoryFocus: "cuisine",
	},

	// ======================================
	// ⚽ FOOTBALL - Ajout de 5 utilisateurs
	// ======================================
	{
		FirstName: "Diego", LastName: "Coach", Username: "diego_coach",
		Email: "diego.coach@gmail.com", ExpectedRole: "creator",
		AvatarURL: "https://images.unsplash.com/photo-1571019613454-1cb2f99b2d8b?w=400&h=400&fit=crop&crop=face",
		Bio: "Entraîneur football ⚽ | Tactiques modernes | Formation jeunes | Ex-joueur pro | Passion du jeu",
		CategoryFocus: "football",
	},
	{
		FirstName: "Matteo", LastName: "Fan", Username: "matteo_fan",
		Email: "matteo.fan@outlook.it", ExpectedRole: "subscriber",
		AvatarURL: "https://images.unsplash.com/photo-1603415526960-f7e0328c63b1?w=400&h=400&fit=crop&crop=face",
		Bio: "Supporter PSG | Analyses tactiques | Statistiques | Passion stade | Ambiance folle",
		CategoryFocus: "football",
	},
	{
		FirstName: "Kevin", LastName: "Goals", Username: "kevin_goals",
		Email: "kevin.goals@yahoo.com", ExpectedRole: "subscriber",
		AvatarURL: "https://images.unsplash.com/photo-1552374196-1ab2a1c593e8?w=400&h=400&fit=crop&crop=face",
		Bio: "Attaquant amateur | Club local | Finition précise | Rêves de gloire | Weekend football",
		CategoryFocus: "football",
	},
	{
		FirstName: "Lucas", LastName: "Keeper", Username: "lucas_keeper",
		Email: "lucas.keeper@live.fr", ExpectedRole: "subscriber",
		AvatarURL: "https://images.unsplash.com/photo-1507591064344-4c6ce005b128?w=400&h=400&fit=crop&crop=face",
		Bio: "Gardien de but | Réflexes de chat | Arrêts spectaculaires | Dernière ligne",
		CategoryFocus: "football",
	},
	{
		FirstName: "Rémi", LastName: "Referee", Username: "remi_referee",
		Email: "remi.referee@hotmail.fr", ExpectedRole: "subscriber",
		AvatarURL: "https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=400&h=400&fit=crop&crop=face",
		Bio: "Arbitre officiel | Règles du jeu | Fair-play | Respect | Justice sur terrain",
		CategoryFocus: "football",
	},

	// ======================================
	// 🏀 BASKET - Ajout de 4 utilisateurs
	// ======================================
	{
		FirstName: "Jamal", LastName: "Coach", Username: "jamal_coach",
		Email: "jamal.coach@gmail.com", ExpectedRole: "creator",
		AvatarURL: "https://images.unsplash.com/photo-1605296867304-46d5465a13f1?w=400&h=400&fit=crop&crop=face",
		Bio: "Coach basketball 🏀 | Stratégies NBA | Formation talents | Ex-universitaire | Mentalité gagnante",
		CategoryFocus: "basket",
	},
	{
		FirstName: "Malik", LastName: "Shooter", Username: "malik_shooter",
		Email: "malik.shooter@yahoo.com", ExpectedRole: "subscriber",
		AvatarURL: "https://images.unsplash.com/photo-1558618047-3c8c76ca7d13?w=400&h=400&fit=crop&crop=face",
		Bio: "Tireur à 3pts | Streetball | Playground legend | Technique parfaite | Clutch time",
		CategoryFocus: "basket",
	},
	{
		FirstName: "Tony", LastName: "Dunker", Username: "tony_dunker",
		Email: "tony.dunker@live.com", ExpectedRole: "subscriber",
		AvatarURL: "https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=400&h=400&fit=crop&crop=face",
		Bio: "Ailier puissant | Dunks spectaculaires | Physique impressionnant | Show time",
		CategoryFocus: "basket",
	},
	{
		FirstName: "Jordan", LastName: "Point", Username: "jordan_point",
		Email: "jordan.point@outlook.com", ExpectedRole: "subscriber",
		AvatarURL: "https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=400&h=400&fit=crop&crop=face",
		Bio: "Meneur de jeu | Vision parfaite | Passes décisives | Chef d'orchestre | Basketball IQ",
		CategoryFocus: "basket",
	},

	// ======================================
	// 👗 MODE - Ajout de 6 utilisateurs
	// ======================================
	{
		FirstName: "Victoria", LastName: "Fashion", Username: "victoria_fashion",
		Email: "victoria.fashion@gmail.com", ExpectedRole: "creator",
		AvatarURL: "https://images.unsplash.com/photo-1544005313-94ddf0286df2?w=400&h=400&fit=crop&crop=face",
		Bio: "Styliste haute couture 👗 | Fashion week | Tendances avant-garde | Créations exclusives | Luxe parisien",
		CategoryFocus: "mode",
	},
	{
		FirstName: "Nathan", LastName: "Street", Username: "nathan_street",
		Email: "nathan.street@outlook.com", ExpectedRole: "subscriber",
		AvatarURL: "https://images.unsplash.com/photo-1493225457124-a3eb161ffa5f?w=400&h=400&fit=crop&crop=face",
		Bio: "Streetwear addict | Sneakers collector | Urban style | Hype beasts | Culture underground",
		CategoryFocus: "mode",
	},
	{
		FirstName: "Chloé", LastName: "Vintage", Username: "chloe_vintage",
		Email: "chloe.vintage@yahoo.fr", ExpectedRole: "subscriber",
		AvatarURL: "https://images.unsplash.com/photo-1541961017774-22349e4a1262?w=400&h=400&fit=crop&crop=face",
		Bio: "Mode vintage | Pièces rétro | Années 70-80 | Friperies | Style unique intemporel",
		CategoryFocus: "mode",
	},
	{
		FirstName: "Antoine", LastName: "Luxury", Username: "antoine_luxury",
		Email: "antoine.luxury@live.fr", ExpectedRole: "subscriber",
		AvatarURL: "https://images.unsplash.com/photo-1560250097-0b93528c311a?w=400&h=400&fit=crop&crop=face",
		Bio: "Mode masculine haut de gamme | Costumes sur-mesure | Élégance classique | Savoir-vivre",
		CategoryFocus: "mode",
	},
	{
		FirstName: "Zara", LastName: "Trendy", Username: "zara_trendy",
		Email: "zara.trendy@hotmail.com", ExpectedRole: "subscriber",
		AvatarURL: "https://images.unsplash.com/photo-1616677223600-b737e8ba0c97?w=400&h=400&fit=crop&crop=face",
		Bio: "Fashion blogger | Tendances instantanées | Looks abordables | Style accessible | Influence mode",
		CategoryFocus: "mode",
	},
	{
		FirstName: "Bastien", LastName: "Minimal", Username: "bastien_minimal",
		Email: "bastien.minimal@gmail.com", ExpectedRole: "subscriber",
		AvatarURL: "https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=400&h=400&fit=crop&crop=face",
		Bio: "Style minimaliste | Garde-robe capsule | Qualité over quantité | Simplicité chic",
		CategoryFocus: "mode",
	},

	// ======================================
	// 🎬 CINÉMA - Ajout de 5 utilisateurs
	// ======================================
	{
		FirstName: "François", LastName: "Director", Username: "francois_director",
		Email: "francois.director@gmail.com", ExpectedRole: "creator",
		AvatarURL: "https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=400&h=400&fit=crop&crop=face",
		Bio: "Réalisateur indépendant 🎬 | Court-métrages | Festivals | Cinéma d'auteur | Vision artistique unique",
		CategoryFocus: "cinema",
	},
	{
		FirstName: "Léa", LastName: "Critic", Username: "lea_critic",
		Email: "lea.critic@outlook.fr", ExpectedRole: "subscriber",
		AvatarURL: "https://images.unsplash.com/photo-1546015720-b8b30df5aa27?w=400&h=400&fit=crop&crop=face",
		Bio: "Critique cinéma | Analyses approfondies | Cannes régulier | Ciné-club | Passion 7ème art",
		CategoryFocus: "cinema",
	},
	{
		FirstName: "Hugo", LastName: "Action", Username: "hugo_action",
		Email: "hugo.action@yahoo.com", ExpectedRole: "subscriber",
		AvatarURL: "https://images.unsplash.com/photo-1605296867304-46d5465a13f1?w=400&h=400&fit=crop&crop=face",
		Bio: "Fan films d'action | Blockbusters | Effets spéciaux | Marvel addict | Adrénaline",
		CategoryFocus: "cinema",
	},
	{
		FirstName: "Emma", LastName: "Indie", Username: "emma_indie",
		Email: "emma.indie@live.com", ExpectedRole: "subscriber",
		AvatarURL: "https://images.unsplash.com/photo-1607631568010-1c4fb0a8938a?w=400&h=400&fit=crop&crop=face",
		Bio: "Cinéma indépendant | Films d'auteur | Découvertes rares | Émotions authentiques",
		CategoryFocus: "cinema",
	},
	{
		FirstName: "Théo", LastName: "Horror", Username: "theo_horror",
		Email: "theo.horror@hotmail.fr", ExpectedRole: "subscriber",
		AvatarURL: "https://images.unsplash.com/photo-1507591064344-4c6ce005b128?w=400&h=400&fit=crop&crop=face",
		Bio: "Passionné horreur | Films d'épouvante | Frissons garantis | Collection VHS | Nuits blanches",
		CategoryFocus: "cinema",
	},

	// ======================================
	// 📰 ACTUALITÉS - Ajout de 5 utilisateurs
	// ======================================
	{
		FirstName: "Martin", LastName: "News", Username: "martin_news",
		Email: "martin.news@gmail.com", ExpectedRole: "creator",
		AvatarURL: "https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=400&h=400&fit=crop&crop=face",
		Bio: "Journaliste indépendant 📰 | Investigations | Analyses politiques | Fact-checking | Information vérifiée",
		CategoryFocus: "actualites",
	},
	{
		FirstName: "Clara", LastName: "Politics", Username: "clara_politics",
		Email: "clara.politics@outlook.fr", ExpectedRole: "subscriber",
		AvatarURL: "https://images.unsplash.com/photo-1438761681033-6461ffad8d80?w=400&h=400&fit=crop&crop=face",
		Bio: "Passionnée politique | Débats publics | Élections | Démocratie | Engagement citoyen",
		CategoryFocus: "actualites",
	},
	{
		FirstName: "Alex", LastName: "World", Username: "alex_world",
		Email: "alex.world@yahoo.com", ExpectedRole: "subscriber",
		AvatarURL: "https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=400&h=400&fit=crop&crop=face",
		Bio: "Actualités internationales | Géopolitique | Conflits mondiaux | Diplomatie | Vision globale",
		CategoryFocus: "actualites",
	},
	{
		FirstName: "Sophie", LastName: "Local", Username: "sophie_local",
		Email: "sophie.local@live.fr", ExpectedRole: "subscriber",
		AvatarURL: "https://images.unsplash.com/photo-1594736797933-d0c50ba14942?w=400&h=400&fit=crop&crop=face",
		Bio: "Journalisme local | Vie de quartier | Municipales | Proximité | Terrain quotidien",
		CategoryFocus: "actualites",
	},
	{
		FirstName: "David", LastName: "Economy", Username: "david_economy",
		Email: "david.economy@hotmail.com", ExpectedRole: "subscriber",
		AvatarURL: "https://images.unsplash.com/photo-1566554273541-37a9ca77b91d?w=400&h=400&fit=crop&crop=face",
		Bio: "Économie française | Marchés financiers | Analyses boursières | Tendances économiques",
		CategoryFocus: "actualites",
	},

	// ======================================
	// 📚 MANGAS - Ajout de 6 utilisateurs
	// ======================================
	{
		FirstName: "Akira", LastName: "Sensei", Username: "akira_sensei",
		Email: "akira.sensei@gmail.com", ExpectedRole: "creator",
		AvatarURL: "https://images.unsplash.com/photo-1560250097-0b93528c311a?w=400&h=400&fit=crop&crop=face",
		Bio: "Expert manga 📚 | Culture japonaise | Reviews détaillées | Recommendations | Histoire du manga",
		CategoryFocus: "mangas",
	},
	{
		FirstName: "Yuki", LastName: "Otaku", Username: "yuki_otaku",
		Email: "yuki.otaku@live.jp", ExpectedRole: "subscriber",
		AvatarURL: "https://images.unsplash.com/photo-1544005313-94ddf0286df2?w=400&h=400&fit=crop&crop=face",
		Bio: "Otaku passionnée | Collection manga | Cosplay créatif | Conventions | Japon authentique",
		CategoryFocus: "mangas",
	},
	{
		FirstName: "Ryu", LastName: "Shonen", Username: "ryu_shonen",
		Email: "ryu.shonen@yahoo.com", ExpectedRole: "subscriber",
		AvatarURL: "https://images.unsplash.com/photo-1558618047-3c8c76ca7d13?w=400&h=400&fit=crop&crop=face",
		Bio: "Fan shonen | One Piece addict | Naruto expert | Dragon Ball legend | Action épique",
		CategoryFocus: "mangas",
	},
	{
		FirstName: "Sakura", LastName: "Shojo", Username: "sakura_shojo",
		Email: "sakura.shojo@outlook.com", ExpectedRole: "subscriber",
		AvatarURL: "https://images.unsplash.com/photo-1616677223600-b737e8ba0c97?w=400&h=400&fit=crop&crop=face",
		Bio: "Passionnée shojo | Romance manga | Sailor Moon nostalgique | Émotions kawaii",
		CategoryFocus: "mangas",
	},
	{
		FirstName: "Kenji", LastName: "Seinen", Username: "kenji_seinen",
		Email: "kenji.seinen@live.fr", ExpectedRole: "subscriber",
		AvatarURL: "https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=400&h=400&fit=crop&crop=face",
		Bio: "Seinen connaisseur | Berserk fan | Monster psychologique | Histoires matures | Profondeur",
		CategoryFocus: "mangas",
	},
	{
		FirstName: "Hana", LastName: "Anime", Username: "hana_anime",
		Email: "hana.anime@hotmail.fr", ExpectedRole: "subscriber",
		AvatarURL: "https://images.unsplash.com/photo-1583195764036-6dc248ac07d9?w=400&h=400&fit=crop&crop=face",
		Bio: "Anime addict | Studio Ghibli fan | Adaptations manga | Animation japonaise | Rêves animés",
		CategoryFocus: "mangas",
	},

	// ======================================
	// 😂 MEMES - Ajout de 5 utilisateurs
	// ======================================
	{
		FirstName: "Kevin", LastName: "Viral", Username: "kevin_viral",
		Email: "kevin.viral@gmail.com", ExpectedRole: "creator",
		AvatarURL: "https://images.unsplash.com/photo-1560250097-0b93528c311a?w=400&h=400&fit=crop&crop=face",
		Bio: "Créateur memes viral 😂 | Humour internet | Tendances réseaux | Contenu funny | Rire quotidien",
		CategoryFocus: "memes",
	},
	{
		FirstName: "Dylan", LastName: "Funny", Username: "dylan_funny",
		Email: "dylan.funny@outlook.com", ExpectedRole: "subscriber",
		AvatarURL: "https://images.unsplash.com/photo-1552374196-1ab2a1c593e8?w=400&h=400&fit=crop&crop=face",
		Bio: "Chasseur de memes | Reddit explorer | Humour absurde | Partage fou rire | Internet culture",
		CategoryFocus: "memes",
	},
	{
		FirstName: "Lisa", LastName: "LOL", Username: "lisa_lol",
		Email: "lisa.lol@yahoo.fr", ExpectedRole: "subscriber",
		AvatarURL: "https://images.unsplash.com/photo-1551836022-d5d88e9218df?w=400&h=400&fit=crop&crop=face",
		Bio: "Meme queen | TikTok trends | Humour millennial | Gif collection | Always laughing",
		CategoryFocus: "memes",
	},
	{
		FirstName: "Tony", LastName: "Humor", Username: "tony_humor",
		Email: "tony.humor@live.com", ExpectedRole: "subscriber",
		AvatarURL: "https://images.unsplash.com/photo-1507591064344-4c6ce005b128?w=400&h=400&fit=crop&crop=face",
		Bio: "Stand-up amateur | Blagues quotidiennes | Timing parfait | Humour observationnel",
		CategoryFocus: "memes",
	},
	{
		FirstName: "Zoé", LastName: "Sarcasm", Username: "zoe_sarcasm",
		Email: "zoe.sarcasm@hotmail.fr", ExpectedRole: "subscriber",
		AvatarURL: "https://images.unsplash.com/photo-1546015720-b8b30df5aa27?w=400&h=400&fit=crop&crop=face",
		Bio: "Reine du sarcasme | Humour noir | Ironie fine | Punchlines assassines | Esprit vif",
		CategoryFocus: "memes",
	},

	// ======================================
	// 💻 TECH - Ajout de 7 utilisateurs
	// ======================================
	{
		FirstName: "Alexandre", LastName: "Code", Username: "alexandre_code",
		Email: "alexandre.code@gmail.com", ExpectedRole: "creator",
		AvatarURL: "https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=400&h=400&fit=crop&crop=face",
		Bio: "Lead Developer 💻 | Full-stack expert | Architecture logicielle | Mentoring | Open source contributor",
		CategoryFocus: "tech",
	},
	{
		FirstName: "Julie", LastName: "Frontend", Username: "julie_frontend",
		Email: "julie.frontend@outlook.com", ExpectedRole: "creator",
		AvatarURL: "https://images.unsplash.com/photo-1551836022-d5d88e9218df?w=400&h=400&fit=crop&crop=face",
		Bio: "UI/UX Developer 🎨 | React specialist | Design systems | Interfaces modernes | User experience",
		CategoryFocus: "tech",
	},
	{
		FirstName: "Marc", LastName: "Backend", Username: "marc_backend",
		Email: "marc.backend@yahoo.com", ExpectedRole: "subscriber",
		AvatarURL: "https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=400&h=400&fit=crop&crop=face",
		Bio: "Backend engineer | APIs robustes | Microservices | Cloud architecture | Performance",
		CategoryFocus: "tech",
	},
	{
		FirstName: "Sarah", LastName: "Mobile", Username: "sarah_mobile",
		Email: "sarah.mobile@live.fr", ExpectedRole: "subscriber",
		AvatarURL: "https://images.unsplash.com/photo-1607631568010-1c4fb0a8938a?w=400&h=400&fit=crop&crop=face",
		Bio: "Mobile developer | Flutter & React Native | Apps natives | Store optimization",
		CategoryFocus: "tech",
	},
	{
		FirstName: "Thomas", LastName: "AI", Username: "thomas_ai",
		Email: "thomas.ai@hotmail.com", ExpectedRole: "subscriber",
		AvatarURL: "https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=400&h=400&fit=crop&crop=face",
		Bio: "Data scientist | Machine learning | IA générative | Python expert | Future tech",
		CategoryFocus: "tech",
	},
	{
		FirstName: "Emma", LastName: "Cyber", Username: "emma_cyber",
		Email: "emma.cyber@gmail.com", ExpectedRole: "subscriber",
		AvatarURL: "https://images.unsplash.com/photo-1559847844-d68e1c3a2ffc?w=400&h=400&fit=crop&crop=face",
		Bio: "Cybersécurité | Ethical hacking | Protection données | Sécurité réseau | Vigilance",
		CategoryFocus: "tech",
	},
	{
		FirstName: "Paul", LastName: "DevOps", Username: "paul_devops",
		Email: "paul.devops@outlook.fr", ExpectedRole: "subscriber",
		AvatarURL: "https://images.unsplash.com/photo-1605296867304-46d5465a13f1?w=400&h=400&fit=crop&crop=face",
		Bio: "DevOps engineer | CI/CD pipelines | Docker & Kubernetes | Infrastructure as code",
		CategoryFocus: "tech",
	},
}

// ===== FONCTION PRINCIPALE POUR EXTENSION =====

func createAdditionalUsers() {
	log.Println("")
	log.Println("🚀 EXTENSION - Ajout de nouveaux utilisateurs par catégories")
	log.Printf("📊 %d utilisateurs supplémentaires à créer", len(additionalUsers))
	
	// Vérifier que l'API est accessible
	if !checkAPIHealth() {
		log.Fatal("❌ Impossible de joindre l'API OnlyFlick")
	}

	// Test de connexion admin pour approuver les créateurs
	adminSuccess, adminToken := testAdminLogin()
	if !adminSuccess {
		log.Printf("⚠️ Pas de token admin - les créateurs ne pourront pas être promus automatiquement")
	}

	printPhaseHeader("CRÉATION DES UTILISATEURS SUPPLÉMENTAIRES")

	successCount := 0
	failedCount := 0
	userTokens := make(map[string]string)

	for i, user := range additionalUsers {
		log.Printf("[%d/%d] 👤 Création de %s [%s] (%s)...", 
			i+1, len(additionalUsers), user.Username, user.CategoryFocus, user.ExpectedRole)

		success, response := createUser(user)
		if success && response != nil {
			successCount++
			userTokens[user.Email] = response.Token
		} else {
			failedCount++
		}

		if i < len(additionalUsers)-1 {
			time.Sleep(100 * time.Millisecond)
		}
	}

	log.Println("")
	log.Printf("📊 Résultats création:")
	log.Printf("✅ Succès: %d/%d (%.1f%%)", successCount, len(additionalUsers), float64(successCount)/float64(len(additionalUsers))*100)
	log.Printf("❌ Échecs: %d/%d (%.1f%%)", failedCount, len(additionalUsers), float64(failedCount)/float64(len(additionalUsers))*100)

	// Mise à jour des profils
	if len(userTokens) > 0 {
		printPhaseHeader("MISE À JOUR DES PROFILS SUPPLÉMENTAIRES")

		profileUpdated := 0
		profileFailed := 0

		for _, user := range additionalUsers {
			if token, exists := userTokens[user.Email]; exists {
				log.Printf("🎨 Mise à jour profil %s [%s]...", user.Username, user.CategoryFocus)
				
				if updateUserProfile(user, token) {
					profileUpdated++
				} else {
					profileFailed++
				}

				time.Sleep(100 * time.Millisecond)
			}
		}

		log.Println("")
		log.Printf("📊 Résultats profils:")
		log.Printf("✅ Profils mis à jour: %d/%d", profileUpdated, len(userTokens))
		log.Printf("❌ Échecs mise à jour: %d/%d", profileFailed, len(userTokens))
	}

	// Promotion des créateurs supplémentaires
	promotedCount := 0
	if adminSuccess && len(userTokens) > 0 {
		printPhaseHeader("PROMOTION DES NOUVEAUX CRÉATEURS")
		
		// Faire les demandes pour les nouveaux créateurs
		requestCount := 0
		for _, user := range additionalUsers {
			if user.ExpectedRole == "creator" {
				if token, exists := userTokens[user.Email]; exists {
					if requestCreatorUpgrade(token) {
						requestCount++
						log.Printf("📋 %s: Demande de créateur soumise [%s]", user.Username, user.CategoryFocus)
					}
					time.Sleep(100 * time.Millisecond)
				}
			}
		}
		
		log.Printf("📊 %d nouvelles demandes de créateur soumises", requestCount)
		
		// Attendre et approuver
		time.Sleep(2 * time.Second)
		
		requestIDs, err := getCreatorRequestsIDs(adminToken)
		if err == nil {
			for _, requestID := range requestIDs {
				if approveCreatorRequest(requestID, adminToken) {
					promotedCount++
					log.Printf("👑 Demande %d approuvée", requestID)
				}
				time.Sleep(100 * time.Millisecond)
			}
		}
		
		log.Printf("📊 %d nouveaux créateurs promus", promotedCount)
	}

	// Statistiques finales détaillées
	printPhaseHeader("STATISTIQUES FINALES PAR CATÉGORIE")
	
	categoryStats := make(map[string]int)
	for _, user := range additionalUsers {
		categoryStats[user.CategoryFocus]++
	}

	log.Printf("📈 NOUVEAUX UTILISATEURS AJOUTÉS PAR CATÉGORIE:")
	for category, count := range categoryStats {
		log.Printf("   %s: +%d utilisateurs", getCategoryEmoji(category), count)
	}
	
	log.Println("")
	log.Printf("🎉 EXTENSION TERMINÉE!")
	log.Printf("👥 Nouveaux utilisateurs créés: %d", successCount)
	log.Printf("🎨 Profils configurés: %d", len(userTokens))
	log.Printf("👑 Nouveaux créateurs: %d", promotedCount)
	
	log.Println("")
	log.Println("✨ Base de données OnlyFlick ENRICHIE avec plus de diversité par catégorie!")
	log.Println("📱 Prêt pour tester l'app Flutter avec une communauté plus large!")
}

// Pour utiliser cette extension, remplacez la fonction main() par :
/*
func main() {
	createAdditionalUsers()
}
*/

// ===== FONCTIONS PRINCIPALES =====
func main() {
    createAdditionalUsers()
}

// func main() {
// 	log.Println("🚀 OnlyFlick - Script de création des utilisateurs NETTOYÉ")
// 	log.Printf("🌐 API Backend: %s", ApiBase)
// 	log.Printf("🔒 Mot de passe par défaut: %s", Password)
	
// 	printStatistics()

// 	// Vérifier que l'API est accessible
// 	if !checkAPIHealth() {
// 		log.Fatal("❌ Impossible de joindre l'API OnlyFlick - Vérifiez que le backend est démarré")
// 	}

// 	// PHASE 1: Création des utilisateurs
// 	printPhaseHeader("PHASE 1: CRÉATION DES UTILISATEURS PAR VRAIES CATÉGORIES")

// 	successCount := 0
// 	failedCount := 0
// 	userTokens := make(map[string]string)
// 	var adminUserID int64

// 	for i, user := range users {
// 		log.Printf("[%d/%d] 👤 Création de %s [%s] (%s)...", 
// 			i+1, len(users), user.Username, user.CategoryFocus, user.ExpectedRole)

// 		success, response := createUser(user)
// 		if success && response != nil {
// 			successCount++
// 			userTokens[user.Email] = response.Token
			
// 			if user.ExpectedRole == "admin" {
// 				adminUserID = response.UserID
// 				log.Printf("👑 Admin ID sauvegardé: %d", adminUserID)
// 			}
// 		} else {
// 			failedCount++
// 		}

// 		if i < len(users)-1 {
// 			time.Sleep(100 * time.Millisecond)
// 		}
// 	}

// 	log.Println("")
// 	log.Printf("📊 Résultats Phase 1:")
// 	log.Printf("✅ Succès: %d/%d (%.1f%%)", successCount, len(users), float64(successCount)/float64(len(users))*100)
// 	log.Printf("❌ Échecs: %d/%d (%.1f%%)", failedCount, len(users), float64(failedCount)/float64(len(users))*100)

// 	// PHASE 1.5: Promotion de l'admin
// 	if adminUserID > 0 {
// 		printPhaseHeader("PHASE 1.5: PROMOTION DE L'ADMINISTRATEUR")
		
// 		log.Printf("👑 Promotion manuelle de l'utilisateur ID %d vers admin", adminUserID)
// 		log.Println("⚠️  ATTENTION: Vous devez maintenant exécuter cette requête SQL sur votre base de données:")
// 		log.Printf("   UPDATE users SET role = 'admin' WHERE id = %d;", adminUserID)
// 		log.Println("")
// 		log.Println("📝 Une fois la requête exécutée, appuyez sur Entrée pour continuer...")
		
// 		var input string
// 		fmt.Scanln(&input)
		
// 		log.Println("✅ Promotion admin supposée effectuée, continuation du script...")
// 	}

// 	// Test connexion admin
// 	adminSuccess, adminToken := testAdminLogin()
// 	if !adminSuccess {
// 		log.Printf("❌ Échec connexion admin")
// 		log.Printf("💡 Vérifiez que la requête SQL a bien été exécutée:")
// 		log.Printf("   UPDATE users SET role = 'admin' WHERE id = %d;", adminUserID)
// 		log.Fatal("⛔ Arrêt du script - admin requis pour la suite")
// 	}

// 	// PHASE 2: Mise à jour des profils
// 	if len(userTokens) > 0 {
// 		printPhaseHeader("PHASE 2: MISE À JOUR DES PROFILS PAR CATÉGORIES")

// 		profileUpdated := 0
// 		profileFailed := 0

// 		for _, user := range users {
// 			if token, exists := userTokens[user.Email]; exists {
// 				log.Printf("🎨 Mise à jour profil %s [%s]...", user.Username, user.CategoryFocus)
				
// 				if updateUserProfile(user, token) {
// 					profileUpdated++
// 				} else {
// 					profileFailed++
// 				}

// 				time.Sleep(100 * time.Millisecond)
// 			}
// 		}

// 		log.Println("")
// 		log.Printf("📊 Résultats Phase 2:")
// 		log.Printf("✅ Profils mis à jour: %d/%d", profileUpdated, len(userTokens))
// 		log.Printf("❌ Échecs mise à jour: %d/%d", profileFailed, len(userTokens))
// 	}

// 	// PHASE 3: Promotion des créateurs
// 	promotedCount := 0
// 	if adminSuccess && len(userTokens) > 0 {
// 		printPhaseHeader("PHASE 3: PROMOTION DES CRÉATEURS")
// 		promotedCount = promoteCreators(adminToken, userTokens)
		
// 		log.Println("")
// 		log.Printf("📊 Résultats Phase 3:")
// 		log.Printf("👑 Créateurs promus: %d", promotedCount)
// 	}

// 	// RÉSUMÉ FINAL
// 	printPhaseHeader("RÉSUMÉ FINAL - ONLYFLICK AVEC VRAIES CATÉGORIES")
	
// 	log.Printf("🎉 Script terminé avec succès!")
// 	log.Printf("👥 Utilisateurs créés: %d/%d", successCount, len(users))
// 	log.Printf("🎨 Profils configurés: %d", len(userTokens))
// 	log.Printf("👑 Créateurs promus: %d", promotedCount)
// 	log.Printf("🔐 Connexion admin: %v", adminSuccess)
	
// 	log.Println("")
// 	log.Println("📋 PROCHAINES ÉTAPES:")
// 	log.Println("1. 🌐 Connectez-vous avec: admin@onlyflick.com / password123")
// 	log.Println("2. ✅ Créateurs automatiquement promus")
// 	log.Println("3. 📝 Créer du contenu varié par catégories")
// 	log.Println("4. 📱 Tester l'application Flutter avec VRAIES catégories")
	
// 	log.Println("")
// 	log.Println("🏷️ VRAIES CATÉGORIES DISPONIBLES:")
// 	log.Println("   🌿 wellness | 💄 beaute | 🎨 art | 🎵 musique")
// 	log.Println("   🍽️ cuisine | ⚽ football | 🏀 basket | 👗 mode")
// 	log.Println("   🎬 cinema | 📰 actualites | 📚 mangas | 😂 memes | 💻 tech")
	
// 	log.Println("")
// 	log.Println("✨ Base de données OnlyFlick NETTOYÉE prête pour le développement Flutter!")
// }

// ===== FONCTIONS UTILITAIRES =====

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
		log.Printf("✅ %s créé [%s] (%s) (ID: %d)", userData.Username, userData.CategoryFocus, userData.ExpectedRole, registerResp.UserID)
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
				log.Printf("🖼️ %s: Avatar mis à jour", userData.Username)
			} else {
				body, _ := io.ReadAll(resp.Body)
				log.Printf("❌ %s: Erreur avatar (status %d) - %s", userData.Username, resp.StatusCode, string(body))
				success = false
			}
		}
		
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
		log.Printf("✨ %s [%s]: Profil complet mis à jour", userData.Username, userData.CategoryFocus)
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

func requestCreatorUpgrade(token string) bool {
	resp, err := makeAPIRequest("POST", "/profile/request-upgrade", nil, token)
	if err != nil {
		return false
	}
	defer resp.Body.Close()

	return resp.StatusCode == 200
}

func approveCreatorRequest(requestID int64, adminToken string) bool {
	endpoint := fmt.Sprintf("/admin/creator-requests/%d/approve", requestID)
	resp, err := makeAPIRequest("POST", endpoint, nil, adminToken)
	if err != nil {
		return false
	}
	defer resp.Body.Close()

	return resp.StatusCode == 200
}

func getCreatorRequestsIDs(adminToken string) ([]int64, error) {
	resp, err := makeAPIRequest("GET", "/admin/creator-requests", nil, adminToken)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	if resp.StatusCode != 200 {
		return nil, fmt.Errorf("status code: %d", resp.StatusCode)
	}

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, err
	}

	var requests []map[string]interface{}
	if err := json.Unmarshal(body, &requests); err != nil {
		return nil, err
	}

	var ids []int64
	for _, req := range requests {
		if id, ok := req["id"].(float64); ok {
			ids = append(ids, int64(id))
		}
	}

	return ids, nil
}

func promoteCreators(adminToken string, userTokens map[string]string) int {
	promotedCount := 0
	
	log.Println("🎨 Processus de promotion des créateurs...")
	
	// Étape 1: Faire les demandes de passage en créateur
	log.Println("📝 Étape 1: Demandes de passage en créateur...")
	requestCount := 0
	
	for _, user := range users {
		if user.ExpectedRole == "creator" {
			if token, exists := userTokens[user.Email]; exists {
				if requestCreatorUpgrade(token) {
					requestCount++
					log.Printf("📋 %s: Demande de créateur soumise [%s]", user.Username, user.CategoryFocus)
				} else {
					log.Printf("❌ %s: Échec demande de créateur", user.Username)
				}
				
				time.Sleep(100 * time.Millisecond)
			}
		}
	}
	
	log.Printf("📊 %d demandes de créateur soumises", requestCount)
	
	// Étape 2: Attendre un peu pour que les demandes soient traitées
	log.Println("⏳ Attente des demandes...")
	time.Sleep(2 * time.Second)
	
	// Étape 3: Approuver toutes les demandes
	log.Println("✅ Étape 2: Approbation des demandes...")
	
	requestIDs, err := getCreatorRequestsIDs(adminToken)
	if err != nil {
		log.Printf("❌ Erreur récupération des demandes: %v", err)
		return 0
	}
	
	log.Printf("📋 %d demandes en attente trouvées", len(requestIDs))
	
	for _, requestID := range requestIDs {
		if approveCreatorRequest(requestID, adminToken) {
			promotedCount++
			log.Printf("👑 Demande %d approuvée", requestID)
		} else {
			log.Printf("❌ Échec approbation demande %d", requestID)
		}
		
		time.Sleep(100 * time.Millisecond)
	}
	
	return promotedCount
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
	
	// Compter par catégorie
	categoryCounts := make(map[string]int)

	for _, user := range users {
		switch user.ExpectedRole {
		case "admin":
			adminCount++
		case "creator":
			creatorCount++
		case "subscriber":
			subscriberCount++
		}
		
		// Compter par focus de catégorie
		categoryCounts[user.CategoryFocus]++
	}

	log.Printf("📊 Répartition des utilisateurs:")
	log.Printf("   👑 Administrateurs: %d", adminCount)
	log.Printf("   🎨 Créateurs: %d", creatorCount)
	log.Printf("   👥 Abonnés: %d", subscriberCount)
	log.Printf("   📈 Total: %d utilisateurs", len(users))
	
	log.Printf("")
	log.Printf("🏷️ Répartition par VRAIES catégories:")
	for category, count := range categoryCounts {
		if category != "" {
			log.Printf("   %s: %d utilisateurs", getCategoryEmoji(category), count)
		}
	}
}

// Fonction utilitaire pour obtenir l'emoji d'une catégorie
func getCategoryEmoji(category string) string {
	switch category {
	case "wellness":
		return "🌿 Wellness"
	case "beaute":
		return "💄 Beauté"
	case "art":
		return "🎨 Art"
	case "musique":
		return "🎵 Musique"
	case "cuisine":
		return "🍽️ Cuisine"
	case "football":
		return "⚽ Football"
	case "basket":
		return "🏀 Basket"
	case "mode":
		return "👗 Mode"
	case "cinema":
		return "🎬 Cinéma"
	case "actualites":
		return "📰 Actualités"
	case "mangas":
		return "📚 Mangas"
	case "memes":
		return "😂 Memes"
	case "tech":
		return "💻 Tech"
	case "admin":
		return "👑 Admin"
	default:
		return "🏷️ " + category
	}
}

func min(a, b int) int {
	if a < b {
		return a
	}
	return b
}

// ===== CLIENT HTTP CONFIGURÉ =====

func createHTTPClient() *http.Client {
	return &http.Client{
		Timeout: Timeout,
	}
}

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