// onlyflick-app/lib/features/messaging/providers/messaging_provider.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import '../services/messaging_service.dart';
import '../services/websocket_service.dart';
import '../models/message_models.dart';

/// Provider pour gérer l'état de la messagerie avec WebSocket temps réel
class MessagingProvider extends ChangeNotifier {
  final MessagingService _messagingService = MessagingService();
  final WebSocketService _webSocketService = WebSocketService();

  // Subscriptions pour les streams WebSocket
  StreamSubscription<Message>? _messageSubscription;
  StreamSubscription<WebSocketEvent>? _eventSubscription;

  // État des conversations
  List<Conversation> _conversations = [];
  bool _isLoadingConversations = false;
  MessagingError? _conversationsError;

  // État des messages pour la conversation active
  Map<int, List<Message>> _messagesCache = {};
  int? _activeConversationId;
  bool _isLoadingMessages = false;
  MessagingError? _messagesError;

  // État de l'envoi de messages
  bool _isSendingMessage = false;
  MessagingError? _sendMessageError;

  // État de la recherche d'utilisateurs
  List<User> _searchResults = [];
  bool _isSearchingUsers = false;
  String _lastSearchQuery = '';

  // État WebSocket
  bool _isWebSocketConnected = false;
  Map<int, Set<int>> _typingUsers = {}; // conversationId -> Set d'userIds qui tapent
  Timer? _typingTimer;

  // Getters pour l'état des conversations
  List<Conversation> get conversations => List.unmodifiable(_conversations);
  bool get isLoadingConversations => _isLoadingConversations;
  MessagingError? get conversationsError => _conversationsError;

  // Getters pour l'état des messages
  List<Message> get activeMessages {
    if (_activeConversationId == null) return [];
    return List.unmodifiable(_messagesCache[_activeConversationId] ?? []);
  }
  
  int? get activeConversationId => _activeConversationId;
  bool get isLoadingMessages => _isLoadingMessages;
  MessagingError? get messagesError => _messagesError;
  bool get isSendingMessage => _isSendingMessage;
  MessagingError? get sendMessageError => _sendMessageError;

  // Getters pour la recherche
  List<User> get searchResults => List.unmodifiable(_searchResults);
  bool get isSearchingUsers => _isSearchingUsers;
  String get lastSearchQuery => _lastSearchQuery;

  // Getters pour WebSocket et temps réel
  bool get isWebSocketConnected => _isWebSocketConnected;
  
  /// Obtient la liste des utilisateurs qui tapent dans une conversation
  Set<int> getTypingUsers(int conversationId) {
    return Set.unmodifiable(_typingUsers[conversationId] ?? {});
  }

  /// Constructeur qui initialise les subscriptions WebSocket
  MessagingProvider() {
    _initializeWebSocket();
  }

  /// Initialise les subscriptions WebSocket
  void _initializeWebSocket() {
    // Écouter les nouveaux messages en temps réel
    _messageSubscription = _webSocketService.messageStream.listen(
      _handleRealtimeMessage,
      onError: (error) => debugPrint('❌ WebSocket message stream error: $error'),
    );

    // Écouter les événements WebSocket
    _eventSubscription = _webSocketService.eventStream.listen(
      _handleWebSocketEvent,
      onError: (error) => debugPrint('❌ WebSocket event stream error: $error'),
    );
  }

  /// Gère les messages reçus en temps réel
  void _handleRealtimeMessage(Message message) {
    debugPrint('💬 Realtime message received for conversation ${message.conversationId}');
    
    // Ajouter le message à la cache locale
    final currentMessages = _messagesCache[message.conversationId] ?? [];
    _messagesCache[message.conversationId] = [...currentMessages, message];
    
    // Mettre à jour la conversation dans la liste
    _updateConversationWithNewMessage(message);
    
    notifyListeners();
  }

  /// Gère les événements WebSocket
  void _handleWebSocketEvent(WebSocketEvent event) {
    switch (event.type) {
      case WebSocketEventType.connected:
        _isWebSocketConnected = true;
        debugPrint('✅ WebSocket connected');
        // Rejoindre la conversation active si elle existe
        if (_activeConversationId != null) {
          _webSocketService.joinConversation(_activeConversationId!);
        }
        break;
        
      case WebSocketEventType.disconnected:
        _isWebSocketConnected = false;
        debugPrint('❌ WebSocket disconnected');
        break;
        
      case WebSocketEventType.userTyping:
        if (event.conversationId != null && event.userId != null && event.isTyping != null) {
          _handleUserTyping(event.conversationId!, event.userId!, event.isTyping!);
        }
        break;
        
      case WebSocketEventType.error:
        debugPrint('❌ WebSocket error: ${event.message}');
        break;
        
      default:
        debugPrint('📡 WebSocket event: ${event.type}');
    }
    notifyListeners();
  }

  /// Gère les indicateurs de frappe
  void _handleUserTyping(int conversationId, int userId, bool isTyping) {
    if (conversationId != _activeConversationId) return;
    
    _typingUsers[conversationId] ??= <int>{};
    
    if (isTyping) {
      _typingUsers[conversationId]!.add(userId);
    } else {
      _typingUsers[conversationId]!.remove(userId);
    }
    
    notifyListeners();
  }

