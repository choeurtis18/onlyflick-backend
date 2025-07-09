// /lib/core//services/messaging_service.dart
import 'package:flutter/foundation.dart';
import '../../../core/services/api_service.dart';
import '../models/message_models.dart';

/// Service pour la messagerie adapté à votre backend Go OnlyFlick
class MessagingService {
  final ApiService _apiService = ApiService();

  /// Récupérer toutes les conversations de l'utilisateur connecté
  /// Backend: GET /conversations -> handler.GetMyConversations
Future<MessagingResult<List<Conversation>>> getMyConversations() async {
  try {
    debugPrint('💬 Fetching user conversations...');
    
    final response = await _apiService.get('/conversations');

    debugPrint('🔍 RESPONSE DEBUG:');
    debugPrint('Success: ${response.isSuccess}');
    debugPrint('Status Code: ${response.statusCode}');
    debugPrint('Data Type: ${response.data?.runtimeType}');
    debugPrint('Data Content: ${response.data}');

    if (response.isSuccess && response.data != null) {
      final responseData = response.data;
      List<Conversation> conversations = [];
      
      debugPrint('🔍 PARSING CONVERSATIONS:');
      
      // Votre backend retourne probablement directement une liste de conversations
      if (responseData is List) {
        debugPrint('✅ Response is List with ${responseData.length} items');
        
        for (int i = 0; i < responseData.length; i++) {
          final item = responseData[i];
          debugPrint('--- CONVERSATION $i ---');
          debugPrint('Type: ${item.runtimeType}');
          
          if (item is Map<String, dynamic>) {
            debugPrint('Keys available: ${item.keys.toList()}');
            
            // Debug chaque champ important
            debugPrint('  id: ${item['id']} (${item['id']?.runtimeType})');
            debugPrint('  user1_id: ${item['user1_id']} (${item['user1_id']?.runtimeType})');
            debugPrint('  user2_id: ${item['user2_id']} (${item['user2_id']?.runtimeType})');
            debugPrint('  created_at: ${item['created_at']} (${item['created_at']?.runtimeType})');
            debugPrint('  updated_at: ${item['updated_at']} (${item['updated_at']?.runtimeType})');
            
            // Champs utilisateur (probablement manquants)
            debugPrint('  other_user_username: ${item['other_user_username']} (${item['other_user_username']?.runtimeType})');
            debugPrint('  other_user_first_name: ${item['other_user_first_name']} (${item['other_user_first_name']?.runtimeType})');
            debugPrint('  other_user_last_name: ${item['other_user_last_name']} (${item['other_user_last_name']?.runtimeType})');
            debugPrint('  other_user_avatar: ${item['other_user_avatar']} (${item['other_user_avatar']?.runtimeType})');
            
            // Dernier message (probablement manquant)
            debugPrint('  last_message: ${item['last_message']} (${item['last_message']?.runtimeType})');
            debugPrint('  unread_count: ${item['unread_count']} (${item['unread_count']?.runtimeType})');
            
            // Autres champs possibles
            item.forEach((key, value) {
              if (!['id', 'user1_id', 'user2_id', 'created_at', 'updated_at', 
                    'other_user_username', 'other_user_first_name', 'other_user_last_name', 
                    'other_user_avatar', 'last_message', 'unread_count'].contains(key)) {
                debugPrint('  $key: $value (${value?.runtimeType})');
              }
            });
            
            try {
              final conversation = Conversation.fromJson(item);
              conversations.add(conversation);
              debugPrint('✅ Conversation $i parsed successfully');
              debugPrint('    Display name: ${conversation.otherUserDisplayName}');
              debugPrint('    Has last message: ${conversation.lastMessage != null}');
              debugPrint('    Unread count: ${conversation.unreadCount}');
            } catch (e) {
              debugPrint('❌ Failed to parse conversation $i: $e');
            }
          } else {
            debugPrint('❌ Item $i is not a Map: ${item.runtimeType}');
          }
        }
      } else if (responseData is Map<String, dynamic>) {
        debugPrint('Response is Map, looking for conversations inside...');
        // Si emballé dans un objet
        if (responseData['conversations'] is List) {
          final conversationsList = responseData['conversations'] as List;
          conversations = conversationsList
              .map((item) => Conversation.fromJson(item as Map<String, dynamic>))
              .toList();
        } else if (responseData['data'] is List) {
          final conversationsList = responseData['data'] as List;
          conversations = conversationsList
              .map((item) => Conversation.fromJson(item as Map<String, dynamic>))
              .toList();
        }
      }
      
      debugPrint('💬 Successfully parsed ${conversations.length} conversations');
      return MessagingResult.success(conversations);
    } else {
      debugPrint('❌ Failed to fetch conversations: ${response.error}');
      return MessagingResult.failure(
        MessagingError.fromApiResponse(
          response.error ?? 'Erreur lors de la récupération des conversations',
          response.statusCode,
        ),
      );
    }
  } catch (e) {
    debugPrint('❌ Error fetching conversations: $e');
    return MessagingResult.failure(MessagingError.network());
  }
}

