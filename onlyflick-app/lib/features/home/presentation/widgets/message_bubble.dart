// onlyflick-app/lib/features/messaging/widgets/message_bubble.dart
import 'package:flutter/material.dart';
import '../../../../core/models/message_models.dart'; 

/// Widget pour afficher un message sous forme de bulle
class MessageBubble extends StatelessWidget {
  final Message message;
  final bool isCurrentUser;
  final bool showAvatar;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isCurrentUser,
    this.showAvatar = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 8),
      child: Row(
        mainAxisAlignment: isCurrentUser 
            ? MainAxisAlignment.end 
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Avatar pour les messages des autres utilisateurs
          if (!isCurrentUser) ...[
            if (showAvatar)
              CircleAvatar(
                radius: 16,
                backgroundColor: theme.primaryColor,
                backgroundImage: message.senderAvatar != null
                    ? NetworkImage(message.senderAvatar!)
                    : null,
                child: message.senderAvatar == null
                    ? Text(
                        _getInitials(message.senderDisplayName),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : null,
              )
            else
              const SizedBox(width: 32), // Espace pour aligner avec les avatars
            const SizedBox(width: 8),
          ],
          
          // Bulle du message
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.75,
              ),
              child: Column(
                crossAxisAlignment: isCurrentUser 
                    ? CrossAxisAlignment.end 
                    : CrossAxisAlignment.start,
                children: [
                  // Nom de l'expéditeur (pour les messages des autres)
                  if (!isCurrentUser && showAvatar)
                    Padding(
                      padding: const EdgeInsets.only(left: 12, bottom: 2),
                      child: Text(
                        message.senderDisplayName,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  
                  // Contenu du message
                  Container(
                    decoration: BoxDecoration(
                      color: isCurrentUser
                          ? theme.primaryColor
                          : Colors.grey[200],
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(16),
                        topRight: const Radius.circular(16),
                        bottomLeft: Radius.circular(isCurrentUser ? 16 : 4),
                        bottomRight: Radius.circular(isCurrentUser ? 4 : 16),
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Contenu du message
                        Text(
                          message.content,
                          style: TextStyle(
                            color: isCurrentUser 
                                ? Colors.white 
                                : Colors.black87,
                            fontSize: 15,
                            height: 1.3,
                          ),
                        ),
                        
                        const SizedBox(height: 4),
                        
                        // Timestamp
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _formatTime(message.createdAt),
                              style: TextStyle(
                                color: isCurrentUser 
                                    ? Colors.white70 
                                    : Colors.grey[600],
                                fontSize: 11,
                              ),
                            ),
                            
                            // Indicateur de statut pour les messages envoyés
                            if (isCurrentUser) ...[
                              const SizedBox(width: 4),
                              Icon(
                                Icons.done, // TODO: Ajouter Icons.done_all pour "lu"
                                size: 12,
                                color: Colors.white70,
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
          
          // Espace pour les messages de l'utilisateur actuel
          if (isCurrentUser) ...[
            const SizedBox(width: 8),
            const SizedBox(width: 32), // Espace pour équilibrer avec l'avatar
          ],
        ],
      ),
    );
  }

  /// Génère les initiales à partir du nom de l'expéditeur
  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    } else if (parts.isNotEmpty) {
      return parts[0][0].toUpperCase();
    }
    return '?';
  }

  /// Formate l'heure d'envoi du message
  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    // Si c'est aujourd'hui, afficher seulement l'heure
    if (difference.inDays == 0) {
      final hour = dateTime.hour.toString().padLeft(2, '0');
      final minute = dateTime.minute.toString().padLeft(2, '0');
      return '$hour:$minute';
    }
    
    // Si c'est hier
    if (difference.inDays == 1) {
      final hour = dateTime.hour.toString().padLeft(2, '0');
      final minute = dateTime.minute.toString().padLeft(2, '0');
      return 'Hier $hour:$minute';
    }
    
    // Si c'est plus ancien, afficher la date
    final day = dateTime.day.toString().padLeft(2, '0');
    final month = dateTime.month.toString().padLeft(2, '0');
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    
    // Si c'est cette année
    if (dateTime.year == now.year) {
      return '$day/$month $hour:$minute';
    }
    
    // Si c'est une année différente
    return '$day/$month/${dateTime.year} $hour:$minute';
  }
}