  /// Connecte le WebSocket (appelé après login)
  Future<void> connectWebSocket() async {
    debugPrint('🔌 Connecting WebSocket...');
    await _webSocketService.connect();
  }

  /// Déconnecte le WebSocket (appelé lors du logout)
  Future<void> disconnectWebSocket() async {
    debugPrint('🔌 Disconnecting WebSocket...');
    await _webSocketService.disconnect();
    _isWebSocketConnected = false;
    _typingUsers.clear();
    notifyListeners();
  }
  Future<void> loadConversations() async {
    if (_isLoadingConversations) return;

    _isLoadingConversations = true;
    _conversationsError = null;
    notifyListeners();

    try {
      final result = await _messagingService.getMyConversations();
      
      if (result.isSuccess && result.data != null) {
        _conversations = result.data!;
        _conversationsError = null;
        debugPrint('💬 Loaded ${_conversations.length} conversations');
      } else {
        _conversationsError = result.error;
        debugPrint('❌ Failed to load conversations: ${result.error?.message}');
      }
    } catch (e) {
      _conversationsError = MessagingError(
        message: 'Erreur inattendue lors du chargement des conversations',
        type: MessagingErrorType.unknown,
      );
      debugPrint('❌ Unexpected error loading conversations: $e');
    } finally {
      _isLoadingConversations = false;
      notifyListeners();
    }
  }

  /// Charge les messages d'une conversation spécifique
  Future<void> loadMessages(int conversationId) async {
    if (_isLoadingMessages) return;

    // Quitter la conversation précédente si WebSocket connecté
    if (_activeConversationId != null && _isWebSocketConnected) {
      _webSocketService.leaveConversation(_activeConversationId!);
    }

    _activeConversationId = conversationId;
    _isLoadingMessages = true;
    _messagesError = null;
    notifyListeners();

    try {
      final result = await _messagingService.getMessagesInConversation(conversationId);
      
      if (result.isSuccess && result.data != null) {
        _messagesCache[conversationId] = result.data!;
        _messagesError = null;
        debugPrint('💬 Loaded ${result.data!.length} messages for conversation $conversationId');
        
        // Rejoindre la conversation via WebSocket si connecté
        if (_isWebSocketConnected) {
          _webSocketService.joinConversation(conversationId);
        }
        
        // Marquer la conversation comme lue
        _markConversationAsRead(conversationId);
      } else {
        _messagesError = result.error;
        debugPrint('❌ Failed to load messages: ${result.error?.message}');
      }
    } catch (e) {
      _messagesError = MessagingError(
        message: 'Erreur inattendue lors du chargement des messages',
        type: MessagingErrorType.unknown,
      );
      debugPrint('❌ Unexpected error loading messages: $e');
    } finally {
      _isLoadingMessages = false;
      notifyListeners();
    }
  }

  /// Envoie un message dans la conversation active
  Future<bool> sendMessage(String content) async {
    if (_activeConversationId == null || _isSendingMessage) return false;

    _isSendingMessage = true;
    _sendMessageError = null;
    notifyListeners();

    try {
      final result = await _messagingService.sendMessage(_activeConversationId!, content);
      
      if (result.isSuccess && result.data != null) {
        // Ajouter le message à la cache locale
        final currentMessages = _messagesCache[_activeConversationId!] ?? [];
        _messagesCache[_activeConversationId!] = [...currentMessages, result.data!];
        
        // Mettre à jour la conversation dans la liste (dernier message)
        _updateConversationWithNewMessage(result.data!);
        
        _sendMessageError = null;
        debugPrint('💬 Message sent successfully');
        notifyListeners();
        return true;
      } else {
        _sendMessageError = result.error;
        debugPrint('❌ Failed to send message: ${result.error?.message}');
        notifyListeners();
        return false;
      }
    } catch (e) {
      _sendMessageError = MessagingError(
        message: 'Erreur inattendue lors de l\'envoi du message',
        type: MessagingErrorType.unknown,
      );
      debugPrint('❌ Unexpected error sending message: $e');
      notifyListeners();
      return false;
    } finally {
      _isSendingMessage = false;
      notifyListeners();
    }
  }

  /// Recherche des utilisateurs pour démarrer une conversation
  Future<void> searchUsers(String query) async {
    if (_isSearchingUsers || query.trim() == _lastSearchQuery) return;

    _lastSearchQuery = query.trim();
    _isSearchingUsers = true;
    notifyListeners();

    try {
      final result = await _messagingService.searchUsers(query);
      
      if (result.isSuccess && result.data != null) {
        _searchResults = result.data!;
        debugPrint('💬 Found ${_searchResults.length} users for "$query"');
      } else {
        _searchResults = [];
        debugPrint('❌ Failed to search users: ${result.error?.message}');
      }
    } catch (e) {
      _searchResults = [];
      debugPrint('❌ Unexpected error searching users: $e');
    } finally {
      _isSearchingUsers = false;
      notifyListeners();
    }
  }

