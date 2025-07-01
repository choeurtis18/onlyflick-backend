// onlyflick-app/lib/features/messaging/pages/conversations_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/providers/messaging_provider.dart';
import '../../../../core/models/message_models.dart';
import '../widgets/new_conversation_dialog.dart';
import 'chat_page.dart';

/// Page des conversations avec design OnlyFlick
class ConversationsPage extends StatefulWidget {
  const ConversationsPage({super.key});

  @override
  State<ConversationsPage> createState() => _ConversationsPageState();
}

class _ConversationsPageState extends State<ConversationsPage> {
  @override
  void initState() {
    super.initState();
    // Charger les conversations au démarrage
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MessagingProvider>().loadConversations();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _buildAppBar(),
      body: Consumer<MessagingProvider>(
        builder: (context, messagingProvider, child) {
          return RefreshIndicator(
            onRefresh: () => messagingProvider.refresh(),
            child: _buildBody(messagingProvider),
          );
        },
      ),
    );
  }

  /// AppBar moderne style OnlyFlick
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      leading: IconButton(
        onPressed: () => Navigator.of(context).pop(),
        icon: const Icon(Icons.arrow_back_ios, color: Colors.black, size: 20),
      ),
      title: const Text(
        'Messages',
        style: TextStyle(
          color: Colors.black,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
      ),
      actions: [
        // Indicateur WebSocket
        Consumer<MessagingProvider>(
          builder: (context, messagingProvider, child) {
            return Container(
              margin: const EdgeInsets.only(right: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: messagingProvider.isWebSocketConnected 
                          ? Colors.green 
                          : Colors.orange,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    messagingProvider.isWebSocketConnected ? 'En ligne' : 'Hors ligne',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        // Bouton nouvelle conversation
        IconButton(
          onPressed: _showNewConversationDialog,
          icon: const Icon(Icons.edit_square, color: Colors.black, size: 22),
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  /// Corps principal de la page
  Widget _buildBody(MessagingProvider messagingProvider) {
    // État de chargement initial
    if (messagingProvider.isLoadingConversations && 
        messagingProvider.conversations.isEmpty) {
      return _buildLoadingState();
    }

    // État d'erreur
    if (messagingProvider.conversationsError != null && 
        messagingProvider.conversations.isEmpty) {
      return _buildErrorState(messagingProvider);
    }

    // Aucune conversation
    if (messagingProvider.conversations.isEmpty) {
      return _buildEmptyState();
    }

    // Liste des conversations
    return Column(
      children: [
        // Indicateur de rafraîchissement
        if (messagingProvider.isLoadingConversations)
          Container(
            height: 2,
            child: const LinearProgressIndicator(
              backgroundColor: Colors.transparent,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
            ),
          ),
        
        // En-tête avec stats
        _buildStatsHeader(messagingProvider),
        
        // Liste des conversations
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: messagingProvider.conversations.length,
            itemBuilder: (context, index) {
              final conversation = messagingProvider.conversations[index];
              return _buildConversationTile(conversation);
            },
          ),
        ),
      ],
    );
  }

  /// État de chargement
  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 32,
            height: 32,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Chargement des conversations...',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  /// État d'erreur
  Widget _buildErrorState(MessagingProvider messagingProvider) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.wifi_off_rounded,
                size: 32,
                color: Colors.grey[400],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Impossible de charger',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              messagingProvider.conversationsError!.message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => messagingProvider.loadConversations(),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: const Text(
                'Réessayer',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// État vide
  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: Colors.grey[50],
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.chat_bubble_outline,
                size: 40,
                color: Colors.grey[400],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Aucune conversation',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Commencez une nouvelle conversation\navec d\'autres utilisateurs OnlyFlick',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                height: 1.4,
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _showNewConversationDialog,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              icon: const Icon(Icons.add, size: 20),
              label: const Text(
                'Nouvelle conversation',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// En-tête avec statistiques
  Widget _buildStatsHeader(MessagingProvider messagingProvider) {
    final totalConversations = messagingProvider.conversations.length;
    final unreadCount = messagingProvider.totalUnreadCount;
    
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$totalConversations conversation${totalConversations > 1 ? 's' : ''}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (unreadCount > 0) ...[
                  const SizedBox(height: 2),
                  Text(
                    '$unreadCount non lu${unreadCount > 1 ? 's' : ''}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.red,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
          // Bouton de tri (optionnel)
          TextButton.icon(
            onPressed: () {
              // TODO: Implémenter le tri
            },
            style: TextButton.styleFrom(
              foregroundColor: Colors.grey[600],
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
            icon: Icon(Icons.sort, size: 16, color: Colors.grey[600]),
            label: Text(
              'Récents',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ),
        ],
      ),
    );
  }

  /// Tuile de conversation style OnlyFlick
  Widget _buildConversationTile(Conversation conversation) {
    final hasUnreadMessages = conversation.hasUnreadMessages;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _openChat(conversation),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Avatar
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: Colors.grey[200],
                      backgroundImage: conversation.otherUserAvatar != null
                          ? NetworkImage(conversation.otherUserAvatar!)
                          : null,
                      child: conversation.otherUserAvatar == null
                          ? Text(
                              _getInitials(conversation.otherUserDisplayName),
                              style: TextStyle(
                                color: Colors.grey[700],
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            )
                          : null,
                    ),
                    // Indicateur en ligne (si WebSocket connecté)
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(width: 12),
                
                // Contenu
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Ligne 1: Nom + Timestamp
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              conversation.otherUserDisplayName,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: hasUnreadMessages ? FontWeight.w700 : FontWeight.w600,
                                color: Colors.black,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (conversation.lastMessage != null)
                            Text(
                              _formatTimestamp(conversation.lastMessage!.createdAt),
                              style: TextStyle(
                                fontSize: 12,
                                color: hasUnreadMessages ? Colors.black : Colors.grey[500],
                                fontWeight: hasUnreadMessages ? FontWeight.w600 : FontWeight.w400,
                              ),
                            ),
                        ],
                      ),
                      
                      const SizedBox(height: 4),
                      
                      // Ligne 2: Dernier message + Badge
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              conversation.lastMessage?.content ?? 'Aucun message',
                              style: TextStyle(
                                fontSize: 14,
                                color: hasUnreadMessages ? Colors.black87 : Colors.grey[600],
                                fontWeight: hasUnreadMessages ? FontWeight.w500 : FontWeight.w400,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          
                          // Badge non lus
                          if (hasUnreadMessages) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.red,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                conversation.unreadCount > 99 
                                    ? '99+' 
                                    : conversation.unreadCount.toString(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Ouvrir le chat
  void _openChat(Conversation conversation) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ChatPage(conversation: conversation),
      ),
    );
  }

  /// Afficher le dialogue nouvelle conversation
  void _showNewConversationDialog() {
    showDialog(
      context: context,
      builder: (context) => const NewConversationDialog(),
    );
  }

  /// Générer les initiales
  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    } else if (parts.isNotEmpty) {
      return parts[0][0].toUpperCase();
    }
    return '?';
  }

  /// Formater le timestamp
  String _formatTimestamp(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    if (difference.inDays == 0) {
      final hour = dateTime.hour.toString().padLeft(2, '0');
      final minute = dateTime.minute.toString().padLeft(2, '0');
      return '$hour:$minute';
    }
    
    if (difference.inDays == 1) {
      return 'Hier';
    }
    
    if (difference.inDays < 7) {
      final weekdays = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];
      return weekdays[dateTime.weekday - 1];
    }
    
    final day = dateTime.day.toString().padLeft(2, '0');
    final month = dateTime.month.toString().padLeft(2, '0');
    return '$day/$month';
  }
}