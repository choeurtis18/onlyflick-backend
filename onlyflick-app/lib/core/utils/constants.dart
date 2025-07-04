// lib/utils/constants.dart

class ApiConstants {
  // URL de base de votre API Go
  static const String baseUrl = 'http://localhost:8080/api';
  
  // Pour l'émulateur Android, utilisez : 'http://10.0.2.2:8080/api'
  // Pour un appareil physique, utilisez l'IP de votre machine : 'http://192.168.x.x:8080/api'
  
  // Endpoints de l'API
  static const String loginEndpoint = '/login';
  static const String registerEndpoint = '/register';
  static const String profileEndpoint = '/profile';
  static const String postsEndpoint = '/posts';
  static const String usersEndpoint = '/users';
  static const String followEndpoint = '/follow';
  static const String uploadEndpoint = '/upload';
  
  // Timeouts
  static const Duration connectTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);
  
  // Pagination
  static const int defaultPageSize = 20;
  static const int maxPageSize = 50;
}

class AppConstants {
  // Clés de stockage local
  static const String tokenKey = 'auth_token';
  static const String userIdKey = 'user_id';
  static const String usernameKey = 'username';
  static const String roleKey = 'user_role';
  
  // Rôles utilisateur
  static const String adminRole = 'admin';
  static const String creatorRole = 'creator';
  static const String subscriberRole = 'subscriber';
  
  // Types de contenu
  static const String imageType = 'image';
  static const String videoType = 'video';
  
  // Tailles d'images
  static const double avatarSize = 50.0;
  static const double profileAvatarSize = 100.0;
  static const double postImageMaxHeight = 400.0;
  
  // Messages d'erreur
  static const String networkError = 'Erreur de connexion réseau';
  static const String serverError = 'Erreur du serveur';
  static const String authError = 'Erreur d\'authentification';
  static const String unknownError = 'Une erreur inconnue s\'est produite';
  
  // Validation
  static const int minPasswordLength = 6;
  static const int maxBioLength = 500;
  static const int maxPostCaptionLength = 2000;
  
  // Formats de date
  static const String dateFormat = 'dd/MM/yyyy';
  static const String dateTimeFormat = 'dd/MM/yyyy HH:mm';
  static const String timeFormat = 'HH:mm';
}

class AppColors {
  // Couleurs principales
  static const int primaryColor = 0xFF6366F1; // Indigo
  static const int secondaryColor = 0xFF8B5CF6; // Violet
  static const int accentColor = 0xFFEC4899; // Rose
  
  // Couleurs neutres
  static const int backgroundLight = 0xFFFFFFFF;
  static const int backgroundDark = 0xFF1F2937;
  static const int surfaceLight = 0xFFF9FAFB;
  static const int surfaceDark = 0xFF374151;
  
  // Couleurs de texte
  static const int textPrimary = 0xFF111827;
  static const int textSecondary = 0xFF6B7280;
  static const int textLight = 0xFFFFFFFF;
  
  // Couleurs d'état
  static const int successColor = 0xFF10B981;
  static const int errorColor = 0xFFEF4444;
  static const int warningColor = 0xFFF59E0B;
  static const int infoColor = 0xFF3B82F6;
}