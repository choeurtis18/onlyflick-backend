// lib/features/search/widgets/tags_filter_widget.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class TagsFilterWidget extends StatefulWidget {
  final List<String> tags;
  final String selectedTag;
  final Function(String) onTagSelected;
  final EdgeInsets? padding;

  const TagsFilterWidget({
    super.key,
    required this.tags,
    required this.selectedTag,
    required this.onTagSelected,
    this.padding,
  });

  @override
  State<TagsFilterWidget> createState() => _TagsFilterWidgetState();
}

class _TagsFilterWidgetState extends State<TagsFilterWidget>
    with SingleTickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  late AnimationController _animationController;
  
  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Color(0xFFF0F0F0), width: 1),
        ),
      ),
      child: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          return Transform.translate(
            offset: Offset(0, 20 * (1 - _animationController.value)),
            child: Opacity(
              opacity: _animationController.value,
              child: child,
            ),
          );
        },
        child: Container(
          height: 60,
          padding: widget.padding ?? const EdgeInsets.symmetric(vertical: 12),
          child: ListView.separated(
            controller: _scrollController,
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: widget.tags.length,
            separatorBuilder: (context, index) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final tag = widget.tags[index];
              final isSelected = tag == widget.selectedTag;
              
              return _buildTagChip(tag, isSelected);
            },
          ),
        ),
      ),
    );
  }

  Widget _buildTagChip(String tag, bool isSelected) {
    return GestureDetector(
      onTap: () => _onTagTap(tag),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.black : Colors.transparent,
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
            // Icône du tag (optionnelle)
            if (_getTagIcon(tag) != null) ...[
              Icon(
                _getTagIcon(tag),
                size: 16,
                color: isSelected ? Colors.white : const Color(0xFF666666),
              ),
              const SizedBox(width: 6),
            ],
            
            // Texte du tag
            Text(
              tag,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: isSelected ? Colors.white : const Color(0xFF666666),
              ),
            ),
            
            // Badge de comptage (optionnel)
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
                child: Text(
                  '${_getTagCount(tag)}',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? Colors.white : const Color(0xFF999999),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _onTagTap(String tag) {
    // Animation de feedback
    _animateTagTap();
    
    // Scroll automatique vers le tag sélectionné
    _scrollToSelectedTag(tag);
    
    // Appeler le callback
    widget.onTagSelected(tag);
    
    // Feedback haptique léger
    _hapticFeedback();
  }

  void _animateTagTap() {
    _animationController.reverse().then((_) {
      _animationController.forward();
    });
  }

  void _scrollToSelectedTag(String tag) {
    final index = widget.tags.indexOf(tag);
    if (index != -1 && _scrollController.hasClients) {
      const itemWidth = 100.0; // Largeur approximative d'un chip
      final scrollPosition = (index * itemWidth) - (MediaQuery.of(context).size.width / 2);
      
      _scrollController.animateTo(
        scrollPosition.clamp(0.0, _scrollController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _hapticFeedback() {
    // Feedback haptique léger (disponible sur iOS et Android)
    try {
      HapticFeedback.lightImpact();
    } catch (e) {
      // Ignore si le feedback haptique n'est pas disponible
    }
  }

  /// Retourne une icône appropriée pour le tag (optionnel)
  IconData? _getTagIcon(String tag) {
    switch (tag.toLowerCase()) {
      case 'tous':
        return Icons.apps;
      case 'photography':
        return Icons.camera_alt;
      case 'art':
        return Icons.palette;
      case 'music':
        return Icons.music_note;
      case 'fitness':
        return Icons.fitness_center;
      case 'travel':
        return Icons.flight;
      case 'food':
        return Icons.restaurant;
      case 'fashion':
        return Icons.style;
      case 'design':
        return Icons.design_services;
      case 'tech':
        return Icons.computer;
      default:
        return null;
    }
  }

  /// Retourne un nombre factice de posts pour ce tag (pour la démo)
  int _getTagCount(String tag) {
    // Génère un nombre cohérent basé sur le tag
    final seed = tag.hashCode;
    final random = seed.abs();
    
    switch (tag.toLowerCase()) {
      case 'tous':
        return 0; // Pas de badge pour "Tous"
      case 'photography':
        return 150 + (random % 50);
      case 'art':
        return 80 + (random % 40);
      case 'music':
        return 120 + (random % 30);
      case 'fitness':
        return 60 + (random % 20);
      case 'travel':
        return 90 + (random % 35);
      case 'food':
        return 110 + (random % 25);
      case 'fashion':
        return 70 + (random % 30);
      case 'design':
        return 45 + (random % 15);
      case 'tech':
        return 85 + (random % 20);
      default:
        return 20 + (random % 10);
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

/// Widget de tag personnalisable (version standalone)
class TagChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback? onTap;
  final IconData? icon;
  final int? count;
  final Color? selectedColor;
  final Color? unselectedColor;

  const TagChip({
    super.key,
    required this.label,
    required this.isSelected,
    this.onTap,
    this.icon,
    this.count,
    this.selectedColor,
    this.unselectedColor,
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
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 16,
                color: isSelected ? Colors.white : const Color(0xFF666666),
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: isSelected ? Colors.white : const Color(0xFF666666),
              ),
            ),
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
                child: Text(
                  '$count',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? Colors.white : const Color(0xFF999999),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}