// onlyflick-app/lib/features/messaging/models/message_models.dart

/// Modèle pour un message
class Message {
  final int id;
  final int conversationId;
  final int senderId;
  final String content;
  final DateTime createdAt;
  final DateTime updatedAt;
  
  // Informations sur l'expéditeur (jointes par le backend)
  final String? senderUsername;
  final String? senderFirstName;
  final String? senderLastName;
  final String? senderAvatar;

  const Message({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
    this.senderUsername,
    this.senderFirstName,
    this.senderLastName,
    this.senderAvatar,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'] as int,
      conversationId: json['conversation_id'] as int,
      senderId: json['sender_id'] as int,
      content: json['content'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      senderUsername: json['sender_username'] as String?,
      senderFirstName: json['sender_first_name'] as String?,
      senderLastName: json['sender_last_name'] as String?,
      senderAvatar: json['sender_avatar'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'conversation_id': conversationId,
      'sender_id': senderId,
      'content': content,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      if (senderUsername != null) 'sender_username': senderUsername,
      if (senderFirstName != null) 'sender_first_name': senderFirstName,
      if (senderLastName != null) 'sender_last_name': senderLastName,
      if (senderAvatar != null) 'sender_avatar': senderAvatar,
    };
  }

  /// Nom d'affichage de l'expéditeur
  String get senderDisplayName {
    if (senderFirstName != null && senderLastName != null) {
      return '$senderFirstName $senderLastName';
    }
    if (senderUsername != null) {
      return senderUsername!;
    }
    return 'Utilisateur #$senderId';
  }

  @override
  String toString() => 'Message(id: $id, senderId: $senderId, content: ${content.length > 50 ? '${content.substring(0, 50)}...' : content})';
}

/// Modèle pour une conversation
class Conversation {
  final int id;
  final int user1Id;
  final int user2Id;
  final DateTime createdAt;
  final DateTime updatedAt;
  
  // Informations sur l'autre utilisateur (jointes par le backend)
  final String? otherUserUsername;
  final String? otherUserFirstName;
  final String? otherUserLastName;
  final String? otherUserAvatar;
  
  // Dernier message de la conversation
  final Message? lastMessage;
  final int unreadCount;

  const Conversation({
    required this.id,
    required this.user1Id,
    required this.user2Id,
    required this.createdAt,
    required this.updatedAt,
    this.otherUserUsername,
    this.otherUserFirstName,
    this.otherUserLastName,
    this.otherUserAvatar,
    this.lastMessage,
    this.unreadCount = 0,
  });

  factory Conversation.fromJson(Map<String, dynamic> json) {
    return Conversation(
      id: json['id'] as int,
      user1Id: json['user1_id'] as int,
      user2Id: json['user2_id'] as int,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      otherUserUsername: json['other_user_username'] as String?,
      otherUserFirstName: json['other_user_first_name'] as String?,
      otherUserLastName: json['other_user_last_name'] as String?,
      otherUserAvatar: json['other_user_avatar'] as String?,
      lastMessage: json['last_message'] != null 
          ? Message.fromJson(json['last_message'] as Map<String, dynamic>)
          : null,
      unreadCount: json['unread_count'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user1_id': user1Id,
      'user2_id': user2Id,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      if (otherUserUsername != null) 'other_user_username': otherUserUsername,
      if (otherUserFirstName != null) 'other_user_first_name': otherUserFirstName,
      if (otherUserLastName != null) 'other_user_last_name': otherUserLastName,
      if (otherUserAvatar != null) 'other_user_avatar': otherUserAvatar,
      if (lastMessage != null) 'last_message': lastMessage!.toJson(),
      'unread_count': unreadCount,
    };
  }

  /// Nom d'affichage de l'autre utilisateur
  String get otherUserDisplayName {
    if (otherUserFirstName != null && otherUserLastName != null) {
      return '$otherUserFirstName $otherUserLastName';
    }
    if (otherUserUsername != null) {
      return otherUserUsername!;
    }
    return 'Conversation #$id';
  }

  /// Indique si la conversation a des messages non lus
  bool get hasUnreadMessages => unreadCount > 0;

  /// Récupère l'ID de l'autre utilisateur selon l'utilisateur connecté
  int getOtherUserId(int currentUserId) {
    return currentUserId == user1Id ? user2Id : user1Id;
  }

  @override
  String toString() => 'Conversation(id: $id, otherUser: $otherUserDisplayName, unread: $unreadCount)';
}

/// Modèle pour un utilisateur (simplifié pour la messagerie)
class User {
  final int id;
  final String username;
  final String firstName;
  final String lastName;
  final String email;
  final String? avatar;
  final bool isCreator;

  const User({
    required this.id,
    required this.username,
    required this.firstName,
    required this.lastName,
    required this.email,
    this.avatar,
    this.isCreator = false,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as int,
      username: json['username'] as String,
      firstName: json['first_name'] as String,
      lastName: json['last_name'] as String,
      email: json['email'] as String,
      avatar: json['avatar'] as String?,
      isCreator: json['is_creator'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'first_name': firstName,
      'last_name': lastName,
      'email': email,
      if (avatar != null) 'avatar': avatar,
      'is_creator': isCreator,
    };
  }

  /// Nom d'affichage complet
  String get displayName => '$firstName $lastName';

  /// Initiales pour l'avatar
  String get initials => '${firstName.isNotEmpty ? firstName[0] : ''}${lastName.isNotEmpty ? lastName[0] : ''}';

  @override
  String toString() => 'User(id: $id, username: $username, name: $displayName)';
}

/// Classes pour la gestion des résultats et erreurs
class MessagingResult<T> {
  final T? data;
  final MessagingError? error;
  final bool isSuccess;

  const MessagingResult._({
    this.data,
    this.error,
    required this.isSuccess,
  });

  factory MessagingResult.success(T data) {
    return MessagingResult._(
      data: data,
      isSuccess: true,
    );
  }

  factory MessagingResult.failure(MessagingError error) {
    return MessagingResult._(
      error: error,
      isSuccess: false,
    );
  }
}

class MessagingError {
  final String message;
  final int? statusCode;
  final MessagingErrorType type;

  const MessagingError({
    required this.message,
    this.statusCode,
    required this.type,
  });

  factory MessagingError.network() {
    return const MessagingError(
      message: 'Problème de connexion. Vérifiez votre réseau.',
      type: MessagingErrorType.network,
    );
  }

  factory MessagingError.validation(String message) {
    return MessagingError(
      message: message,
      type: MessagingErrorType.validation,
    );
  }

  factory MessagingError.unauthorized() {
    return const MessagingError(
      message: 'Vous devez vous connecter pour accéder à la messagerie.',
      type: MessagingErrorType.authentication,
      statusCode: 401,
    );
  }

  factory MessagingError.forbidden() {
    return const MessagingError(
      message: 'Vous n\'avez pas l\'autorisation d\'accéder à cette conversation.',
      type: MessagingErrorType.authorization,
      statusCode: 403,
    );
  }

  factory MessagingError.notFound() {
    return const MessagingError(
      message: 'Conversation ou message introuvable.',
      type: MessagingErrorType.notFound,
      statusCode: 404,
    );
  }

  factory MessagingError.fromApiResponse(String message, int? statusCode) {
    switch (statusCode) {
      case 400:
        return MessagingError(
          message: message,
          statusCode: statusCode,
          type: MessagingErrorType.validation,
        );
      case 401:
        return MessagingError.unauthorized();
      case 403:
        return MessagingError.forbidden();
      case 404:
        return MessagingError.notFound();
      case 500:
      case 502:
      case 503:
        return MessagingError(
          message: 'Erreur serveur. Veuillez réessayer plus tard.',
          statusCode: statusCode,
          type: MessagingErrorType.server,
        );
      default:
        return MessagingError(
          message: message,
          statusCode: statusCode,
          type: MessagingErrorType.unknown,
        );
    }
  }

  @override
  String toString() => 'MessagingError(type: $type, message: $message, code: $statusCode)';
}

enum MessagingErrorType {
  network,
  validation,
  authentication,
  authorization,
  notFound,
  server,
  unknown,
}