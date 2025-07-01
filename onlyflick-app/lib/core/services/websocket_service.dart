// onlyflick-app/lib/features/messaging/services/websocket_service.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;
import '../../../core/services/api_service.dart';
import '../models/message_models.dart';

/// Service WebSocket pour la messagerie en temps réel
class WebSocketService {
  static final WebSocketService _instance = WebSocketService._internal();
  factory WebSocketService() => _instance;
  WebSocketService._internal();

  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  Timer? _pingTimer;
  Timer? _reconnectTimer;
  
  // Configuration
  int _reconnectAttempts = 0;
  static const int maxReconnectAttempts = 5;
  static const Duration reconnectDelay = Duration(seconds: 3);
  static const Duration pingInterval = Duration(seconds: 30);
  
  // États de connexion
  bool _isConnected = false;
  bool _isConnecting = false;
  bool _shouldReconnect = true;
  
  // Conversation actuelle
  int? _currentConversationId;
  
  // Streams pour les événements
  final StreamController<Message> _messageController = StreamController<Message>.broadcast();
  final StreamController<WebSocketEvent> _eventController = StreamController<WebSocketEvent>.broadcast();
  
  // Getters publics
  bool get isConnected => _isConnected;
  bool get isConnecting => _isConnecting;
  int? get currentConversationId => _currentConversationId;
  Stream<Message> get messageStream => _messageController.stream;
  Stream<WebSocketEvent> get eventStream => _eventController.stream;

  /// URL WebSocket pour une conversation spécifique
  String _websocketUrlForConversation(int conversationId) {
    final baseUrl = ApiService().baseUrl;
    final wsUrl = baseUrl.replaceFirst('http://', 'ws://').replaceFirst('https://', 'wss://');
    return '$wsUrl/ws/messages/$conversationId';
  }

  /// Se connecte au WebSocket pour une conversation spécifique
  Future<void> connectToConversation(int conversationId) async {
    if (_isConnected && _currentConversationId == conversationId) {
      debugPrint('🔌 WebSocket: Already connected to conversation $conversationId');
      return;
    }

    // Déconnecter la conversation précédente si elle existe
    if (_isConnected && _currentConversationId != conversationId) {
      await disconnect();
    }

    final token = ApiService().token;
    if (token == null) {
      debugPrint('❌ WebSocket: No authentication token available');
      _eventController.add(WebSocketEvent.authenticationRequired());
      return;
    }

    _isConnecting = true;
    _currentConversationId = conversationId;
    _eventController.add(WebSocketEvent.connecting());
    
    try {
      // Construire l'URL WebSocket avec le token en query parameter
      // Ceci est plus compatible avec les navigateurs web
      final baseWsUrl = _websocketUrlForConversation(conversationId);
      final wsUrlWithToken = '$baseWsUrl?token=$token';
      
      debugPrint('🔌 WebSocket: Connecting to $baseWsUrl (with auth token)');
      
      _channel = WebSocketChannel.connect(
        Uri.parse(wsUrlWithToken),
        protocols: null,
      );

      debugPrint('🔧 WebSocket: Using query parameter authentication for better browser compatibility');

      // Écouter les messages
      _subscription = _channel!.stream.listen(
        _handleMessage,
        onError: _handleError,
        onDone: _handleDisconnection,
      );

      // Marquer comme connecté
      _isConnected = true;
      _isConnecting = false;
      _reconnectAttempts = 0;
      
      // Démarrer le ping pour maintenir la connexion
      _startPing();
      
      debugPrint('✅ WebSocket: Connected successfully to conversation $conversationId');
      _eventController.add(WebSocketEvent.connected());
      
    } catch (e) {
      _isConnecting = false;
      _currentConversationId = null;
      debugPrint('❌ WebSocket: Connection failed: $e');
      _eventController.add(WebSocketEvent.error('Échec de connexion: $e'));
      _scheduleReconnect();
    }
  }

  /// Se connecte au WebSocket (méthode legacy, utilise connectToConversation maintenant)
  @Deprecated('Utilisez connectToConversation(int conversationId) à la place')
  Future<void> connect() async {
    debugPrint('⚠️ WebSocket: connect() est obsolète, utilisez connectToConversation(int conversationId)');
    _eventController.add(WebSocketEvent.error('ID de conversation requis pour la connexion'));
  }

  /// Déconnecte le WebSocket
  Future<void> disconnect() async {
    _shouldReconnect = false;
    _stopPing();
    _stopReconnectTimer();
    
    if (_channel != null) {
      debugPrint('🔌 WebSocket: Disconnecting from conversation $_currentConversationId...');
      await _channel!.sink.close(status.normalClosure);
      _channel = null;
    }
    
    _subscription?.cancel();
    _subscription = null;
    _isConnected = false;
    _isConnecting = false;
    _currentConversationId = null;
    
    debugPrint('✅ WebSocket: Disconnected');
    _eventController.add(WebSocketEvent.disconnected());
  }

