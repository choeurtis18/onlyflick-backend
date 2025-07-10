// lib/features/search/widgets/search_suggestions_widget.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/models/search_models.dart';

class SearchSuggestionsWidget extends StatefulWidget {
  final List<UserSearchResult> suggestions;
  final Function(UserSearchResult) onUserTap;
  final VoidCallback onDismiss;
  final double maxHeight;

  const SearchSuggestionsWidget({
    super.key,
    required this.suggestions,
    required this.onUserTap,
    required this.onDismiss,
    this.maxHeight = 300,
  });

  @override
  State<SearchSuggestionsWidget> createState() => _SearchSuggestionsWidgetState();
}

class _SearchSuggestionsWidgetState extends State<SearchSuggestionsWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));
    
    _slideAnimation = Tween<double>(
      begin: -20.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));
    
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _dismiss() async {
    await _animationController.reverse();
    widget.onDismiss();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.suggestions.isEmpty) {
      return const SizedBox.shrink();
    }

    return GestureDetector(
      onTap: _dismiss,
      child: Container(
        color: Colors.black.withOpacity(0.4), // Overlay plus visible
        child: Stack(
          children: [
            // Zone de tap pour fermer
            Positioned.fill(
              child: GestureDetector(
                onTap: _dismiss,
                child: Container(color: Colors.transparent),
              ),
            ),
            
            // Suggestions dropdown
            Positioned(
              top: 0,
              left: 16,
              right: 16,
              child: AnimatedBuilder(
                animation: _animationController,
                builder: (context, child) {
                  return Transform.translate(
                    offset: Offset(0, _slideAnimation.value),
                    child: Opacity(
                      opacity: _fadeAnimation.value,
                      child: _buildSuggestionsList(),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestionsList() {
    final maxHeight = widget.maxHeight;
    final itemHeight = 80.0; // Plus haut pour plus de présence
    final minHeight = 200.0;
    final calculatedHeight = (widget.suggestions.length * itemHeight) + 40; // +40 pour padding
    final actualHeight = calculatedHeight.clamp(minHeight, maxHeight);

    return Container(
      constraints: BoxConstraints(
        minHeight: minHeight, // Hauteur minimum garantie
        maxHeight: actualHeight,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20), // Plus arrondi
        border: Border.all(color: Colors.grey[300]!, width: 1.5), // Bordure plus marquée
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2), // Ombre plus prononcée
            blurRadius: 30,
            offset: const Offset(0, 12),
            spreadRadius: 4,
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 60,
            offset: const Offset(0, 25),
            spreadRadius: 0,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header élégant
            
            // Liste des utilisateurs avec plus d'espace
            Flexible(
              child: widget.suggestions.isNotEmpty
                  ? ListView.builder(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 10),
                      physics: widget.suggestions.length > 3 
                          ? const AlwaysScrollableScrollPhysics()
                          : const NeverScrollableScrollPhysics(),
                      itemCount: widget.suggestions.length,
                      itemBuilder: (context, index) {
                        final user = widget.suggestions[index];
                        final isLast = index == widget.suggestions.length - 1;
                        
                        return _buildUserSuggestion(user, isLast, index);
                      },
                    )
                  : _buildEmptySpace(),
            ),
            
          ],
        ),
      ),
    );
  }

  

  Widget _buildEmptySpace() {
    return Container(
      height: 100,
      child: Center(
        child: Text(
          'Recherche en cours...',
          style: GoogleFonts.inter(
            fontSize: 14,
            color: Colors.grey[500],
          ),
        ),
      ),
    );
  }

  
  Widget _buildUserSuggestion(UserSearchResult user, bool isLast, int index) {
    return GestureDetector(
      onTap: () => widget.onUserTap(user),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.grey[200]!,
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
        
            
            
            // Avatar utilisateur plus stylé
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.grey[300]!,
                  width: 2.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: CircleAvatar(
                radius: 22,
                backgroundImage: user.avatarUrl != null && user.avatarUrl!.isNotEmpty
                    ? NetworkImage(user.avatarUrl!)
                    : null,
                backgroundColor: Colors.grey[100],
                child: user.avatarUrl == null || user.avatarUrl!.isEmpty
                    ? Text(
                        user.firstName.isNotEmpty 
                            ? user.firstName[0].toUpperCase() 
                            : '?',
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[600],
                        ),
                      )
                    : null,
              ),
            ),
            
            const SizedBox(width: 16),
            
            // Informations utilisateur enrichies
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Nom complet avec badge
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          '${user.firstName} ${user.lastName}',
                          style: GoogleFonts.inter(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            color: Colors.black,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (user.isCreator) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.blue[600],
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.verified,
                                size: 12,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 2),
                              Text(
                                'Créateur',
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                  
                  const SizedBox(height: 4),
                  
                  // Username avec style
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '@${user.username}',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: Colors.grey[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  
                  // Stats si créateur
                  if (user.isCreator && user.followersCount > 0) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          Icons.people,
                          size: 14,
                          color: Colors.grey[500],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${user.followersCount} abonné${user.followersCount > 1 ? 's' : ''}',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            
            // Flèche stylée
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Widget pour afficher un état "Aucun résultat"
class NoResultsSuggestionWidget extends StatelessWidget {
  final String query;
  final VoidCallback onDismiss;

  const NoResultsSuggestionWidget({
    super.key,
    required this.query,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onDismiss,
      child: Container(
        color: Colors.black.withOpacity(0.4),
        child: Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                onTap: onDismiss,
                child: Container(color: Colors.transparent),
              ),
            ),
            Positioned(
              top: 0,
              left: 16,
              right: 16,
              child: Container(
                constraints: const BoxConstraints(
                  minHeight: 280, // Hauteur minimum plus importante
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.grey[300]!, width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 30,
                      offset: const Offset(0, 12),
                      spreadRadius: 4,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(24, 20, 20, 16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.red[50]!,
                            Colors.white,
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(20),
                          topRight: Radius.circular(20),
                        ),
                        border: Border(
                          bottom: BorderSide(
                            color: Colors.grey[200]!,
                            width: 1,
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.red[100],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.search_off,
                              size: 24,
                              color: Colors.red[600],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Aucun résultat',
                                  style: GoogleFonts.inter(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey[800],
                                  ),
                                ),
                                Text(
                                  'pour "$query"',
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          GestureDetector(
                            onTap: onDismiss,
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                Icons.close,
                                size: 20,
                                color: Colors.grey[600],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // Contenu principal
                    Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        children: [
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Colors.grey[300]!,
                                width: 2,
                              ),
                            ),
                            child: Icon(
                              Icons.person_search,
                              size: 40,
                              color: Colors.grey[500],
                            ),
                          ),
                          
                          const SizedBox(height: 24),
                          
                          Text(
                            'Utilisateur introuvable',
                            style: GoogleFonts.inter(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[700],
                            ),
                          ),
                          
                          const SizedBox(height: 8),
                          
                          Text(
                            'Vérifiez l\'orthographe ou essayez\navec un autre nom d\'utilisateur',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              color: Colors.grey[500],
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // Footer
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(20),
                          bottomRight: Radius.circular(20),
                        ),
                        border: Border(
                          top: BorderSide(
                            color: Colors.grey[200]!,
                            width: 1,
                          ),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.keyboard_arrow_up,
                            size: 16,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Tapez en dehors pour fermer',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}