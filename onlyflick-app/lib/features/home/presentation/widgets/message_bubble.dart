// onlyflick-app/lib/features/messaging/widgets/message_bubble.dart
import 'package:flutter/material.dart';
import '../../../../core/models/message_models.dart';

/// Widget pour afficher une bulle de message avec design premium OnlyFlick
class MessageBubble extends StatefulWidget {
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
  State<MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<MessageBubble>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutBack,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return FadeTransition(
      opacity: _fadeAnimation,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Padding(
          padding: EdgeInsets.only(
            left: widget.isCurrentUser ? 50 : 0,
            right: widget.isCurrentUser ? 0 : 50,
            bottom: 12,
          ),
          child: Row(
            mainAxisAlignment: widget.isCurrentUser 
                ? MainAxisAlignment.end 
                : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Avatar pour les messages des autres utilisateurs
              if (!widget.isCurrentUser && widget.showAvatar) 
                _buildOtherUserAvatar(theme),
              if (!widget.isCurrentUser && !widget.showAvatar) 
                const SizedBox(width: 44),
              
              // Bulle de message
              Flexible(
                child: Column(
                  crossAxisAlignment: widget.isCurrentUser 
                      ? CrossAxisAlignment.end 
                      : CrossAxisAlignment.start,
                  children: [
                    // Nom de l'expéditeur (seulement pour les autres utilisateurs)
                    if (!widget.isCurrentUser && widget.showAvatar) 
                      _buildSenderName(),
                    
                    if (!widget.isCurrentUser && widget.showAvatar)
                      const SizedBox(height: 4),
                    
                    // Bulle du message principal
                    _buildMessageContainer(theme),
                    
                    const SizedBox(height: 4),
                    
                    // Heure et statut du message
                    _buildMessageFooter(),
                  ],
                ),
              ),
              
              // Espace pour les messages de l'utilisateur actuel
              if (widget.isCurrentUser) const SizedBox(width: 12),
            ],
          ),
        ),
      ),
    );
  }

  /// Avatar pour les autres utilisateurs avec effet premium
  Widget _buildOtherUserAvatar(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.only(right: 12, bottom: 24),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: theme.primaryColor.withOpacity(0.2),
            blurRadius: 6,
            spreadRadius: 1,
          ),
        ],
      ),
      child: CircleAvatar(
        radius: 18,
        backgroundColor: theme.primaryColor,
        backgroundImage: widget.message.senderAvatar != null && 
                         widget.message.senderAvatar!.isNotEmpty
            ? NetworkImage(widget.message.senderAvatar!)
            : null,
        child: widget.message.senderAvatar == null || 
               widget.message.senderAvatar!.isEmpty
            ? Text(
                _getInitials(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              )
            : null,
      ),
    );
  }

  /// Nom de l'expéditeur avec style premium
  Widget _buildSenderName() {
    return Padding(
      padding: const EdgeInsets.only(left: 16),
      child: Text(
        widget.message.senderDisplayName,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Colors.grey[600],
          letterSpacing: 0.2,
        ),
      ),
    );
  }

  /// Container principal du message avec design premium
  Widget _buildMessageContainer(ThemeData theme) {
    return Hero(
      tag: 'message_${widget.message.id}',
      child: Material(
        color: Colors.transparent,
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.75,
            minWidth: 80,
          ),
          decoration: BoxDecoration(
            gradient: widget.isCurrentUser
                ? LinearGradient(
                    colors: [
                      theme.primaryColor,
                      theme.primaryColor.withOpacity(0.85),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: widget.isCurrentUser ? null : Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(20),
              topRight: const Radius.circular(20),
              bottomLeft: widget.isCurrentUser 
                  ? const Radius.circular(20) 
                  : const Radius.circular(6),
              bottomRight: widget.isCurrentUser 
                  ? const Radius.circular(6) 
                  : const Radius.circular(20),
            ),
            boxShadow: [
              BoxShadow(
                color: widget.isCurrentUser
                    ? theme.primaryColor.withOpacity(0.3)
                    : Colors.black.withOpacity(0.08),
                blurRadius: widget.isCurrentUser ? 12 : 8,
                offset: const Offset(0, 2),
                spreadRadius: widget.isCurrentUser ? 1 : 0,
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Text(
              widget.message.content,
              style: TextStyle(
                fontSize: 16,
                color: widget.isCurrentUser 
                    ? Colors.white 
                    : const Color(0xFF1A1A1A),
                height: 1.4,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Footer avec heure et statut du message
  Widget _buildMessageFooter() {
    return Padding(
      padding: EdgeInsets.only(
        left: widget.isCurrentUser ? 0 : 16,
        right: widget.isCurrentUser ? 16 : 0,
        top: 2,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _formatTime(widget.message.createdAt),
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[500],
              fontWeight: FontWeight.w400,
            ),
          ),
          
          // Indicateur de statut pour les messages envoyés
          if (widget.isCurrentUser) ...[
            const SizedBox(width: 4),
            Icon(
              Icons.done_rounded, 
              size: 14,
              color: Colors.grey[500],
            ),
          ],
        ],
      ),
    );
  }

  /// Génère les initiales à partir du nom de l'expéditeur
  String _getInitials() {
    // Essayer d'abord avec prénom et nom
    if (widget.message.senderFirstName != null && 
        widget.message.senderFirstName!.isNotEmpty &&
        widget.message.senderLastName != null && 
        widget.message.senderLastName!.isNotEmpty) {
      return '${widget.message.senderFirstName![0]}${widget.message.senderLastName![0]}'.toUpperCase();
    }
    
    // Sinon essayer avec le username
    if (widget.message.senderUsername != null && 
        widget.message.senderUsername!.isNotEmpty) {
      return widget.message.senderUsername![0].toUpperCase();
    }
    
    // Fallback avec le display name
    final displayName = widget.message.senderDisplayName;
    final parts = displayName.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    } else if (parts.isNotEmpty) {
      return parts[0][0].toUpperCase();
    }
    
    return 'U';
  }

  /// Formate l'heure d'envoi du message avec style OnlyFlick
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
    
    // Si c'est cette semaine
    if (difference.inDays < 7) {
      final weekdays = ['Dim', 'Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam'];
      final weekday = weekdays[dateTime.weekday % 7];
      final hour = dateTime.hour.toString().padLeft(2, '0');
      final minute = dateTime.minute.toString().padLeft(2, '0');
      return '$weekday $hour:$minute';
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