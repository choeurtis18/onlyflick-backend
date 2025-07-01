// onlyflick-app/lib/features/messaging/pages/websocket_test_page.dart
import 'package:flutter/material.dart';
import 'dart:async';
import '../../.././../core/services/websocket_service.dart' as ws_service; 
import '../../../../core/models/message_models.dart' as msg_models;
class WebSocketTestPage extends StatefulWidget {
  const WebSocketTestPage({Key? key}) : super(key: key);

  @override
  State<WebSocketTestPage> createState() => _WebSocketTestPageState();
}

class _WebSocketTestPageState extends State<WebSocketTestPage> {
  final ws_service.WebSocketService _wsService = ws_service.WebSocketService();
  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _conversationIdController = TextEditingController(text: '1');
  
  StreamSubscription<msg_models.Message>? _messageSubscription;
  StreamSubscription<ws_service.WebSocketEvent>? _eventSubscription;
  
  List<msg_models.Message> _messages = [];
  String _connectionStatus = 'Déconnecté';
  String _lastEvent = '';

  @override
  void initState() {
    super.initState();
    _initWebSocket();
  }

  void _initWebSocket() {
    // Écouter les messages
    _messageSubscription = _wsService.messageStream.listen((message) {
      setState(() {
        _messages.add(message);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('💬 Nouveau message de ${message.senderId}'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    });

    // Écouter les événements de connexion
    _eventSubscription = _wsService.eventStream.listen((event) {
      setState(() {
        _lastEvent = event.type.toString();
        switch (event.type) {
          case ws_service.WebSocketEventType.connecting:
            _connectionStatus = 'Connexion...';
            break;
          case ws_service.WebSocketEventType.connected:
            _connectionStatus = '✅ Connecté';
            break;
          case ws_service.WebSocketEventType.disconnected:
            _connectionStatus = '❌ Déconnecté';
            break;
          case ws_service.WebSocketEventType.error:
            _connectionStatus = '⚠️ Erreur: ${event.message}';
            break;
          case ws_service.WebSocketEventType.authenticationRequired:
            _connectionStatus = '🔐 Authentification requise';
            break;
          default:
            _connectionStatus = 'État: ${event.type}';
        }
      });
    });
  }

  Future<void> _connectToConversation() async {
    final conversationId = int.tryParse(_conversationIdController.text);
    if (conversationId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ ID de conversation invalide'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      await _wsService.connectToConversation(conversationId);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Erreur de connexion: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _disconnect() async {
    await _wsService.disconnect();
  }

  Future<void> _sendMessage() async {
    final content = _messageController.text.trim();
    if (content.isEmpty) return;

    if (!_wsService.isConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Non connecté au WebSocket'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      await _wsService.sendMessage(content);
      _messageController.clear();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('📤 Message envoyé'),
          backgroundColor: Colors.blue,
          duration: Duration(seconds: 1),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Erreur envoi: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  void dispose() {
    _messageSubscription?.cancel();
    _eventSubscription?.cancel();
    _messageController.dispose();
    _conversationIdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Test WebSocket'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Section statut
            Card(
              color: _wsService.isConnected ? Colors.green[50] : Colors.red[50],
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Statut de connexion',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      _connectionStatus,
                      style: TextStyle(
                        fontSize: 16,
                        color: _wsService.isConnected ? Colors.green[800] : Colors.red[800],
                      ),
                    ),
                    if (_lastEvent.isNotEmpty) ...[
                      SizedBox(height: 4),
                      Text(
                        'Dernier événement: $_lastEvent',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                    if (_wsService.currentConversationId != null) ...[
                      SizedBox(height: 4),
                      Text(
                        'Conversation: ${_wsService.currentConversationId}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            
            SizedBox(height: 16),
            
            // Section connexion
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Connexion',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 12),
                    TextField(
                      controller: _conversationIdController,
                      decoration: InputDecoration(
                        labelText: 'ID de conversation',
                        border: OutlineInputBorder(),
                        hintText: 'Ex: 1',
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _wsService.isConnected ? null : _connectToConversation,
                            icon: Icon(Icons.wifi),
                            label: Text('Se connecter'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _wsService.isConnected ? _disconnect : null,
                            icon: Icon(Icons.wifi_off),
                            label: Text('Déconnecter'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            
            SizedBox(height: 16),
            
            // Section envoi de message
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Envoyer un message',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _messageController,
                            decoration: InputDecoration(
                              labelText: 'Message',
                              border: OutlineInputBorder(),
                              hintText: 'Tapez votre message...',
                            ),
                            onSubmitted: (_) => _sendMessage(),
                          ),
                        ),
                        SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: _wsService.isConnected ? _sendMessage : null,
                          icon: Icon(Icons.send),
                          label: Text('Envoyer'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            
            SizedBox(height: 16),
            
            // Section messages reçus
            Expanded(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Messages reçus (${_messages.length})',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 12),
                      Expanded(
                        child: _messages.isEmpty
                            ? Center(
                                child: Text(
                                  'Aucun message reçu',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 16,
                                  ),
                                ),
                              )
                            : ListView.builder(
                                itemCount: _messages.length,
                                itemBuilder: (context, index) {
                                  final message = _messages[index];
                                  return Card(
                                    margin: EdgeInsets.only(bottom: 8),
                                    color: Colors.blue[50],
                                    child: ListTile(
                                      leading: CircleAvatar(
                                        child: Text('${message.senderId}'),
                                        backgroundColor: Colors.blue,
                                        foregroundColor: Colors.white,
                                      ),
                                      title: Text(message.content),
                                      subtitle: Text(
                                        'De: ${message.senderId} • Conv: ${message.conversationId}',
                                        style: TextStyle(fontSize: 12),
                                      ),
                                      trailing: Text(
                                        '${message.createdAt.hour}:${message.createdAt.minute.toString().padLeft(2, '0')}',
                                        style: TextStyle(fontSize: 12),
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}