  /// Démarre une nouvelle conversation avec un utilisateur
  Future<bool> startConversation(int otherUserId) async {
    try {
      final result = await _messagingService.createConversation(otherUserId);
      
      if (result.isSuccess && result.data != null) {
        // Ajouter la nouvelle conversation à la liste
        _conversations.insert(0, result.data!);
        
        // L'activer immédiatement
        _activeConversationId = result.data!.id;
        _messagesCache[result.data!.id] = [];
        
        debugPrint('💬 Started conversation with user $otherUserId');
        notifyListeners();
        return true;
      } else {
        debugPrint('❌ Failed to start conversation: ${result.error?.message}');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Unexpected error starting conversation: $e');
      return false;
    }
  }

  /// Actualise les données (conversations et messages actifs)
  Future<void> refresh() async {
    await loadConversations();
    if (_activeConversationId != null) {
      await loadMessages(_activeConversationId!);
    }
  }

  /// Efface la conversation active
  void clearActiveConversation() {
    // Quitter la conversation WebSocket si connectée
    if (_activeConversationId != null && _isWebSocketConnected) {
      _webSocketService.leaveConversation(_activeConversationId!);
    }
    
    _activeConversationId = null;
    _messagesError = null;
    _sendMessageError = null;
    notifyListeners();
  }

  /// Envoie un indicateur de frappe
  void sendTypingIndicator(bool isTyping) {
    if (_activeConversationId != null && _isWebSocketConnected) {
      _webSocketService.sendTypingIndicator(_activeConversationId!, isTyping);
      
      // Arrêter automatiquement l'indicateur après 3 secondes
      if (isTyping) {
        _typingTimer?.cancel();
        _typingTimer = Timer(const Duration(seconds: 3), () {
          if (_activeConversationId != null && _isWebSocketConnected) {
            _webSocketService.sendTypingIndicator(_activeConversationId!, false);
          }
        });
      } else {
        _typingTimer?.cancel();
      }
    }
  }

  /// Efface les résultats de recherche
  void clearSearchResults() {
    _searchResults = [];
    _lastSearchQuery = '';
    notifyListeners();
  }

  /// Obtient une conversation par son ID
  Conversation? getConversationById(int conversationId) {
    try {
      return _conversations.firstWhere((conv) => conv.id == conversationId);
    } catch (e) {
      return null;
    }
  }

  /// Obtient le nombre total de messages non lus
  int get totalUnreadCount {
    return _conversations.fold(0, (total, conv) => total + conv.unreadCount);
  }

  /// Met à jour une conversation avec un nouveau message
  void _updateConversationWithNewMessage(Message message) {
    final conversationIndex = _conversations.indexWhere(
      (conv) => conv.id == message.conversationId,
    );
    
    if (conversationIndex != -1) {
      final conversation = _conversations[conversationIndex];
      final updatedConversation = Conversation(
        id: conversation.id,
        user1Id: conversation.user1Id,
        user2Id: conversation.user2Id,
        createdAt: conversation.createdAt,
        updatedAt: message.createdAt,
        otherUserUsername: conversation.otherUserUsername,
        otherUserFirstName: conversation.otherUserFirstName,
        otherUserLastName: conversation.otherUserLastName,
        otherUserAvatar: conversation.otherUserAvatar,
        lastMessage: message,
        unreadCount: 0, // Si on vient d'envoyer, pas de non-lus
      );
      
      // Déplacer la conversation en haut de la liste
      _conversations.removeAt(conversationIndex);
      _conversations.insert(0, updatedConversation);
    }
  }

  /// Marque une conversation comme lue (appel en arrière-plan)
  Future<void> _markConversationAsRead(int conversationId) async {
    try {
      await _messagingService.markConversationAsRead(conversationId);
      
      // Mettre à jour localement
      final conversationIndex = _conversations.indexWhere(
        (conv) => conv.id == conversationId,
      );
      
      if (conversationIndex != -1) {
        final conversation = _conversations[conversationIndex];
        if (conversation.unreadCount > 0) {
          final updatedConversation = Conversation(
            id: conversation.id,
            user1Id: conversation.user1Id,
            user2Id: conversation.user2Id,
            createdAt: conversation.createdAt,
            updatedAt: conversation.updatedAt,
            otherUserUsername: conversation.otherUserUsername,
            otherUserFirstName: conversation.otherUserFirstName,
            otherUserLastName: conversation.otherUserLastName,
            otherUserAvatar: conversation.otherUserAvatar,
            lastMessage: conversation.lastMessage,
            unreadCount: 0,
          );
          
          _conversations[conversationIndex] = updatedConversation;
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('❌ Failed to mark conversation as read: $e');
      // Ne pas faire échouer l'opération pour cela
    }
  }

  @override
  void dispose() {
    // Nettoyer les ressources WebSocket
    _messageSubscription?.cancel();
    _eventSubscription?.cancel();
    _typingTimer?.cancel();
    _webSocketService.dispose();
    
    // Nettoyer le reste
    _conversations.clear();
    _messagesCache.clear();
    _searchResults.clear();
    _typingUsers.clear();
    
    super.dispose();
  }
}