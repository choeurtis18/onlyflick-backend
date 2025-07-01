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
  bool _isInitialized = false; // Flag pour éviter les double appels

  @override
  void initState() {
    super.initState();
    // Charger les conversations au démarrage - UNE SEULE FOIS
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_isInitialized) {
        _isInitialized = true;
        context.read<MessagingProvider>().loadConversations();
      }
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
            onRefresh: () async {
              // Appel explicite de refresh seulement quand l'utilisateur tire vers le bas
              await messagingProvider.refresh();
            },
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
              messagingProvider.conversationsError?.message ?? 'Une erreur est survenue',
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
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Commencez une conversation avec un créateur',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _showNewConversationDialog,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              icon: const Icon(Icons.add, size: 18),
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
    final unreadCount = messagingProvider.conversations
        .where((conv) => conv.unreadCount > 0)
        .length;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          _buildStatItem(
            icon: Icons.chat_bubble_outline,
            count: totalConversations,
            label: 'Conversations',
          ),
          Container(
            width: 1,
            height: 24,
            color: Colors.grey[300],
            margin: const EdgeInsets.symmetric(horizontal: 16),
          ),
          _buildStatItem(
            icon: Icons.mark_chat_unread_outlined,
            count: unreadCount,
            label: 'Non lues',
            isHighlight: unreadCount > 0,
          ),
        ],
      ),
    );
  }

  /// Widget pour une statistique
  Widget _buildStatItem({
    required IconData icon,
    required int count,
    required String label,
    bool isHighlight = false,
  }) {
    return Expanded(
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: isHighlight ? Colors.red.withOpacity(0.1) : Colors.black.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              icon,
              size: 16,
              color: isHighlight ? Colors.red : Colors.black,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  count.toString(),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isHighlight ? Colors.red : Colors.black,
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Tuile d'une conversation
  Widget _buildConversationTile(Conversation conversation) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            offset: const Offset(0, 1),
            blurRadius: 3,
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        onTap: () => _openConversation(conversation),
        leading: Stack(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: Colors.grey[200],
              backgroundImage: conversation.otherUserAvatar != null
                  ? NetworkImage(conversation.otherUserAvatar!)
                  : null,
              child: conversation.otherUserAvatar == null
                  ? Icon(Icons.person, color: Colors.grey[600])
                  : null,
            ),
            // Indicateur de messages non lus
            if (conversation.unreadCount > 0)
              Positioned(
                right: 0,
                top: 0,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                  child: Text(
                    conversation.unreadCount > 9 ? '9+' : conversation.unreadCount.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        ),
        title: Text(
          conversation.otherUserUsername ?? 'Utilisateur inconnu',
          style: TextStyle(
            fontWeight: conversation.unreadCount > 0 ? FontWeight.bold : FontWeight.w600,
            fontSize: 16,
          ),
        ),
        subtitle: conversation.lastMessage != null 
            ? Text(
                conversation.lastMessage!.content ?? 'Message sans contenu',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                  fontWeight: conversation.unreadCount > 0 ? FontWeight.w500 : FontWeight.normal,
                ),
              )
            : Text(
                'Aucun message',
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 14,
                  fontStyle: FontStyle.italic,
                ),
              ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (conversation.lastMessage != null)
              Text(
                _formatTime(conversation.lastMessage!.createdAt),
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 12,
                ),
              ),
            const SizedBox(height: 4),
            Icon(
              Icons.arrow_forward_ios_outlined,
              size: 12,
              color: Colors.grey[400],
            ),
          ],
        ),
      ),
    );
  }

  /// Ouvre une conversation
  void _openConversation(Conversation conversation) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ChatPage(conversation: conversation),
      ),
    );
  }

  /// Affiche le dialogue de nouvelle conversation
  void _showNewConversationDialog() {
    showDialog(
      context: context,
      builder: (context) => const NewConversationDialog(),
    );
  }

  /// Formate l'heure d'un message
  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays}j';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m';
    } else {
      return 'maintenant';
    }
  }
}