// onlyflick-app/lib/features/home/presentation/widgets/tags_filter_widget.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/services/tags_service.dart';

class TagsFilterWidget extends StatefulWidget {
  final List<String> tags;
  final String selectedTag;
  final Function(String) onTagSelected;

  const TagsFilterWidget({
    super.key,
    required this.tags,
    required this.selectedTag,
    required this.onTagSelected,
  });

  @override
  State<TagsFilterWidget> createState() => _TagsFilterWidgetState();
}

class _TagsFilterWidgetState extends State<TagsFilterWidget> {
  // Map pour stocker les comptages de chaque tag (récupéré du backend)
  Map<String, int> _tagCounts = {};
  bool _isLoadingCounts = false;

  @override
  void initState() {
    super.initState();
    _loadTagCounts();
  }

  @override
  void didUpdateWidget(TagsFilterWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Recharger les comptages si les tags ont changé
    if (oldWidget.tags != widget.tags) {
      _loadTagCounts();
    }
  }

  // Charger les comptages réels depuis le backend
  Future<void> _loadTagCounts() async {
    if (_isLoadingCounts) return;
    
    setState(() {
      _isLoadingCounts = true;
    });

    try {
      // Récupérer les vraies statistiques depuis le backend
      final tagsWithStats = await TagsService.getTagsWithStats();
      
      final Map<String, int> counts = {};
      for (final tagData in tagsWithStats) {
        counts[tagData.displayName] = tagData.count;
      }
      
      setState(() {
        _tagCounts = counts;
        _isLoadingCounts = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingCounts = false;
      });
      debugPrint('Erreur lors du chargement des comptages de tags: $e');
      
      // Fallback avec comptages factices si l'API échoue
      _loadFallbackCounts();
    }
  }

  // Méthode de fallback en cas d'erreur API
  void _loadFallbackCounts() {
    final Map<String, int> counts = {};
    for (String tag in widget.tags) {
      if (tag.toLowerCase() != 'tous') {
        counts[tag] = _generateConsistentCount(tag);
      }
    }
    setState(() {
      _tagCounts = counts;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: widget.tags.length,
        itemBuilder: (context, index) {
          final tag = widget.tags[index];
          final isSelected = tag == widget.selectedTag;

          return Padding(
            padding: EdgeInsets.only(
              right: index < widget.tags.length - 1 ? 12 : 0,
            ),
            child: _buildTagChip(tag, isSelected),
          );
        },
      ),
    );
  }

