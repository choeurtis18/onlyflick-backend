// onlyflick-app/lib/features/messaging/widgets/conversation_tile.dart
import 'package:flutter/material.dart';
import '../../../../core/models/message_models.dart';

/// Widget pour afficher une conversation dans la liste
class ConversationTile extends StatelessWidget {
  final Conversation conversation;
  final VoidCallback onTap;

  const ConversationTile({
    super.key,
    required this.conversation,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasUnreadMessages = conversation.hasUnreadMessages;
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      elevation: hasUnreadMessages ? 2.0 : 1.0,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        onTap: onTap,
        
        // Avatar de l'autre utilisateur
        leading: CircleAvatar(
          radius: 24,
          backgroundColor: theme.primaryColor,
          backgroundImage: conversation.otherUserAvatar != null
              ? NetworkImage(conversation.otherUserAvatar!)
              : null,
          child: conversation.otherUserAvatar == null
              ? Text(
                  _getInitials(conversation.otherUserDisplayName),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                )
              : null,
        ),
        
        // Contenu principal
        title: Row(
          children: [
            // Nom de l'autre utilisateur
            Expanded(
              child: Text(
                conversation.otherUserDisplayName,
                style: TextStyle(
                  fontWeight: hasUnreadMessages ? FontWeight.bold : FontWeight.w500,
                  fontSize: 16,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            
            // Timestamp du dernier message
            if (conversation.lastMessage != null)
              Text(
                _formatTimestamp(conversation.lastMessage!.createdAt),
                style: TextStyle(
                  color: hasUnreadMessages 
                      ? theme.primaryColor 
                      : Colors.grey[600],
                  fontSize: 12,
                  fontWeight: hasUnreadMessages ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
          ],
        ),
        
        // Dernière message ou statut
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (conversation.lastMessage != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  // Contenu du dernier message
                  Expanded(
                    child: Text(
                      conversation.lastMessage!.content,
                      style: TextStyle(
                        color: hasUnreadMessages 
                            ? Colors.black87 
                            : Colors.grey[600],
                        fontWeight: hasUnreadMessages ? FontWeight.w500 : FontWeight.normal,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  
                  // Badge des messages non lus
                  if (hasUnreadMessages) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: theme.primaryColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        conversation.unreadCount > 99 
                            ? '99+' 
                            : conversation.unreadCount.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ] else ...[
              const SizedBox(height: 4),
              Text(
                'Aucun message',
                style: TextStyle(
                  color: Colors.grey[500],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ],
        ),
        
        // Indicateur visuel pour les conversations non lues
        trailing: hasUnreadMessages
            ? Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: theme.primaryColor,
                  shape: BoxShape.circle,
                ),
              )
            : null,
      ),
    );
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

  /// Formate le timestamp pour l'affichage
  String _formatTimestamp(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    // Aujourd'hui
    if (difference.inDays == 0) {
      final hour = dateTime.hour.toString().padLeft(2, '0');
      final minute = dateTime.minute.toString().padLeft(2, '0');
      return '$hour:$minute';
    }
    
    // Hier
    if (difference.inDays == 1) {
      return 'Hier';
    }
    
    // Cette semaine (derniers 7 jours)
    if (difference.inDays < 7) {
      final weekdays = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];
      return weekdays[dateTime.weekday - 1];
    }
    
    // Plus ancien
    final day = dateTime.day.toString().padLeft(2, '0');
    final month = dateTime.month.toString().padLeft(2, '0');
    return '$day/$month';
  }
}