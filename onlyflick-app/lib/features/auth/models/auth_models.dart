/// Modèle pour l'utilisateur (correspond au backend Go)
class User {
  final int id;
  final String firstName;
  final String lastName;
  final String email;
  final String role;
  final DateTime createdAt;
  // ===== NOUVEAUX CHAMPS PROFIL =====
  final String avatarUrl;
  final String bio;
  final String username;
  final DateTime? updatedAt;

  const User({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.role,
    required this.createdAt,
    // ===== NOUVEAUX CHAMPS AVEC VALEURS PAR DÉFAUT =====
    this.avatarUrl = '',
    this.bio = '',
    this.username = '',
    this.updatedAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] ?? 0,
      firstName: json['first_name'] ?? '',
      lastName: json['last_name'] ?? '',
      email: json['email'] ?? '',
      role: json['role'] ?? 'subscriber',
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      // ===== PARSING DES NOUVEAUX CHAMPS =====
      avatarUrl: json['avatar_url'] ?? '',
      bio: json['bio'] ?? '',
      username: json['username'] ?? '',
      updatedAt: json['updated_at'] != null 
          ? DateTime.tryParse(json['updated_at']) 
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'first_name': firstName,
    'last_name': lastName,
    'email': email,
    'role': role,
    'created_at': createdAt.toIso8601String(),
    // ===== SÉRIALISATION DES NOUVEAUX CHAMPS =====
    'avatar_url': avatarUrl,
    'bio': bio,
    'username': username,
    if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
  };

  /// Nom complet de l'utilisateur
  String get fullName => '$firstName $lastName';

  /// Initiales de l'utilisateur
  String get initials {
    final first = firstName.isNotEmpty ? firstName[0].toUpperCase() : '';
    final last = lastName.isNotEmpty ? lastName[0].toUpperCase() : '';
    return first + last;
  }

  /// Nom d'affichage public (username avec @)
  String get displayName {
    if (username.isNotEmpty) {
      return '@$username';
    }
    return fullName; // Fallback si pas de username
  }

  /// Vérifie si l'utilisateur est un créateur
  bool get isCreator => role == 'creator';

  /// Vérifie si l'utilisateur est un administrateur
  bool get isAdmin => role == 'admin';

  /// Vérifie si l'utilisateur est un abonné
  bool get isSubscriber => role == 'subscriber';

  @override
  String toString() => 'User(id: $id, username: $username, email: $email, role: $role)';
}

/// Requête de connexion
class LoginRequest {
  final String email;
  final String password;

  const LoginRequest({
    required this.email,
    required this.password,
  });

  Map<String, dynamic> toJson() => {
    'email': email,
    'password': password,
  };

  @override
  String toString() => 'LoginRequest(email: $email)';
}

/// Requête d'inscription AVEC USERNAME
class RegisterRequest {
  final String firstName;
  final String lastName;
  final String username;  // ===== AJOUT USERNAME OBLIGATOIRE =====
  final String email;
  final String password;

  const RegisterRequest({
    required this.firstName,
    required this.lastName,
    required this.username,  // ===== USERNAME REQUIS =====
    required this.email,
    required this.password,
  });

  Map<String, dynamic> toJson() => {
    'first_name': firstName,
    'last_name': lastName,
    'username': username,  // ===== INCLURE USERNAME DANS JSON =====
    'email': email,
    'password': password,
  };

  /// Validation côté client
  String? validateUsername() {
    if (username.isEmpty) {
      return 'Username est obligatoire';
    }
    if (username.length < 3 || username.length > 20) {
      return 'Username doit contenir entre 3 et 20 caractères';
    }
    if (!RegExp(r'^[a-zA-Z][a-zA-Z0-9_-]*$').hasMatch(username)) {
      return 'Username doit commencer par une lettre et ne contenir que des lettres, chiffres, _ ou -';
    }
    return null; // Valide
  }

  /// Validation complète de tous les champs
  List<String> validate() {
    final errors = <String>[];
    
    if (firstName.trim().isEmpty) {
      errors.add('Prénom est obligatoire');
    }
    if (lastName.trim().isEmpty) {
      errors.add('Nom est obligatoire');
    }
    if (email.trim().isEmpty) {
      errors.add('Email est obligatoire');
    } else if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
      errors.add('Format email invalide');
    }
    if (password.isEmpty) {
      errors.add('Mot de passe est obligatoire');
    } else if (password.length < 6) {
      errors.add('Mot de passe doit contenir au moins 6 caractères');
    }
    
    final usernameError = validateUsername();
    if (usernameError != null) {
      errors.add(usernameError);
    }
    
    return errors;
  }

  /// Vérifie si tous les champs sont valides
  bool get isValid => validate().isEmpty;

  @override
  String toString() => 'RegisterRequest(firstName: $firstName, lastName: $lastName, username: $username, email: $email)';
}

