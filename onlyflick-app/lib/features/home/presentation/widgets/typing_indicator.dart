// onlyflick-app/lib/features/messaging/widgets/typing_indicator.dart
import 'package:flutter/material.dart';

/// Widget qui affiche l'indicateur de frappe animé avec design premium OnlyFlick
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
  late AnimationController _breathingController;
  late AnimationController _dotsController;
  late Animation<double> _breathingAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    
    // Animation de "respiration" pour la bulle
    _breathingController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    
    // Animation pour les points de frappe
    _dotsController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    
    _breathingAnimation = Tween<double>(
      begin: 0.95,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _breathingController,
      curve: Curves.easeInOut,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _breathingController,
      curve: Curves.easeOut,
    ));
    
    // Démarrer les animations
    _breathingController.repeat(reverse: true);
    _dotsController.repeat();
    
    // Animation d'entrée
    _breathingController.forward();
  }

  @override
  void dispose() {
    _breathingController.dispose();
    _dotsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return FadeTransition(
      opacity: _fadeAnimation,
      child: ScaleTransition(
        scale: _breathingAnimation,
        child: Padding(
          padding: const EdgeInsets.only(left: 0, right: 50, bottom: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Avatar avec effet premium
              if (widget.showAvatar) _buildPremiumAvatar(theme),
              if (widget.showAvatar) const SizedBox(width: 12),
              
              // Bulle de frappe premium
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Nom de l'utilisateur qui tape
                    if (widget.userDisplayName != null && widget.showAvatar)
                      _buildUserName(),
                    
                    if (widget.userDisplayName != null && widget.showAvatar)
                      const SizedBox(height: 4),
                    
                    // Bulle avec animation premium
                    _buildTypingBubble(theme),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Avatar premium avec effet de glow
  Widget _buildPremiumAvatar(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: theme.primaryColor.withOpacity(0.3),
            blurRadius: 8,
            spreadRadius: 1,
          ),
        ],
      ),
      child: CircleAvatar(
        radius: 18,
        backgroundColor: theme.primaryColor.withOpacity(0.1),
        backgroundImage: widget.avatarUrl != null && widget.avatarUrl!.isNotEmpty
            ? NetworkImage(widget.avatarUrl!)
            : null,
        child: widget.avatarUrl == null || widget.avatarUrl!.isEmpty
            ? Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      theme.primaryColor.withOpacity(0.8),
                      theme.primaryColor.withOpacity(0.6),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Center(
                  child: Text(
                    _getInitials(widget.userDisplayName ?? '?'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              )
            : null,
      ),
    );
  }

  /// Nom de l'utilisateur avec style premium
  Widget _buildUserName() {
    return Padding(
      padding: const EdgeInsets.only(left: 16),
      child: Text(
        widget.userDisplayName!,
        style: TextStyle(
          fontSize: 13,
          color: Colors.grey[600],
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
        ),
      ),
    );
  }

  /// Bulle de frappe avec design premium
  Widget _buildTypingBubble(ThemeData theme) {
    return AnimatedBuilder(
      animation: _breathingAnimation,
      child: Container(
        constraints: const BoxConstraints(minWidth: 80),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
            bottomLeft: Radius.circular(6),
            bottomRight: Radius.circular(20),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
            BoxShadow(
              color: theme.primaryColor.withOpacity(0.1),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'écrit',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 15,
                  fontStyle: FontStyle.italic,
                  fontWeight: FontWeight.w400,
                ),
              ),
              const SizedBox(width: 8),
              _buildPremiumTypingDots(theme),
            ],
          ),
        ),
      ),
      builder: (context, child) {
        return Transform.scale(
          scale: _breathingAnimation.value,
          child: child,
        );
      },
    );
  }

  /// Animation premium des points de frappe
  Widget _buildPremiumTypingDots(ThemeData theme) {
    return AnimatedBuilder(
      animation: _dotsController,
      builder: (context, child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (index) {
            // Chaque point a un délai différent dans l'animation
            final delay = index * 0.3;
            final animationValue = ((_dotsController.value - delay) % 1.0).clamp(0.0, 1.0);
            
            // Animation en forme de vague pour chaque point
            final scale = 0.6 + (0.8 * (1 + (animationValue * 2 - 1).abs()) / 2);
            final opacity = 0.3 + (0.7 * (1 - (animationValue * 2 - 1).abs()));
            
            return Transform.scale(
              scale: scale,
              child: Container(
                margin: EdgeInsets.only(left: index > 0 ? 4 : 0),
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      theme.primaryColor.withOpacity(opacity),
                      theme.primaryColor.withOpacity(opacity * 0.7),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: theme.primaryColor.withOpacity(opacity * 0.3),
                      blurRadius: 4,
                      spreadRadius: 0.5,
                    ),
                  ],
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

/// Widget de conteneur premium pour les indicateurs de frappe multiples
class TypingIndicatorContainer extends StatefulWidget {
  final Map<int, String> typingUsers; // userId -> displayName
  final Map<int, String?> userAvatars; // userId -> avatarUrl

  const TypingIndicatorContainer({
    super.key,
    required this.typingUsers,
    this.userAvatars = const {},
  });

  @override
  State<TypingIndicatorContainer> createState() => _TypingIndicatorContainerState();
}

class _TypingIndicatorContainerState extends State<TypingIndicatorContainer>
    with SingleTickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOut),
    );
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _fadeController, 
      curve: Curves.easeOutCubic,
    ));
    
    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.typingUsers.isEmpty) {
      return const SizedBox.shrink();
    }

    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: _buildTypingContent(),
      ),
    );
  }

  Widget _buildTypingContent() {
    // Si un seul utilisateur tape
    if (widget.typingUsers.length == 1) {
      final userId = widget.typingUsers.keys.first;
      final displayName = widget.typingUsers[userId];
      final avatarUrl = widget.userAvatars[userId];
      
      return TypingIndicator(
        userDisplayName: displayName,
        avatarUrl: avatarUrl,
        showAvatar: true,
      );
    }

    // Si plusieurs utilisateurs tapent - version premium
    final userNames = widget.typingUsers.values.take(2).join(' et ');
    final remainingCount = widget.typingUsers.length - 2;
    
    String displayText;
    if (remainingCount > 0) {
      displayText = '$userNames et $remainingCount autre${remainingCount > 1 ? 's' : ''}';
    } else {
      displayText = userNames;
    }

    return TypingIndicator(
      userDisplayName: displayText,
      showAvatar: false, // Pas d'avatar pour les groupes
    );
  }
}