  /// Rejoint une conversation pour recevoir ses messages en temps réel
  /// Note: Cette méthode est maintenant automatique lors de connectToConversation
  void joinConversation(int conversationId) {
    if (!_isConnected) {
      debugPrint('❌ WebSocket: Cannot join conversation, not connected');
      return;
    }

    if (_currentConversationId != conversationId) {
      debugPrint('⚠️ WebSocket: Requesting join for different conversation. Use connectToConversation instead.');
      return;
    }

    debugPrint('🔌 WebSocket: Already in conversation $conversationId');
  }

  /// Quitte une conversation
  void leaveConversation(int conversationId) {
    if (!_isConnected || _currentConversationId != conversationId) return;

    debugPrint('🔌 WebSocket: Leaving conversation $conversationId');
    disconnect();
  }

  /// Envoie un message dans la conversation actuelle
  Future<void> sendMessage(String content) async {
    if (!_isConnected || _currentConversationId == null) {
      debugPrint('❌ WebSocket: Cannot send message, not connected to any conversation');
      return;
    }

    try {
      final message = {
        'content': content,
      };
      
      _channel!.sink.add(jsonEncode(message));
      debugPrint('📤 WebSocket: Message sent: $content');
    } catch (e) {
      debugPrint('❌ WebSocket: Error sending message: $e');
      _eventController.add(WebSocketEvent.error('Erreur envoi message: $e'));
    }
  }

  /// Gère les messages reçus du WebSocket
  void _handleMessage(dynamic data) {
    try {
      final jsonData = jsonDecode(data as String);
      debugPrint('🔌 WebSocket: Received message type: ${jsonData['type'] ?? 'unknown'}');
      
      // Si c'est un message direct (pas d'envelope avec type)
      if (!jsonData.containsKey('type')) {
        _handleDirectMessage(jsonData);
        return;
      }
      
      switch (jsonData['type']) {
        case 'new_message':
          _handleNewMessage(jsonData);
          break;
          
        case 'message_delivered':
          _handleMessageDelivered(jsonData);
          break;
          
        case 'message_read':
          _handleMessageRead(jsonData);
          break;
          
        case 'user_typing':
          _handleUserTyping(jsonData);
          break;
          
        case 'error':
          _handleWebSocketError(jsonData);
          break;
          
        case 'pong':
          // Réponse au ping, connexion OK
          debugPrint('🏓 WebSocket: Pong received');
          break;
          
        default:
          debugPrint('🔌 WebSocket: Unknown message type: ${jsonData['type']}');
      }
    } catch (e) {
      debugPrint('❌ WebSocket: Error parsing message: $e');
      debugPrint('📄 WebSocket: Raw data: $data');
    }
  }

  /// Gère les messages directs (format du serveur Go actuel)
  void _handleDirectMessage(Map<String, dynamic> data) {
    try {
      // Le serveur Go envoie directement le message, pas dans une envelope
      final message = Message.fromJson(data);
      
      debugPrint('💬 WebSocket: Direct message received from user ${message.senderId}');
      _messageController.add(message);
      
    } catch (e) {
      debugPrint('❌ WebSocket: Error handling direct message: $e');
      debugPrint('📄 WebSocket: Data: $data');
    }
  }

  /// Gère les nouveaux messages reçus (format avec envelope)
  void _handleNewMessage(Map<String, dynamic> data) {
    try {
      final messageData = data['message'] as Map<String, dynamic>;
      final message = Message.fromJson(messageData);
      
      debugPrint('💬 WebSocket: New message received in conversation ${message.conversationId}');
      _messageController.add(message);
      
    } catch (e) {
      debugPrint('❌ WebSocket: Error handling new message: $e');
    }
  }

  /// Gère la confirmation de livraison des messages
  void _handleMessageDelivered(Map<String, dynamic> data) {
    final messageId = data['message_id'] as int;
    debugPrint('✅ WebSocket: Message $messageId delivered');
    
    _eventController.add(WebSocketEvent.messageDelivered(messageId));
  }

  /// Gère la confirmation de lecture des messages
  void _handleMessageRead(Map<String, dynamic> data) {
    final messageId = data['message_id'] as int;
    debugPrint('👁️ WebSocket: Message $messageId read');
    
    _eventController.add(WebSocketEvent.messageRead(messageId));
  }

  /// Gère les indicateurs de frappe
  void _handleUserTyping(Map<String, dynamic> data) {
    final conversationId = data['conversation_id'] as int;
    final userId = data['user_id'] as int;
    final isTyping = data['is_typing'] as bool;
    
    debugPrint('⌨️ WebSocket: User $userId ${isTyping ? 'started' : 'stopped'} typing in conversation $conversationId');
    
    _eventController.add(WebSocketEvent.userTyping(conversationId, userId, isTyping));
  }