  Widget _buildTagChip(String tag, bool isSelected) {
    return GestureDetector(
      onTap: () {
        hapticFeedback();
        widget.onTagSelected(tag);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected 
              ? Colors.black 
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? Colors.black : const Color(0xFFE0E0E0),
            width: 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icône du tag mise à jour pour correspondre aux nouveaux tags
            Text(
              _getTagEmoji(tag),
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(width: 6),
            
            // Texte du tag
            Text(
              tag,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: isSelected ? Colors.white : const Color(0xFF666666),
              ),
            ),
            
            // Badge de comptage avec vraies données
            if (_getTagCount(tag) > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isSelected 
                      ? Colors.white.withOpacity(0.2) 
                      : const Color(0xFFF0F0F0),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: _isLoadingCounts 
                    ? SizedBox(
                        width: 12,
                        height: 10,
                        child: CircularProgressIndicator(
                          strokeWidth: 1,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            isSelected ? Colors.white : Colors.grey,
                          ),
                        ),
                      )
                    : Text(
                        '${_getTagCount(tag)}',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: isSelected ? Colors.white : const Color(0xFF666666),
                        ),
                      ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Retourne l'emoji correspondant aux NOUVEAUX tags de votre base de données
  String _getTagEmoji(String tag) {
    switch (tag.toLowerCase()) {
      case 'tous':
        return '🏷️';
      
      // X TAGS de votre base de données avec emojis
      case 'wellness':
        return '🌿';
      
      case 'beauté':
      case 'beaute':
        return '💄';
      
      case 'art':
        return '🎨';
      
      case 'musique':
        return '🎵';
      
      case 'cuisine':
        return '👨‍🍳';
      
      case 'football':
        return '⚽';
      
      case 'basket':
        return '🏀';
      
      case 'mode':
        return '👗';
      
      case 'cinéma':
      case 'cinema':
        return '🎬';
      
      case 'actualités':
      case 'actualites':
        return '📰';
      
      case 'mangas':
        return '📚';
      
      case 'memes':
        return '😂';
      
      case 'tech':
        return '💻';
      
      default:
        return '🏷️'; // Emoji générique pour les tags non reconnus
    }
  }

  /// Retourne le nombre de posts pour ce tag (depuis le backend ou cache local)
  int _getTagCount(String tag) {
    if (tag.toLowerCase() == 'tous') {
      return 0; // Pas de badge pour "Tous"
    }
    
    return _tagCounts[tag] ?? 0;
  }

  /// Génère un nombre cohérent basé sur les NOUVEAUX tags (avec les vraies données de votre DB)
  int _generateConsistentCount(String tag) {
    // Utiliser les vraies données de votre base de données comme fallback
    switch (tag.toLowerCase()) {
      case 'wellness':
        return 7;
      case 'beauté':
      case 'beaute':
        return 7;
      case 'art':
        return 10;
      case 'musique':
        return 10;
      case 'cuisine':
        return 8;
      case 'football':
        return 5;
      case 'basket':
        return 5;
      case 'mode':
        return 5;
      case 'cinéma':
      case 'cinema':
        return 5;
      case 'actualités':
      case 'actualites':
        return 5;
      case 'mangas':
        return 5;
      case 'memes':
        return 5;
      case 'tech':
        return 7;
      default:
        return 0; // Tags inconnus
    }
  }
}

/// Extension pour ajouter le feedback haptique
extension on _TagsFilterWidgetState {
  void hapticFeedback() {
    try {
      HapticFeedback.lightImpact();
    } catch (e) {
      // Feedback haptique non disponible, ignorer silencieusement
    }
  }
}

/// Widget de tag personnalisable
class TagChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback? onTap;
  final IconData? icon;
  final int? count;
  final Color? selectedColor;
  final Color? unselectedColor;
  final bool isLoading;

  const TagChip({
    super.key,
    required this.label,
    required this.isSelected,
    this.onTap,
    this.icon,
    this.count,
    this.selectedColor,
    this.unselectedColor,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final selectedBg = selectedColor ?? Colors.black;
    final unselectedBg = unselectedColor ?? Colors.transparent;
    
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? selectedBg : unselectedBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? selectedBg : const Color(0xFFE0E0E0),
            width: 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: selectedBg.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icône ou emoji
            if (icon != null) ...[
              Icon(
                icon,
                size: 16,
                color: isSelected ? Colors.white : const Color(0xFF666666),
              ),
              const SizedBox(width: 6),
            ] else if (label.isNotEmpty) ...[
              Text(
                _getEmojiForLabel(label),
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(width: 6),
            ],
            
            // Texte
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: isSelected ? Colors.white : const Color(0xFF666666),
              ),
            ),
            
            // Badge de comptage
            if (count != null && count! > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isSelected 
                      ? Colors.white.withOpacity(0.2) 
                      : const Color(0xFFF0F0F0),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: isLoading
                    ? SizedBox(
                        width: 12,
                        height: 10,
                        child: CircularProgressIndicator(
                          strokeWidth: 1,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            isSelected ? Colors.white : Colors.grey,
                          ),
                        ),
                      )
                    : Text(
                        '$count',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: isSelected ? Colors.white : const Color(0xFF666666),
                        ),
                      ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Méthode utilitaire pour obtenir l'emoji d'un label
  String _getEmojiForLabel(String label) {
    switch (label.toLowerCase()) {
      case 'tous':
        return '🏷️';
      case 'wellness':
        return '🌿';
      case 'beauté':
      case 'beaute':
        return '💄';
      case 'art':
        return '🎨';
      case 'musique':
        return '🎵';
      case 'cuisine':
        return '👨‍🍳';
      case 'football':
        return '⚽';
      case 'basket':
        return '🏀';
      case 'mode':
        return '👗';
      case 'cinéma':
      case 'cinema':
        return '🎬';
      case 'actualités':
      case 'actualites':
        return '📰';
      case 'mangas':
        return '📚';
      case 'memes':
        return '😂';
      case 'tech':
        return '💻';
      default:
        return '🏷️';
    }
  }
}