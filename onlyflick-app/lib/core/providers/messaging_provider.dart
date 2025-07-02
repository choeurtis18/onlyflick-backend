// onlyflick-app/lib/core/providers/messaging_provider.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import '../services/messaging_service.dart';
import '../services/websocket_service.dart';
import '../services/api_service.dart';
import '../models/message_models.dart' as models;

/// Provider pour gérer l'état de la messagerie avec WebSocket temps réel
class MessagingProvider extends ChangeNotifier {
  final MessagingService _messagingService = MessagingService();
  final WebSocketService _webSocketService = WebSocketService();

  // Subscriptions pour les streams WebSocket
  StreamSubscription<models.Message>? _messageSubscription;
  StreamSubscription<WebSocketEvent>? _eventSubscription;

  // État des conversations
  List<models.Conversation> _conversations = [];
  bool _isLoadingConversations = false;
  models.MessagingError? _conversationsError;

  // État des messages pour la conversation active
  Map<int, List<models.Message>> _messagesCache = {};
  int? _activeConversationId;
  bool _isLoadingMessages = false;
  models.MessagingError? _messagesError;

  // État de l'envoi de messages
  bool _isSendingMessage = false;
  models.MessagingError? _sendMessageError;

  // État de la recherche d'utilisateurs
  List<models.User> _searchResults = [];
  bool _isSearchingUsers = false;
  String _lastSearchQuery = '';

  // État WebSocket
  bool _isWebSocketConnected = false;
  bool _isWebSocketConnecting = false;
  Map<int, Set<int>> _typingUsers = {}; // conversationId -> Set d'userIds qui tapent
  Timer? _typingTimer;
  bool _isCurrentlyTyping = false; // Protection contre les boucles

  // Getters pour l'état des conversations
  List<models.Conversation> get conversations => List.unmodifiable(_conversations);
  bool get isLoadingConversations => _isLoadingConversations;
  models.MessagingError? get conversationsError => _conversationsError;

  // Getters pour l'état des messages
  List<models.Message> get activeMessages {
    if (_activeConversationId == null) return [];
    return List.unmodifiable(_messagesCache[_activeConversationId] ?? []);
  }
  
  int? get activeConversationId => _activeConversationId;
  bool get isLoadingMessages => _isLoadingMessages;
  models.MessagingError? get messagesError => _messagesError;
  bool get isSendingMessage => _isSendingMessage;
  models.MessagingError? get sendMessageError => _sendMessageError;

  // Getters pour la recherche
  List<models.User> get searchResults => List.unmodifiable(_searchResults);
  bool get isSearchingUsers => _isSearchingUsers;
  String get lastSearchQuery => _lastSearchQuery;

  // Getters pour WebSocket et temps réel
  bool get isWebSocketConnected => _isWebSocketConnected;
  bool get isWebSocketConnecting => _isWebSocketConnecting;
  
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
    debugPrint('🔌 MessagingProvider: Initializing WebSocket subscriptions...');
    
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
    