  /// Récupérer les messages d'une conversation spécifique
  /// Backend: GET /conversations/{id}/messages -> handler.GetMessagesInConversation
  Future<MessagingResult<List<Message>>> getMessagesInConversation(int conversationId) async {
    try {
      debugPrint('💬 Fetching messages for conversation $conversationId...');
      
      final response = await _apiService.get('/conversations/$conversationId/messages');

      if (response.isSuccess && response.data != null) {
        final responseData = response.data;
        List<Message> messages = [];
        
        // Votre backend retourne probablement directement une liste de messages
        if (responseData is List) {
          messages = responseData
              .map((item) => Message.fromJson(item as Map<String, dynamic>))
              .toList();
        } else if (responseData is Map<String, dynamic>) {
          // Si emballé dans un objet
          if (responseData['messages'] is List) {
            final messagesList = responseData['messages'] as List;
            messages = messagesList
                .map((item) => Message.fromJson(item as Map<String, dynamic>))
                .toList();
          } else if (responseData['data'] is List) {
            final messagesList = responseData['data'] as List;
            messages = messagesList
                .map((item) => Message.fromJson(item as Map<String, dynamic>))
                .toList();
          }
        }
        
        debugPrint('💬 Successfully fetched ${messages.length} messages');
        return MessagingResult.success(messages);
      } else {
        debugPrint('❌ Failed to fetch messages: ${response.error}');
        return MessagingResult.failure(
          MessagingError.fromApiResponse(
            response.error ?? 'Erreur lors de la récupération des messages',
            response.statusCode,
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Error fetching messages: $e');
      return MessagingResult.failure(MessagingError.network());
    }
  }

  /// Envoyer un message dans une conversation
  /// Backend: POST /conversations/{id}/messages -> handler.SendMessageInConversation
  Future<MessagingResult<Message>> sendMessage(int conversationId, String content) async {
    try {
      debugPrint('💬 Sending message to conversation $conversationId...');
      
      if (content.trim().isEmpty) {
        return MessagingResult.failure(
          MessagingError.validation('Le message ne peut pas être vide')
        );
      }

      final response = await _apiService.post(
        '/conversations/$conversationId/messages',
        body: {'content': content.trim()},
      );

      if (response.isSuccess && response.data != null) {
        final responseData = response.data;
        Message message;
        
        // Votre backend retourne probablement directement le message créé
        if (responseData is Map<String, dynamic>) {
          // Si c'est directement le message
          if (responseData.containsKey('id') && responseData.containsKey('content')) {
            message = Message.fromJson(responseData);
          }
          // Si emballé dans un objet
          else if (responseData['message'] != null) {
            message = Message.fromJson(responseData['message'] as Map<String, dynamic>);
          }
          else if (responseData['data'] != null) {
            message = Message.fromJson(responseData['data'] as Map<String, dynamic>);
          }
          else {
            throw Exception('Format de réponse inattendu pour l\'envoi de message');
          }
        } else {
          throw Exception('Format de réponse inattendu : ${responseData.runtimeType}');
        }
        
        debugPrint('💬 Message sent successfully');
        return MessagingResult.success(message);
      } else {
        debugPrint('❌ Failed to send message: ${response.error}');
        return MessagingResult.failure(
          MessagingError.fromApiResponse(
            response.error ?? 'Erreur lors de l\'envoi du message',
            response.statusCode,
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Error sending message: $e');
      return MessagingResult.failure(MessagingError.network());
    }
  }

  /// Démarrer une nouvelle conversation avec un utilisateur
  /// Backend: POST /conversations/{receiverId} -> handler.StartConversation
  Future<MessagingResult<Conversation>> createConversation(int otherUserId) async {
    try {
      debugPrint('💬 Creating conversation with user $otherUserId...');
      
      final response = await _apiService.post('/conversations/$otherUserId');

      if (response.isSuccess && response.data != null) {
        final responseData = response.data;
        Conversation conversation;
        
        if (responseData is Map<String, dynamic>) {
          // Si c'est directement la conversation
          if (responseData.containsKey('id')) {
            conversation = Conversation.fromJson(responseData);
          }
          // Si emballé dans un objet
          else if (responseData['conversation'] != null) {
            conversation = Conversation.fromJson(responseData['conversation'] as Map<String, dynamic>);
          }
          else if (responseData['data'] != null) {
            conversation = Conversation.fromJson(responseData['data'] as Map<String, dynamic>);
          }
          else {
            throw Exception('Format de réponse inattendu pour la création de conversation');
          }
        } else {
          throw Exception('Format de réponse inattendu : ${responseData.runtimeType}');
        }
        
        debugPrint('💬 Conversation created successfully');
        return MessagingResult.success(conversation);
      } else {
        debugPrint('❌ Failed to create conversation: ${response.error}');
        return MessagingResult.failure(
          MessagingError.fromApiResponse(
            response.error ?? 'Erreur lors de la création de la conversation',
            response.statusCode,
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Error creating conversation: $e');
      return MessagingResult.failure(MessagingError.network());
    }
  }

  /// Rechercher des utilisateurs pour démarrer une conversation
  /// NOTE: Cette fonctionnalité pourrait ne pas exister dans votre backend actuel
  /// Vous pourriez avoir besoin d'ajouter cet endpoint en Go
  Future<MessagingResult<List<User>>> searchUsers(String query) async {
    try {
      debugPrint('💬 Searching users with query: $query');
      
      if (query.trim().isEmpty) {
        return MessagingResult.success(<User>[]);
      }

      // Endpoint qui pourrait ne pas exister - à vérifier/créer dans votre backend
      final response = await _apiService.get(
        '/users/search',
        queryParams: {'q': query.trim()},
      );

      if (response.isSuccess && response.data != null) {
        final responseData = response.data;
        List<User> users = [];
        
        if (responseData is List) {
          users = responseData
              .map((item) => User.fromJson(item as Map<String, dynamic>))
              .toList();
        } else if (responseData is Map<String, dynamic>) {
          if (responseData['users'] is List) {
            final usersList = responseData['users'] as List;
            users = usersList
                .map((item) => User.fromJson(item as Map<String, dynamic>))
                .toList();
          } else if (responseData['data'] is List) {
            final usersList = responseData['data'] as List;
            users = usersList
                .map((item) => User.fromJson(item as Map<String, dynamic>))
                .toList();
          }
        }
        
        debugPrint('💬 Found ${users.length} users');
        return MessagingResult.success(users);
      } else {
        debugPrint('❌ Failed to search users: ${response.error}');
        return MessagingResult.failure(
          MessagingError.fromApiResponse(
            response.error ?? 'Erreur lors de la recherche d\'utilisateurs',
            response.statusCode,
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Error searching users: $e');
      return MessagingResult.failure(MessagingError.network());
    }
  }

  /// Marquer une conversation comme lue
  /// NOTE: Cette fonctionnalité pourrait ne pas exister dans votre backend actuel
  /// Vous pourriez avoir besoin d'ajouter cet endpoint en Go
  Future<MessagingResult<void>> markConversationAsRead(int conversationId) async {
    try {
      debugPrint('💬 Marking conversation $conversationId as read...');
      
      // Endpoint qui pourrait ne pas exister - à vérifier/créer dans votre backend
      final response = await _apiService.patch(
        '/conversations/$conversationId/read',
        body: {},
      );

      if (response.isSuccess) {
        debugPrint('💬 Conversation marked as read');
        return MessagingResult.success(null);
      } else {
        debugPrint('❌ Failed to mark conversation as read: ${response.error}');
        return MessagingResult.failure(
          MessagingError.fromApiResponse(
            response.error ?? 'Erreur lors du marquage comme lu',
            response.statusCode,
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Error marking conversation as read: $e');
      return MessagingResult.failure(MessagingError.network());
    }
  }

  /// Obtenir les utilisateurs pour la recherche (alternative si /users/search n'existe pas)
  /// Utilise une approche différente selon ce qui est disponible dans votre backend
  Future<MessagingResult<List<User>>> searchUsersAlternative(String query) async {
    try {
      debugPrint('💬 Alternative user search with query: $query');
      
      if (query.trim().isEmpty) {
        return MessagingResult.success(<User>[]);
      }

      // Alternatives possibles selon votre backend :
      // 1. Endpoint utilisateurs général avec filtrage côté client
      // 2. Endpoint spécifique pour la messagerie
      // 3. Autre approche selon votre architecture
      
      final response = await _apiService.get('/users'); // À adapter selon votre API
      
      if (response.isSuccess && response.data != null) {
        final responseData = response.data;
        List<User> allUsers = [];
        
        if (responseData is List) {
          allUsers = responseData
              .map((item) => User.fromJson(item as Map<String, dynamic>))
              .toList();
        } else if (responseData is Map<String, dynamic> && responseData['users'] is List) {
          final usersList = responseData['users'] as List;
          allUsers = usersList
              .map((item) => User.fromJson(item as Map<String, dynamic>))
              .toList();
        }
        
        // Filtrage côté client
        final filteredUsers = allUsers.where((user) {
          final searchTerm = query.toLowerCase();
          return user.username.toLowerCase().contains(searchTerm) ||
                 user.firstName.toLowerCase().contains(searchTerm) ||
                 user.lastName.toLowerCase().contains(searchTerm) ||
                 user.email.toLowerCase().contains(searchTerm);
        }).toList();
        
        debugPrint('💬 Found ${filteredUsers.length} users (filtered from ${allUsers.length})');
        return MessagingResult.success(filteredUsers);
      } else {
        debugPrint('❌ Failed to get users for search: ${response.error}');
        return MessagingResult.failure(
          MessagingError.fromApiResponse(
            response.error ?? 'Erreur lors de la recherche d\'utilisateurs',
            response.statusCode,
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Error in alternative user search: $e');
      return MessagingResult.failure(MessagingError.network());
    }
  }
}

/*
📝 NOTES SUR L'ADAPTATION À VOTRE BACKEND :

✅ ENDPOINTS EXISTANTS DANS VOTRE BACKEND :
- GET /conversations (GetMyConversations)
- GET /conversations/{id}/messages (GetMessagesInConversation) 
- POST /conversations/{id}/messages (SendMessageInConversation)
- POST /conversations/{receiverId} (StartConversation)

❓ ENDPOINTS QUI POURRAIENT MANQUER :
- GET /users/search (pour rechercher des utilisateurs)
- PATCH /conversations/{id}/read (pour marquer comme lu)

🔧 ACTIONS À PRENDRE :
1. Testez d'abord avec les endpoints existants
2. Si /users/search n'existe pas, utilisez searchUsersAlternative()
3. Si /conversations/{id}/read n'existe pas, commentez temporairement cette fonctionnalité

📊 ADAPTATIONS FAITES :
- Utilisation de vos vraies routes API
- Gestion flexible des formats de réponse JSON
- Méthodes alternatives pour les fonctionnalités manquantes
- Logs détaillés pour faciliter le débogage
*/