/// Réponse d'authentification du serveur
class AuthResponse {
  final String token;
  final int userId;
  final String? username;  // ===== AJOUT USERNAME OPTIONNEL =====

  const AuthResponse({
    required this.token,
    required this.userId,
    this.username,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(
      token: json['token'] ?? '',
      userId: json['user_id'] ?? 0,
      username: json['username'],  // ===== PARSE USERNAME =====
    );
  }

  Map<String, dynamic> toJson() => {
    'token': token,
    'user_id': userId,
    if (username != null) 'username': username,
  };

  @override
  String toString() => 'AuthResponse(userId: $userId, username: $username, hasToken: ${token.isNotEmpty})';
}

/// Réponse de vérification username
class UsernameCheckResponse {
  final String username;
  final bool available;
  final String message;

  const UsernameCheckResponse({
    required this.username,
    required this.available,
    required this.message,
  });

  factory UsernameCheckResponse.fromJson(Map<String, dynamic> json) {
    return UsernameCheckResponse(
      username: json['username'] ?? '',
      available: json['available'] ?? false,
      message: json['message'] ?? '',
    );
  }

  @override
  String toString() => 'UsernameCheckResponse(username: $username, available: $available)';
}

/// Requête de mise à jour de profil
class UpdateProfileRequest {
  final String? firstName;
  final String? lastName;
  final String? email;
  final String? password;
  final String? username;  // ===== AJOUT USERNAME =====
  final String? avatarUrl;
  final String? bio;

  const UpdateProfileRequest({
    this.firstName,
    this.lastName,
    this.email,
    this.password,
    this.username,  // ===== USERNAME MODIFIABLE =====
    this.avatarUrl,
    this.bio,
  });

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
    if (firstName != null) json['first_name'] = firstName;
    if (lastName != null) json['last_name'] = lastName;
    if (email != null) json['email'] = email;
    if (password != null) json['password'] = password;
    if (username != null) json['username'] = username;  // ===== INCLURE USERNAME =====
    if (avatarUrl != null) json['avatar_url'] = avatarUrl;
    if (bio != null) json['bio'] = bio;
    return json;
  }

  @override
  String toString() => 'UpdateProfileRequest(username: $username, email: $email, hasPassword: ${password != null})';
}

/// États d'authentification
enum AuthState {
  initial,
  loading,
  authenticated,
  unauthenticated,
  error,
}

/// Types d'erreurs d'authentification
enum AuthErrorType {
  invalidCredentials,  // Email ou mot de passe incorrect
  validation,          // Erreur de validation des données
  network,            // Problème de réseau
  serverError,        // Erreur serveur
  sessionExpired,     // Session expirée (401 spécifique)
  unknown,            // Erreur inconnue
}

/// Erreurs d'authentification avec gestion spécifique des codes HTTP
class AuthError {
  final String message;
  final int? statusCode;
  final String? field;
  final AuthErrorType type;

  const AuthError({
    required this.message,
    this.statusCode,
    this.field,
    required this.type,
  });

  factory AuthError.network() {
    return const AuthError(
      message: 'Problème de connexion. Vérifiez votre réseau.',
      statusCode: 0,
      type: AuthErrorType.network,
    );
  }

  factory AuthError.server() {
    return const AuthError(
      message: 'Erreur serveur. Veuillez réessayer plus tard.',
      statusCode: 500,
      type: AuthErrorType.serverError,
    );
  }

  factory AuthError.unauthorized() {
    return const AuthError(
      message: 'Email ou mot de passe incorrect',
      statusCode: 401,
      type: AuthErrorType.invalidCredentials,
    );
  }

  factory AuthError.sessionExpired() {
    return const AuthError(
      message: 'Session expirée, veuillez vous reconnecter',
      statusCode: 401,
      type: AuthErrorType.sessionExpired,
    );
  }

  /// Gestion correcte des erreurs selon le code HTTP et le contexte
  factory AuthError.fromApiResponse(String apiMessage, int? statusCode) {
    switch (statusCode) {
      case 400:
        // Erreur de validation (données manquantes/invalides)
        return AuthError(
          message: apiMessage.isNotEmpty ? apiMessage : 'Données invalides',
          statusCode: statusCode,
          type: AuthErrorType.validation,
        );
        
      case 401:
        // ✅ DISTINCTION IMPORTANTE: 401 peut être credentials OU session expirée
        if (apiMessage.toLowerCase().contains('session') || 
            apiMessage.toLowerCase().contains('expir') ||
            apiMessage.toLowerCase().contains('token')) {
          // Session expirée (utilisateur était connecté)
          return AuthError(
            message: 'Session expirée, veuillez vous reconnecter',
            statusCode: statusCode,
            type: AuthErrorType.sessionExpired,
          );
        } else {
          // Identifiants incorrects (tentative de connexion)
          return AuthError(
            message: 'Email ou mot de passe incorrect',
            statusCode: statusCode,
            type: AuthErrorType.invalidCredentials,
          );
        }
        
      case 403:
        return AuthError(
          message: 'Accès refusé',
          statusCode: statusCode,
          type: AuthErrorType.validation,
        );
        
      case 500:
      case 502:
      case 503:
        return AuthError(
          message: 'Erreur serveur. Veuillez réessayer plus tard.',
          statusCode: statusCode,
          type: AuthErrorType.serverError,
        );
        
      default:
        // Pour tous les autres cas, on utilise le message du serveur
        return AuthError(
          message: apiMessage.isNotEmpty ? apiMessage : 'Erreur inconnue',
          statusCode: statusCode,
          type: AuthErrorType.unknown,
        );
    }
  }