    debugPrint('✅ MessagingProvider: WebSocket subscriptions initialized');
  }

  /// Connecte le WebSocket à une conversation spécifique
  Future<void> connectToConversation(int conversationId) async {
    if (_isWebSocketConnecting) {
      debugPrint('⏳ MessagingProvider: Already connecting to WebSocket, skipping...');
      return;
    }

    if (_isWebSocketConnected && _activeConversationId == conversationId) {
      debugPrint('✅ MessagingProvider: Already connected to conversation $conversationId');
      return;
    }

    try {
      _isWebSocketConnecting = true;
      notifyListeners();
      
      debugPrint('🔌 MessagingProvider: Connecting to conversation $conversationId...');
      
      // Se connecter au WebSocket pour cette conversation spécifique
      await _webSocketService.connectToConversation(conversationId);
      
      // Mettre à jour l'état local
      _isWebSocketConnected = true;
      _activeConversationId = conversationId;
      
      debugPrint('✅ MessagingProvider: Successfully connected to conversation $conversationId');
      
    } catch (e) {
      debugPrint('❌ MessagingProvider: Failed to connect to conversation $conversationId: $e');
      _isWebSocketConnected = false;
      // Ne pas changer _activeConversationId en cas d'erreur
      rethrow; // Permettre au UI de gérer l'erreur
    } finally {
      _isWebSocketConnecting = false;
      notifyListeners();
    }
  }

  /// Déconnecte le WebSocket de la conversation actuelle
  Future<void> disconnectFromConversation() async {
    try {
      debugPrint('🔌 MessagingProvider: Disconnecting from conversation...');
      await _webSocketService.disconnect();
      _isWebSocketConnected = false;
      _activeConversationId = null;
      _typingUsers.clear();
      debugPrint('✅ MessagingProvider: Disconnected from conversation');
      notifyListeners();
    } catch (e) {
      debugPrint('❌ MessagingProvider: Failed to disconnect: $e');
    }
  }

  /// Gère les messages reçus en temps réel (VERSION CORRIGÉE)
  void _handleRealtimeMessage(models.Message message) {
    debugPrint('💬 MessagingProvider: Realtime message received for conversation ${message.conversationId}');
    debugPrint('📋 MessagingProvider: Message ID: ${message.id}, Sender: ${message.senderId}, Content: "${message.content}"');
    
    // ✅ Filtrer les messages vides (déjà fait au niveau WebSocket, mais double sécurité)
    if (message.content.trim().isEmpty) {
      debugPrint('🗑️ MessagingProvider: Ignoring empty message (ID: ${message.id})');
      return;
    }
    
    // ✅ AMÉLIORATION: Ne plus ignorer automatiquement ses propres messages
    // Car cela peut causer des problèmes de synchronisation
    final currentUserId = ApiService().currentUserId;
    if (currentUserId != null && message.senderId == currentUserId) {
      debugPrint('🔄 MessagingProvider: Received own message via WebSocket (ID: ${message.id})');
      // Ne pas ignorer complètement, mais vérifier s'il existe déjà
    }
    
    // Vérifier si le message est pour la conversation active
    if (message.conversationId == _activeConversationId) {
      debugPrint('📨 MessagingProvider: Adding message to active conversation cache');
      
      // Vérifier si le message n'est pas déjà dans la cache (éviter doublons)
      final currentMessages = _messagesCache[message.conversationId] ?? [];
      final messageExists = currentMessages.any((m) => m.id == message.id);
      
      if (!messageExists) {
        // ✅ AMÉLIORATION: Insérer le message à la bonne position (par date)
        final updatedMessages = [...currentMessages, message];
        // Trier par date de création pour maintenir l'ordre chronologique
        updatedMessages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        
        _messagesCache[message.conversationId] = updatedMessages;
        debugPrint('✅ MessagingProvider: Message added to cache (total: ${updatedMessages.length})');
        
        // ✅ Force un rebuild immédiat de l'UI
        notifyListeners();
        
      } else {
        debugPrint('⚠️ MessagingProvider: Message ${message.id} already exists in cache, skipping');
        return; // Pas besoin de notifyListeners si rien n'a changé
      }
      
    } else if (message.conversationId != _activeConversationId) {
      debugPrint('📨 MessagingProvider: Message for inactive conversation ${message.conversationId}');
      
      // ✅ AMÉLIORATION: Même pour les conversations inactives, maintenir le cache
      final currentMessages = _messagesCache[message.conversationId] ?? [];
      final messageExists = currentMessages.any((m) => m.id == message.id);
      
      if (!messageExists) {
        final updatedMessages = [...currentMessages, message];
        updatedMessages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        _messagesCache[message.conversationId] = updatedMessages;
        debugPrint('✅ MessagingProvider: Message cached for inactive conversation');
      }
    }
    
    // Mettre à jour la conversation dans la liste (toujours)
    _updateConversationWithNewMessage(message);
    
    // ✅ Force un rebuild final pour s'assurer que l'UI se met à jour
    notifyListeners();
  }

  /// Gère les événements WebSocket
  void _handleWebSocketEvent(WebSocketEvent event) {
    debugPrint('📡 MessagingProvider: WebSocket event: ${event.type}');
    
    switch (event.type) {
      case WebSocketEventType.connected:
        _isWebSocketConnected = true;
        _isWebSocketConnecting = false;
        debugPrint('✅ MessagingProvider: WebSocket connected');
        break;
        
      case WebSocketEventType.disconnected:
        _isWebSocketConnected = false;
        _isWebSocketConnecting = false;
        debugPrint('❌ MessagingProvider: WebSocket disconnected');
        break;
        
      case WebSocketEventType.userTyping:
        if (event.conversationId != null && event.userId != null && event.isTyping != null) {
          _handleUserTyping(event.conversationId!, event.userId!, event.isTyping!);
        }
        break;
        
      case WebSocketEventType.messageDelivered:
        if (event.messageId != null) {
          debugPrint('✅ MessagingProvider: Message ${event.messageId} delivered');
        }
        break;
        
      case WebSocketEventType.messageRead:
        if (event.messageId != null) {
          debugPrint('👁️ MessagingProvider: Message ${event.messageId} read');
        }
        break;
        
      case WebSocketEventType.error:
        _isWebSocketConnected = false;
        _isWebSocketConnecting = false;
        debugPrint('❌ MessagingProvider: WebSocket error: ${event.message}');
        break;
        
      case WebSocketEventType.connecting:
        _isWebSocketConnecting = true;
        debugPrint('⏳ MessagingProvider: WebSocket connecting...');
        break;
        
      case WebSocketEventType.authenticationRequired:
        _isWebSocketConnected = false;
        _isWebSocketConnecting = false;
        debugPrint('🔐 MessagingProvider: WebSocket authentication required');
        break;
        
      default:
        debugPrint('📡 MessagingProvider: Unhandled WebSocket event: ${event.type}');
    }
    
    notifyListeners();
  }

  /// Gère les indicateurs de frappe
  void _handleUserTyping(int conversationId, int userId, bool isTyping) {
    debugPrint('⌨️ MessagingProvider: User $userId ${isTyping ? 'started' : 'stopped'} typing in conversation $conversationId');
    
    if (conversationId != _activeConversationId) {
      debugPrint('⌨️ MessagingProvider: Typing event for inactive conversation, ignoring');
      return;
    }
    
    _typingUsers[conversationId] ??= <int>{};
    
    if (isTyping) {
      _typingUsers[conversationId]!.add(userId);
    } else {
      _typingUsers[conversationId]!.remove(userId);
    }
    
    notifyListeners();
  }

  /// Charge les conversations de l'utilisateur
  Future<void> loadConversations() async {
    if (_isLoadingConversations) {
      debugPrint('⏳ MessagingProvider: Already loading conversations, skipping...');
      return;
    }

    _isLoadingConversations = true;
    _conversationsError = null;
    notifyListeners();

    try {
      debugPrint('📋 MessagingProvider: Loading conversations...');
      final result = await _messagingService.getMyConversations();
      
      if (result.isSuccess && result.data != null) {
        _conversations = result.data!;
        _conversationsError = null;
        debugPrint('✅ MessagingProvider: Loaded ${_conversations.length} conversations');
      } else {
        _conversationsError = result.error;
        debugPrint('❌ MessagingProvider: Failed to load conversations: ${result.error?.message}');
      }
    } catch (e) {
      _conversationsError = models.MessagingError(
        message: 'Erreur inattendue lors du chargement des conversations',
        type: models.MessagingErrorType.unknown,
      );
      debugPrint('❌ MessagingProvider: Unexpected error loading conversations: $e');
    } finally {
      _isLoadingConversations = false;
      notifyListeners();
    }
  }

  /// Charge les messages d'une conversation spécifique (VERSION CORRIGÉE)
  Future<void> loadMessages(int conversationId) async {
    if (_isLoadingMessages) {
      debugPrint('⏳ MessagingProvider: Already loading messages, skipping...');
      return;
    }

    _activeConversationId = conversationId;
    _isLoadingMessages = true;
    _messagesError = null;
    notifyListeners();

    try {
      debugPrint('💬 MessagingProvider: Loading messages for conversation $conversationId...');
      final result = await _messagingService.getMessagesInConversation(conversationId);
      
      if (result.isSuccess && result.data != null) {
        // ✅ CORRECTION: Filtrer les messages vides lors du chargement initial
        final filteredMessages = result.data!.where((message) {
          final hasContent = message.content.trim().isNotEmpty;
          if (!hasContent) {
            debugPrint('🗑️ MessagingProvider: Filtering out empty message from API (ID: ${message.id})');
          }
          return hasContent;
        }).toList();
        
        _messagesCache[conversationId] = filteredMessages;
        _messagesError = null;
        
        debugPrint('✅ MessagingProvider: Loaded ${result.data!.length} total messages');
        debugPrint('✅ MessagingProvider: Filtered to ${filteredMessages.length} non-empty messages for conversation $conversationId');
        
        // Marquer la conversation comme lue
        _markConversationAsRead(conversationId);
      } else {
        _messagesError = result.error;
        debugPrint('❌ MessagingProvider: Failed to load messages: ${result.error?.message}');
      }
    } catch (e) {
      _messagesError = models.MessagingError(
        message: 'Erreur inattendue lors du chargement des messages',
        type: models.MessagingErrorType.unknown,
      );
      debugPrint('❌ MessagingProvider: Unexpected error loading messages: $e');
    } finally {
      _isLoadingMessages = false;
      notifyListeners();
    }
  }

  /// Envoie un message dans la conversation active
  Future<bool> sendMessage(String content) async {
    if (_activeConversationId == null || _isSendingMessage) {
      debugPrint('❌ MessagingProvider: Cannot send message (no active conversation or already sending)');
      return false;
    }

    _isSendingMessage = true;
    _sendMessageError = null;
    notifyListeners();

    try {
      debugPrint('📤 MessagingProvider: Sending message to conversation $_activeConversationId...');
      final result = await _messagingService.sendMessage(_activeConversationId!, content);
      
      if (result.isSuccess && result.data != null) {
        // Ajouter le message à la cache locale immédiatement
        final currentMessages = _messagesCache[_activeConversationId!] ?? [];
        
        // Vérifier que le message n'existe pas déjà (éviter doublons avec WebSocket)
        final messageExists = currentMessages.any((m) => m.id == result.data!.id);
        
        if (!messageExists) {
          _messagesCache[_activeConversationId!] = [...currentMessages, result.data!];
          debugPrint('✅ MessagingProvider: Message sent and added to local cache (ID: ${result.data!.id})');
        } else {
          debugPrint('⚠️ MessagingProvider: Message already exists in cache (WebSocket faster than API)');
        }
        
        // Mettre à jour la conversation dans la liste (dernier message)
        _updateConversationWithNewMessage(result.data!);
        
        _sendMessageError = null;
        notifyListeners();
        return true;
      } else {
        _sendMessageError = result.error;
        debugPrint('❌ MessagingProvider: Failed to send message: ${result.error?.message}');
        notifyListeners();
        return false;
      }
    } catch (e) {
      _sendMessageError = models.MessagingError(
        message: 'Erreur inattendue lors de l\'envoi du message',
        type: models.MessagingErrorType.unknown,
      );
      debugPrint('❌ MessagingProvider: Unexpected error sending message: $e');
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
      debugPrint('🔍 MessagingProvider: Searching users for "$query"...');
      final result = await _messagingService.searchUsers(query);
      
      if (result.isSuccess && result.data != null) {
        _searchResults = result.data!;
        debugPrint('✅ MessagingProvider: Found ${_searchResults.length} users for "$query"');
      } else {
        _searchResults = [];
        debugPrint('❌ MessagingProvider: Failed to search users: ${result.error?.message}');
      }
    } catch (e) {
      _searchResults = [];
      debugPrint('❌ MessagingProvider: Unexpected error searching users: $e');
    } finally {
      _isSearchingUsers = false;
      notifyListeners();
    }
  }

  /// Démarre une nouvelle conversation avec un utilisateur
  Future<bool> startConversation(int otherUserId) async {
    try {
      debugPrint('💬 MessagingProvider: Starting conversation with user $otherUserId...');
      final result = await _messagingService.createConversation(otherUserId);
      
      if (result.isSuccess && result.data != null) {
        // Ajouter la nouvelle conversation à la liste
        _conversations.insert(0, result.data!);
        
        // L'activer immédiatement
        _activeConversationId = result.data!.id;
        _messagesCache[result.data!.id] = [];
        
        debugPrint('✅ MessagingProvider: Started conversation ${result.data!.id} with user $otherUserId');
        notifyListeners();
        return true;
      } else {
        debugPrint('❌ MessagingProvider: Failed to start conversation: ${result.error?.message}');
        return false;
      }
    } catch (e) {
      debugPrint('❌ MessagingProvider: Unexpected error starting conversation: $e');
      return false;
    }
  }

  /// Actualise les données (conversations et messages actifs)
  Future<void> refresh() async {
    debugPrint('🔄 MessagingProvider: Refreshing data...');
    await loadConversations();
    if (_activeConversationId != null) {
      await loadMessages(_activeConversationId!);
    }
  }

  /// Efface la conversation active
  void clearActiveConversation() {
    debugPrint('🧹 MessagingProvider: Clearing active conversation...');
    
    // Réinitialiser l'état de frappe
    _isCurrentlyTyping = false;
    _typingTimer?.cancel();
    
    // Déconnecter le WebSocket de la conversation
    if (_isWebSocketConnected) {
      disconnectFromConversation();
    }
    
    _activeConversationId = null;
    _messagesError = null;
    _sendMessageError = null;
    _typingUsers.clear();
    notifyListeners();
  }

  /// Envoie un indicateur de frappe
  void sendTypingIndicator(bool isTyping) {
    // Protection contre les boucles infinies
    if (_isCurrentlyTyping == isTyping) {
      debugPrint('⌨️ MessagingProvider: Typing indicator already in state $isTyping, skipping');
      return;
    }

    if (_activeConversationId != null && _isWebSocketConnected) {
      debugPrint('⌨️ MessagingProvider: Sending typing indicator: $isTyping for conversation $_activeConversationId');
      
      _isCurrentlyTyping = isTyping;
      _webSocketService.sendTypingIndicator(_activeConversationId!, isTyping);
      
      // Arrêter automatiquement l'indicateur après 3 secondes
      if (isTyping) {
        _typingTimer?.cancel();
        _typingTimer = Timer(const Duration(seconds: 3), () {
          if (_activeConversationId != null && _isWebSocketConnected && _isCurrentlyTyping) {
            debugPrint('⌨️ MessagingProvider: Auto-stopping typing indicator');
            _isCurrentlyTyping = false;
            _webSocketService.sendTypingIndicator(_activeConversationId!, false);
          }
        });
      } else {
        _typingTimer?.cancel();
        _isCurrentlyTyping = false;
      }
    } else {
      debugPrint('⌨️ MessagingProvider: Cannot send typing indicator (no active conversation or not connected)');
    }
  }

  /// Efface les résultats de recherche
  void clearSearchResults() {
    _searchResults = [];
    _lastSearchQuery = '';
    notifyListeners();
  }

  /// Obtient une conversation par son ID
  models.Conversation? getConversationById(int conversationId) {
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
  void _updateConversationWithNewMessage(models.Message message) {
    final conversationIndex = _conversations.indexWhere(
      (conv) => conv.id == message.conversationId,
    );
    
    if (conversationIndex != -1) {
      final conversation = _conversations[conversationIndex];
      final updatedConversation = models.Conversation(
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
        unreadCount: message.conversationId == _activeConversationId ? 0 : conversation.unreadCount + 1,
      );
      
      // Déplacer la conversation en haut de la liste
      _conversations.removeAt(conversationIndex);
      _conversations.insert(0, updatedConversation);
      
      debugPrint('🔄 MessagingProvider: Updated conversation ${message.conversationId} with new message');
    } else {
      debugPrint('⚠️ MessagingProvider: Could not find conversation ${message.conversationId} to update');
    }
  }

  /// Marque une conversation comme lue (appel en arrière-plan)
  Future<void> _markConversationAsRead(int conversationId) async {
    try {
      debugPrint('📖 MessagingProvider: Marking conversation $conversationId as read...');
      await _messagingService.markConversationAsRead(conversationId);
      debugPrint('✅ MessagingProvider: Successfully marked conversation $conversationId as read on server');
      
      // Mettre à jour localement si succès
      _updateLocalReadStatus(conversationId);
      
    } catch (e) {
      debugPrint('❌ MessagingProvider: Failed to mark conversation as read on server: $e');
      
      // Si c'est une 404, l'endpoint n'existe pas encore - mettre à jour localement quand même
      if (e.toString().contains('404') || e.toString().contains('page not found')) {
        debugPrint('🤷 MessagingProvider: Mark as read endpoint not implemented, updating locally only');
        _updateLocalReadStatus(conversationId);
      }
      // Pour les autres erreurs, ne pas mettre à jour localement
    }
  }

  /// Met à jour le statut de lecture localement
  void _updateLocalReadStatus(int conversationId) {
    final conversationIndex = _conversations.indexWhere(
      (conv) => conv.id == conversationId,
    );
    
    if (conversationIndex != -1) {
      final conversation = _conversations[conversationIndex];
      if (conversation.unreadCount > 0) {
        final updatedConversation = models.Conversation(
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
        debugPrint('✅ MessagingProvider: Updated local read status for conversation $conversationId');
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    debugPrint('🧹 MessagingProvider: Disposing...');
    
    // Nettoyer les ressources WebSocket
    _messageSubscription?.cancel();
    _eventSubscription?.cancel();
    _typingTimer?.cancel();
    
    // Réinitialiser l'état de frappe
    _isCurrentlyTyping = false;
    
    // Déconnecter le WebSocket
    _webSocketService.dispose();
    
    // Nettoyer le reste
    _conversations.clear();
    _messagesCache.clear();
    _searchResults.clear();
    _typingUsers.clear();
    
    debugPrint('✅ MessagingProvider: Disposed');
    super.dispose();
  }
}