  /// Gère les erreurs WebSocket
  void _handleWebSocketError(Map<String, dynamic> data) {
    final error = data['message'] as String;
    debugPrint('❌ WebSocket: Server error: $error');
    
    _eventController.add(WebSocketEvent.error(error));
  }

  /// Gère les erreurs de connexion
  void _handleError(dynamic error) {
    debugPrint('❌ WebSocket: Connection error: $error');
    _isConnected = false;
    _isConnecting = false;
    
    _eventController.add(WebSocketEvent.error('Erreur de connexion: $error'));
    _scheduleReconnect();
  }

  /// Gère la déconnexion
  void _handleDisconnection() {
    debugPrint('🔌 WebSocket: Connection closed');
    _isConnected = false;
    _isConnecting = false;
    _stopPing();
    
    _eventController.add(WebSocketEvent.disconnected());
    
    if (_shouldReconnect && _currentConversationId != null) {
      _scheduleReconnect();
    }
  }

  /// Envoie un message au WebSocket
  void _sendMessage(Map<String, dynamic> message) {
    if (_channel != null && _isConnected) {
      _channel!.sink.add(jsonEncode(message));
    }
  }

  /// Démarre le système de ping pour maintenir la connexion
  void _startPing() {
    _stopPing(); // Arrêter le ping précédent s'il existe
    
    _pingTimer = Timer.periodic(pingInterval, (timer) {
      if (_isConnected && _channel != null) {
        _sendMessage({'type': 'ping'});
      } else {
        timer.cancel();
      }
    });
  }

  /// Arrête le système de ping
  void _stopPing() {
    _pingTimer?.cancel();
    _pingTimer = null;
  }

  /// Programme une tentative de reconnexion
  void _scheduleReconnect() {
    if (!_shouldReconnect || _reconnectAttempts >= maxReconnectAttempts || _currentConversationId == null) {
      if (_reconnectAttempts >= maxReconnectAttempts) {
        debugPrint('❌ WebSocket: Max reconnection attempts reached');
        _eventController.add(WebSocketEvent.error('Impossible de se reconnecter'));
      }
      return;
    }

    _stopReconnectTimer();
    _reconnectAttempts++;
    
    debugPrint('🔄 WebSocket: Scheduling reconnection attempt $_reconnectAttempts in ${reconnectDelay.inSeconds}s');
    
    _reconnectTimer = Timer(reconnectDelay, () {
      if (_shouldReconnect && _currentConversationId != null) {
        connectToConversation(_currentConversationId!);
      }
    });
  }

  /// Arrête le timer de reconnexion
  void _stopReconnectTimer() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
  }

  /// Envoie un indicateur de frappe
  void sendTypingIndicator(int conversationId, bool isTyping) {
    if (!_isConnected || _currentConversationId != conversationId) return;
    
    _sendMessage({
      'type': 'typing',
      'conversation_id': conversationId,
      'is_typing': isTyping,
    });
  }

  /// Nettoie les ressources
  void dispose() {
    _shouldReconnect = false;
    disconnect();
    _messageController.close();
    _eventController.close();
  }
}

/// Classe pour les événements WebSocket
class WebSocketEvent {
  final WebSocketEventType type;
  final String? message;
  final int? messageId;
  final int? conversationId;
  final int? userId;
  final bool? isTyping;

  const WebSocketEvent._({
    required this.type,
    this.message,
    this.messageId,
    this.conversationId,
    this.userId,
    this.isTyping,
  });

  factory WebSocketEvent.connecting() => const WebSocketEvent._(type: WebSocketEventType.connecting);
  
  factory WebSocketEvent.connected() => const WebSocketEvent._(type: WebSocketEventType.connected);
  
  factory WebSocketEvent.disconnected() => const WebSocketEvent._(type: WebSocketEventType.disconnected);
  
  factory WebSocketEvent.error(String message) => WebSocketEvent._(
    type: WebSocketEventType.error,
    message: message,
  );
  
  factory WebSocketEvent.authenticationRequired() => const WebSocketEvent._(
    type: WebSocketEventType.authenticationRequired,
  );
  
  factory WebSocketEvent.messageDelivered(int messageId) => WebSocketEvent._(
    type: WebSocketEventType.messageDelivered,
    messageId: messageId,
  );
  
  factory WebSocketEvent.messageRead(int messageId) => WebSocketEvent._(
    type: WebSocketEventType.messageRead,
    messageId: messageId,
  );
  
  factory WebSocketEvent.userTyping(int conversationId, int userId, bool isTyping) => WebSocketEvent._(
    type: WebSocketEventType.userTyping,
    conversationId: conversationId,
    userId: userId,
    isTyping: isTyping,
  );
}

enum WebSocketEventType {
  connecting,
  connected,
  disconnected,
  error,
  authenticationRequired,
  messageDelivered,
  messageRead,
  userTyping,
}