  factory AuthError.validation(String field, String message) {
    return AuthError(
      message: message,
      field: field,
      statusCode: 400,
      type: AuthErrorType.validation,
    );
  }

  /// : Méthodes utilitaires
  bool get isCredentialsError => type == AuthErrorType.invalidCredentials;
  bool get isSessionExpired => type == AuthErrorType.sessionExpired;
  bool get isNetworkError => type == AuthErrorType.network;
  bool get isValidationError => type == AuthErrorType.validation;
  bool get isServerError => type == AuthErrorType.serverError;
  
  bool get isNetworkErrorLegacy => statusCode == 0;
  bool get isServerErrorLegacy => statusCode != null && statusCode! >= 500;
  bool get isClientError => statusCode != null && statusCode! >= 400 && statusCode! < 500;
  
  /// Message d'erreur approprié pour l'UI
  String get userFriendlyMessage {
    switch (type) {
      case AuthErrorType.invalidCredentials:
        return 'Email ou mot de passe incorrect';
      case AuthErrorType.sessionExpired:
        return 'Session expirée, veuillez vous reconnecter';
      case AuthErrorType.network:
        return 'Problème de connexion. Vérifiez votre réseau.';
      case AuthErrorType.validation:
        return message;
      case AuthErrorType.serverError:
        return 'Erreur serveur. Veuillez réessayer plus tard.';
      case AuthErrorType.unknown:
        return message.isNotEmpty ? message : 'Une erreur est survenue';
    }
  }

  @override
  String toString() => 'AuthError(message: $message, statusCode: $statusCode, field: $field, type: $type)';
}

/// Classe pour les résultats d'authentification
class AuthResult {
  final bool isSuccess;
  final AuthResponse? data;
  final AuthError? error;

  const AuthResult._({
    required this.isSuccess,
    this.data,
    this.error,
  });

  factory AuthResult.success(AuthResponse? data) {
    return AuthResult._(isSuccess: true, data: data);
  }

  factory AuthResult.failure(AuthError error) {
    return AuthResult._(isSuccess: false, error: error);
  }

  bool get isFailure => !isSuccess;
  
  /// : Méthodes utilitaires
  String get errorMessage => error?.userFriendlyMessage ?? '';
  AuthErrorType? get errorType => error?.type;

  @override
  String toString() => isSuccess 
      ? 'AuthResult.success($data)' 
      : 'AuthResult.failure($error)';
}

/// Classe pour les résultats d'utilisateur
class UserResult {
  final bool isSuccess;
  final User? data;
  final AuthError? error;

  const UserResult._({
    required this.isSuccess,
    this.data,
    this.error,
  });

  factory UserResult.success(User data) {
    return UserResult._(isSuccess: true, data: data);
  }

  factory UserResult.failure(AuthError error) {
    return UserResult._(isSuccess: false, error: error);
  }

  bool get isFailure => !isSuccess;
  String get errorMessage => error?.userFriendlyMessage ?? '';

  @override
  String toString() => isSuccess 
      ? 'UserResult.success($data)' 
      : 'UserResult.failure($error)';
}

/// Classe pour les résultats de vérification de username
class UsernameCheckResult {
  final bool isSuccess;
  final UsernameCheckResponse? data;
  final AuthError? error;

  const UsernameCheckResult._({
    required this.isSuccess,
    this.data,
    this.error,
  });

  factory UsernameCheckResult.success(UsernameCheckResponse data) {
    return UsernameCheckResult._(isSuccess: true, data: data);
  }

  factory UsernameCheckResult.failure(AuthError error) {
    return UsernameCheckResult._(isSuccess: false, error: error);
  }

  bool get isFailure => !isSuccess;
  bool get isAvailable => data?.available ?? false;
  String get errorMessage => error?.userFriendlyMessage ?? '';

  @override
  String toString() => isSuccess 
      ? 'UsernameCheckResult.success(${data?.username}: ${data?.available})' 
      : 'UsernameCheckResult.failure($error)';
}