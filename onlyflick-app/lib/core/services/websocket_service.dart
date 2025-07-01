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
  
  // Streams pour les événements
  final StreamController<Message> _messageController = StreamController<Message>.broadcast();
  final StreamController<WebSocketEvent> _eventController = StreamController<WebSocketEvent>.broadcast();
  
  // Getters publics
  bool get isConnected => _isConnected;
  bool get isConnecting => _isConnecting;
  Stream<Message> get messageStream => _messageController.stream;
  Stream<WebSocketEvent> get eventStream => _eventController.stream;

  /// URL WebSocket en fonction de l'environnement
  String get _websocketUrl {
    final baseUrl = ApiService().baseUrl;
    final wsUrl = baseUrl.replaceFirst('http://', 'ws://').replaceFirst('https://', 'wss://');
    return '$wsUrl/ws';
  }

  /// Se connecte au WebSocket
  Future<void> connect() async {
    if (_isConnected || _isConnecting) {
      debugPrint('🔌 WebSocket: Already connected or connecting');
      return;
    }

    final token = ApiService().token;
    if (token == null) {
      debugPrint('❌ WebSocket: No authentication token available');
      _eventController.add(WebSocketEvent.authenticationRequired());
      return;
    }

    _isConnecting = true;
    _eventController.add(WebSocketEvent.connecting());
    
    try {
      debugPrint('🔌 WebSocket: Connecting to $_websocketUrl');
      
      // Créer la connexion WebSocket avec authentification
      _channel = WebSocketChannel.connect(
        Uri.parse('$_websocketUrl?token=$token'),
      );

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
      
      debugPrint('✅ WebSocket: Connected successfully');
      _eventController.add(WebSocketEvent.connected());
      
    } catch (e) {
      _isConnecting = false;
      debugPrint('❌ WebSocket: Connection failed: $e');
      _eventController.add(WebSocketEvent.error('Échec de connexion: $e'));
      _scheduleReconnect();
    }
  }

  /// Déconnecte le WebSocket
  Future<void> disconnect() async {
    _shouldReconnect = false;
    _stopPing();
    _stopReconnectTimer();
    
    if (_channel != null) {
      debugPrint('🔌 WebSocket: Disconnecting...');
      await _channel!.sink.close(status.normalClosure);
      _channel = null;
    }
    
    _subscription?.cancel();
    _subscription = null;
    _isConnected = false;
    _isConnecting = false;
    
    debugPrint('✅ WebSocket: Disconnected');
    _eventController.add(WebSocketEvent.disconnected());
  }

  /// Rejoint une conversation pour recevoir ses messages en temps réel
  void joinConversation(int conversationId) {
    if (!_isConnected) {
      debugPrint('❌ WebSocket: Cannot join conversation, not connected');
      return;
    }

    debugPrint('🔌 WebSocket: Joining conversation $conversationId');
    _sendMessage({
      'type': 'join_conversation',
      'conversation_id': conversationId,
    });
  }

  /// Quitte une conversation
  void leaveConversation(int conversationId) {
    if (!_isConnected) return;

    debugPrint('🔌 WebSocket: Leaving conversation $conversationId');
    _sendMessage({
      'type': 'leave_conversation',
      'conversation_id': conversationId,
    });
  }

  /// Gère les messages reçus du WebSocket
  void _handleMessage(dynamic data) {
    try {
      final jsonData = jsonDecode(data as String);
      debugPrint('🔌 WebSocket: Received message: ${jsonData['type']}');
      
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
          break;
          
        default:
          debugPrint('🔌 WebSocket: Unknown message type: ${jsonData['type']}');
      }
    } catch (e) {
      debugPrint('❌ WebSocket: Error parsing message: $e');
    }
  }

  /// Gère les nouveaux messages reçus
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
    
    if (_shouldReconnect) {
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
    if (!_shouldReconnect || _reconnectAttempts >= maxReconnectAttempts) {
      debugPrint('❌ WebSocket: Max reconnection attempts reached');
      _eventController.add(WebSocketEvent.error('Impossible de se reconnecter'));
      return;
    }

    _stopReconnectTimer();
    _reconnectAttempts++;
    
    debugPrint('🔄 WebSocket: Scheduling reconnection attempt $_reconnectAttempts in ${reconnectDelay.inSeconds}s');
    
    _reconnectTimer = Timer(reconnectDelay, () {
      if (_shouldReconnect) {
        connect();
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
    if (!_isConnected) return;
    
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