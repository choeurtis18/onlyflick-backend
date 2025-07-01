// onlyflick-app/lib/features/messaging/pages/chat_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/providers/messaging_provider.dart';
import '../../../../core/models/message_models.dart';
import '../widgets/message_bubble.dart';
import '../widgets/typing_indicator.dart';
import '../../../../core/services/api_service.dart';

/// Page de chat pour une conversation spécifique
class ChatPage extends StatefulWidget {
  final Conversation conversation;

  const ChatPage({
    super.key,
    required this.conversation,
  });

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _messageFocusNode = FocusNode();
  
  // Gestion des indicateurs de frappe
  Timer? _typingTimer;
  bool _isTypingIndicatorSent = false;

  @override
  void initState() {
    super.initState();
    // Charger les messages de cette conversation
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MessagingProvider>().loadMessages(widget.conversation.id);
    });
    
    // Écouter les changements de texte pour les indicateurs de frappe
    _messageController.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _messageController.removeListener(_onTextChanged);
    _messageController.dispose();
    _scrollController.dispose();
    _messageFocusNode.dispose();
    _typingTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            // Avatar de l'autre utilisateur
            CircleAvatar(
              radius: 16,
              backgroundColor: Theme.of(context).primaryColor,
              backgroundImage: widget.conversation.otherUserAvatar != null
                  ? NetworkImage(widget.conversation.otherUserAvatar!)
                  : null,
              child: widget.conversation.otherUserAvatar == null
                  ? Text(
                      _getInitials(widget.conversation.otherUserDisplayName),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            // Nom de l'autre utilisateur
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.conversation.otherUserDisplayName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (widget.conversation.otherUserUsername != null)
                    Text(
                      '@${widget.conversation.otherUserUsername}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white70,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          // Bouton rafraîchir
          IconButton(
            onPressed: () => context.read<MessagingProvider>().loadMessages(widget.conversation.id),
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualiser',
          ),
        ],
      ),
      body: Column(
        children: [
          // Zone des messages
          Expanded(
            child: Consumer<MessagingProvider>(
              builder: (context, messagingProvider, child) {
                // Chargement initial
                if (messagingProvider.isLoadingMessages && 
                    messagingProvider.activeMessages.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Chargement des messages...'),
                      ],
                    ),
                  );
                }

                // Erreur de chargement
                if (messagingProvider.messagesError != null && 
                    messagingProvider.activeMessages.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          messagingProvider.messagesError!.message,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () => messagingProvider.loadMessages(widget.conversation.id),
                          child: const Text('Réessayer'),
                        ),
                      ],
                    ),
                  );
                }

                // Aucun message
                if (messagingProvider.activeMessages.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Aucun message',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Commencez la conversation en envoyant un message',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                // Liste des messages
                return RefreshIndicator(
                  onRefresh: () => messagingProvider.loadMessages(widget.conversation.id),
                  child: Column(
                    children: [
                      // Indicateur de chargement si refresh en cours
                      if (messagingProvider.isLoadingMessages)
                        const LinearProgressIndicator(),
                      
                      // Liste des messages avec indicateur de frappe
                      Expanded(
                        child: ListView.builder(
                          controller: _scrollController,
                          reverse: true, // Affichage en bas vers le haut
                          padding: const EdgeInsets.all(8),
                          itemCount: messagingProvider.activeMessages.length + _getTypingIndicatorCount(),
                          itemBuilder: (context, index) {
                            // Afficher d'abord l'indicateur de frappe si nécessaire
                            if (index < _getTypingIndicatorCount()) {
                              return _buildTypingIndicator(messagingProvider);
                            }
                            
                            // Index ajusté pour les messages
                            final messageIndex = index - _getTypingIndicatorCount();
                            final reversedIndex = messagingProvider.activeMessages.length - 1 - messageIndex;
                            final message = messagingProvider.activeMessages[reversedIndex];
                            
                            return MessageBubble(
                              message: message,
                              isCurrentUser: _isCurrentUserMessage(message),
                              showAvatar: _shouldShowAvatar(messagingProvider.activeMessages, reversedIndex),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          
          // Zone de saisie des messages
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              border: Border(
                top: BorderSide(
                  color: Colors.grey[300]!,
                  width: 0.5,
                ),
              ),
            ),
            child: Consumer<MessagingProvider>(
              builder: (context, messagingProvider, child) {
                return Row(
                  children: [
                    // Champ de saisie
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        focusNode: _messageFocusNode,
                        decoration: InputDecoration(
                          hintText: 'Tapez votre message...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide(color: Theme.of(context).primaryColor),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          suffixIcon: messagingProvider.sendMessageError != null
                              ? Icon(Icons.error, color: Colors.red[400])
                              : null,
                        ),
                        maxLines: null,
                        textCapitalization: TextCapitalization.sentences,
                        onSubmitted: (value) => _sendMessage(context),
                        onChanged: (value) {
                          // Déjà géré par le listener dans _onTextChanged
                        },
                      ),
                    ),
                    
                    const SizedBox(width: 8),
                    
                    // Bouton d'envoi
                    Container(
                      decoration: BoxDecoration(
                        color: _messageController.text.trim().isNotEmpty && !messagingProvider.isSendingMessage
                            ? Theme.of(context).primaryColor
                            : Colors.grey[300],
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        onPressed: _messageController.text.trim().isNotEmpty && !messagingProvider.isSendingMessage
                            ? () => _sendMessage(context)
                            : null,
                        icon: messagingProvider.isSendingMessage
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : const Icon(Icons.send),
                        color: Colors.white,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          
          // Erreur d'envoi
          Consumer<MessagingProvider>(
            builder: (context, messagingProvider, child) {
              if (messagingProvider.sendMessageError != null) {
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  color: Colors.red[50],
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: Colors.red[400], size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          messagingProvider.sendMessageError!.message,
                          style: TextStyle(
                            color: Colors.red[700],
                            fontSize: 12,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () => _sendMessage(context),
                        child: const Text('Réessayer'),
                      ),
                    ],
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
    );
  }

  /// Envoie un message
  Future<void> _sendMessage(BuildContext context) async {
    final content = _messageController.text.trim();
    if (content.isEmpty) return;

    final messagingProvider = context.read<MessagingProvider>();
    
    // Vider le champ de saisie immédiatement
    _messageController.clear();
    
    // Envoyer le message
    final success = await messagingProvider.sendMessage(content);
    
    if (success) {
      // Faire défiler vers le bas pour afficher le nouveau message
      _scrollToBottom();
      
      // Refocus sur le champ de saisie
      _messageFocusNode.requestFocus();
    } else {
      // Remettre le texte si l'envoi a échoué
      _messageController.text = content;
    }
  }

  /// Fait défiler vers le bas de la liste
  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0.0, // Position 0 car la liste est reverse
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  /// Vérifie si le message est envoyé par l'utilisateur actuel
  bool _isCurrentUserMessage(Message message) {
    final currentUserId = ApiService().currentUserId;
    if (currentUserId == null) return false;
    return message.senderId == currentUserId;
  }

  /// Détermine si l'avatar doit être affiché pour ce message
  bool _shouldShowAvatar(List<Message> messages, int index) {
    if (index == 0) return true; // Premier message
    
    final currentMessage = messages[index];
    final previousMessage = messages[index - 1];
    
    // Afficher l'avatar si l'expéditeur est différent du message précédent
    return currentMessage.senderId != previousMessage.senderId;
  }

  /// Génère les initiales à partir d'un nom
  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    } else if (parts.isNotEmpty) {
      return parts[0][0].toUpperCase();
    }
    return '?';
  }

  /// Gère les changements de texte pour les indicateurs de frappe
  void _onTextChanged() {
    final hasText = _messageController.text.trim().isNotEmpty;
    final messagingProvider = context.read<MessagingProvider>();
    
    if (hasText && !_isTypingIndicatorSent) {
      // Commencer à taper
      _isTypingIndicatorSent = true;
      messagingProvider.sendTypingIndicator(true);
    } else if (!hasText && _isTypingIndicatorSent) {
      // Arrêter de taper
      _isTypingIndicatorSent = false;
      messagingProvider.sendTypingIndicator(false);
    }
    
    // Réinitialiser le timer pour arrêter l'indicateur automatiquement
    if (hasText) {
      _typingTimer?.cancel();
      _typingTimer = Timer(const Duration(seconds: 2), () {
        if (_isTypingIndicatorSent) {
          _isTypingIndicatorSent = false;
          messagingProvider.sendTypingIndicator(false);
        }
      });
    }
  }

  /// Compte le nombre d'indicateurs de frappe à afficher
  int _getTypingIndicatorCount() {
    final messagingProvider = context.read<MessagingProvider>();
    final typingUsers = messagingProvider.getTypingUsers(widget.conversation.id);
    return typingUsers.isNotEmpty ? 1 : 0;
  }

  /// Construit l'indicateur de frappe
  Widget _buildTypingIndicator(MessagingProvider messagingProvider) {
    final typingUsers = messagingProvider.getTypingUsers(widget.conversation.id);
    final currentUserId = ApiService().currentUserId;
    
    // Exclure l'utilisateur actuel des indicateurs de frappe
    final otherTypingUsers = typingUsers.where((userId) => userId != currentUserId).toSet();
    
    if (otherTypingUsers.isEmpty) {
      return const SizedBox.shrink();
    }

    // Créer un map des noms d'affichage (simplifiée pour l'exemple)
    final typingUserNames = <int, String>{};
    for (final userId in otherTypingUsers) {
      typingUserNames[userId] = 'Utilisateur #$userId'; // TODO: Récupérer les vrais noms
    }

    return TypingIndicatorContainer(
      typingUsers: typingUserNames,
    );
  }
}