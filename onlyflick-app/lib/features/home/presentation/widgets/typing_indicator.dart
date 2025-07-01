// onlyflick-app/lib/features/messaging/widgets/typing_indicator.dart
import 'package:flutter/material.dart';

/// Widget qui affiche l'indicateur de frappe animé
class TypingIndicator extends StatefulWidget {
  final String? userDisplayName;
  final bool showAvatar;
  final String? avatarUrl;

  const TypingIndicator({
    super.key,
    this.userDisplayName,
    this.showAvatar = true,
    this.avatarUrl,
  });

  @override
  State<TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Avatar
          if (widget.showAvatar) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: theme.primaryColor.withOpacity(0.3),
              backgroundImage: widget.avatarUrl != null
                  ? NetworkImage(widget.avatarUrl!)
                  : null,
              child: widget.avatarUrl == null
                  ? Text(
                      _getInitials(widget.userDisplayName ?? '?'),
                      style: TextStyle(
                        color: theme.primaryColor,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 8),
          ],
          
          // Bulle de frappe
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Nom de l'utilisateur qui tape
                if (widget.userDisplayName != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 12, bottom: 2),
                    child: Text(
                      widget.userDisplayName!,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                
                // Bulle avec animation
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                      bottomLeft: Radius.circular(4),
                      bottomRight: Radius.circular(16),
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'tape...',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _buildTypingDots(),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(width: 48), // Espace pour équilibrer avec l'avatar
        ],
      ),
    );
  }

  /// Construit l'animation des points de frappe
  Widget _buildTypingDots() {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Row(
          children: List.generate(3, (index) {
            // Chaque point a un délai différent dans l'animation
            final delay = index * 0.2;
            final animationValue = (_animation.value - delay).clamp(0.0, 1.0);
            final opacity = (animationValue * 2).clamp(0.3, 1.0);
            final scale = 0.8 + (animationValue * 0.4);
            
            return Transform.scale(
              scale: scale,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 1),
                width: 4,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[500]!.withOpacity(opacity),
                  shape: BoxShape.circle,
                ),
              ),
            );
          }),
        );
      },
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
}

/// Widget de conteneur pour les indicateurs de frappe multiples
class TypingIndicatorContainer extends StatelessWidget {
  final Map<int, String> typingUsers; // userId -> displayName
  final Map<int, String?> userAvatars; // userId -> avatarUrl

  const TypingIndicatorContainer({
    super.key,
    required this.typingUsers,
    this.userAvatars = const {},
  });

  @override
  Widget build(BuildContext context) {
    if (typingUsers.isEmpty) {
      return const SizedBox.shrink();
    }

    // Si un seul utilisateur tape
    if (typingUsers.length == 1) {
      final userId = typingUsers.keys.first;
      final displayName = typingUsers[userId];
      final avatarUrl = userAvatars[userId];
      
      return TypingIndicator(
        userDisplayName: displayName,
        avatarUrl: avatarUrl,
      );
    }

    // Si plusieurs utilisateurs tapent
    final userNames = typingUsers.values.take(3).join(', ');
    final remainingCount = typingUsers.length - 3;
    final displayText = remainingCount > 0
        ? '$userNames et ${remainingCount} autre${remainingCount > 1 ? 's' : ''}'
        : userNames;

    return TypingIndicator(
      userDisplayName: displayText,
      showAvatar: false, // Pas d'avatar pour les groupes
    );
  }
}