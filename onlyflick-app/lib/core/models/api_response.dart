/// Classe générique pour wrapper les réponses de l'API
class ApiResponse<T> {
  final bool isSuccess;
  final T? data;
  final String? error;
  final int? statusCode;

  const ApiResponse._({
    required this.isSuccess,
    this.data,
    this.error,
    this.statusCode,
  });

  /// Constructeur pour les réponses de succès
  factory ApiResponse.success(T? data, [int? statusCode]) {
    return ApiResponse._(
      isSuccess: true,
      data: data,
      statusCode: statusCode,
    );
  }

  /// Constructeur pour les réponses d'erreur
  factory ApiResponse.error(String error, [int? statusCode]) {
    return ApiResponse._(
      isSuccess: false,
      error: error,
      statusCode: statusCode,
    );
  }

  /// Vérifie si la réponse est un succès
  bool get isError => !isSuccess;

  /// Récupère les données avec une vérification de sécurité
  T? get dataOrNull => isSuccess ? data : null;

  /// Récupère les données ou lance une exception
  T get dataOrThrow {
    if (isSuccess && data != null) {
      return data!;
    }
    throw ApiResponseException(error ?? 'Unknown error', statusCode);
  }

  /// Exécute une fonction si la réponse est un succès
  R? onSuccess<R>(R Function(T data) callback) {
    if (isSuccess && data != null) {
      return callback(data!);
    }
    return null;
  }

  /// Exécute une fonction si la réponse est une erreur
  R? onError<R>(R Function(String error, int? statusCode) callback) {
    if (isError && error != null) {
      return callback(error!, statusCode);
    }
    return null;
  }

  /// Transforme les données en un autre type
  ApiResponse<R> map<R>(R Function(T data) mapper) {
    if (isSuccess && data != null) {
      try {
        final mappedData = mapper(data!);
        return ApiResponse.success(mappedData, statusCode);
      } catch (e) {
        return ApiResponse.error('Error mapping data: $e', statusCode);
      }
    }
    return ApiResponse.error(error ?? 'No data to map', statusCode);
  }

  /// Combine avec une autre ApiResponse
  ApiResponse<R> flatMap<R>(ApiResponse<R> Function(T data) mapper) {
    if (isSuccess && data != null) {
      return mapper(data!);
    }
    return ApiResponse.error(error ?? 'No data to flat map', statusCode);
  }

  @override
  String toString() {
    if (isSuccess) {
      return 'ApiResponse.success(data: $data, statusCode: $statusCode)';
    } else {
      return 'ApiResponse.error(error: $error, statusCode: $statusCode)';
    }
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ApiResponse<T> &&
        other.isSuccess == isSuccess &&
        other.data == data &&
        other.error == error &&
        other.statusCode == statusCode;
  }

  @override
  int get hashCode =>
      isSuccess.hashCode ^
      data.hashCode ^
      error.hashCode ^
      statusCode.hashCode;
}

/// Exception spécifique pour les erreurs de réponse API
class ApiResponseException implements Exception {
  final String message;
  final int? statusCode;

  const ApiResponseException(this.message, this.statusCode);

  @override
  String toString() =>
      'ApiResponseException: $message${statusCode != null ? ' (HTTP $statusCode)' : ''}';
}

/// Extensions utiles pour ApiResponse
extension ApiResponseExtensions<T> on ApiResponse<T> {
  /// Récupère un message d'erreur formaté
  String get errorMessage {
    if (error != null) return error!;
    if (statusCode != null) return 'Erreur HTTP $statusCode';
    return 'Erreur inconnue';
  }

  /// Vérifie si c'est une erreur d'authentification
  bool get isAuthError => statusCode == 401;

  /// Vérifie si c'est une erreur de permission
  bool get isPermissionError => statusCode == 403;

  /// Vérifie si c'est une erreur de ressource non trouvée
  bool get isNotFoundError => statusCode == 404;

  /// Vérifie si c'est une erreur de validation
  bool get isValidationError => statusCode == 400;

  /// Vérifie si c'est une erreur serveur
  bool get isServerError => statusCode != null && statusCode! >= 500;

  /// Vérifie si c'est une erreur réseau/client
  bool get isClientError => statusCode != null && statusCode! >= 400 && statusCode! < 500;
}