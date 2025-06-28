// lib/features/search/presentation/widgets/search_bar_widget.dart

import 'package:flutter/material.dart';

/// Widget de barre de recherche moderne avec animations
class SearchBarWidget extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final Function(String) onSubmitted;
  final VoidCallback onClear;
  final String? hintText;
  final bool enabled;
  final Widget? leadingIcon;
  final Color? backgroundColor;
  final Color? borderColor;
  final double borderRadius;
  final EdgeInsets? contentPadding;

  const SearchBarWidget({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.onSubmitted,
    required this.onClear,
    this.hintText,
    this.enabled = true,
    this.leadingIcon,
    this.backgroundColor,
    this.borderColor,
    this.borderRadius = 14.0,
    this.contentPadding,
  });

  @override
  State<SearchBarWidget> createState() => _SearchBarWidgetState();
}

class _SearchBarWidgetState extends State<SearchBarWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    
    // Animation pour le bouton clear
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    
    _scaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    ));
    
    _opacityAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    // Écouter les changements de texte
    widget.controller.addListener(_onTextChanged);
    _updateButtonState();
  }

  @override
  void didUpdateWidget(SearchBarWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Si le controller a changé, mettre à jour les listeners
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onTextChanged);
      widget.controller.addListener(_onTextChanged);
      _updateButtonState();
    }
  }

  void _onTextChanged() {
    _updateButtonState();
  }

  void _updateButtonState() {
    final hasText = widget.controller.text.isNotEmpty;
    if (hasText != _hasText) {
      setState(() {
        _hasText = hasText;
      });
      
      if (hasText) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    }
  }

  void _onClearPressed() {
    widget.controller.clear();
    widget.onClear();
    widget.focusNode.requestFocus();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: widget.controller,
        focusNode: widget.focusNode,
        enabled: widget.enabled,
        onSubmitted: widget.onSubmitted,
        textInputAction: TextInputAction.search,
        style: const TextStyle(
          fontSize: 16,
          color: Colors.black,
          fontWeight: FontWeight.w400,
        ),
        decoration: InputDecoration(
          hintText: widget.hintText ?? 'Rechercher des posts, utilisateurs...',
          hintStyle: TextStyle(
            color: Colors.grey[500],
            fontSize: 16,
            fontWeight: FontWeight.w400,
          ),
          prefixIcon: widget.leadingIcon ?? _buildLeadingIcon(),
          suffixIcon: _buildSuffixIcon(),
          filled: true,
          fillColor: widget.backgroundColor ?? Colors.grey[100],
          contentPadding: widget.contentPadding ?? 
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            borderSide: BorderSide(
              color: widget.borderColor ?? Colors.transparent,
              width: 1,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            borderSide: BorderSide(
              color: widget.borderColor ?? Colors.grey[400]!,
              width: 1.5,
            ),
          ),
          disabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            borderSide: BorderSide(
              color: Colors.grey[300]!,
              width: 1,
            ),
          ),
        ),
        cursorColor: Colors.black,
        cursorWidth: 2,
        cursorHeight: 20,
      ),
    );
  }

  Widget _buildLeadingIcon() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.all(12),
      child: Icon(
        widget.focusNode.hasFocus ? Icons.search : Icons.search_outlined,
        color: widget.focusNode.hasFocus ? Colors.black : Colors.black54,
        size: 22,
      ),
    );
  }

  Widget _buildSuffixIcon() {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Opacity(
            opacity: _opacityAnimation.value,
            child: _hasText
                ? IconButton(
                    icon: Container(
                      width: 24,
                      height: 24,
                      decoration: const BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                    onPressed: _onClearPressed,
                    splashRadius: 20,
                    tooltip: 'Effacer',
                  )
                : const SizedBox(width: 48), // Garde l'espace même quand invisible
          ),
        );
      },
    );
  }
}

/// Widget de barre de recherche avec suggestions intégrées
class SearchBarWithSuggestions extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final Function(String) onSubmitted;
  final VoidCallback onClear;
  final Widget? suggestionsWidget;
  final bool showSuggestions;
  final String? hintText;
  final double maxSuggestionsHeight;

  const SearchBarWithSuggestions({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.onSubmitted,
    required this.onClear,
    this.suggestionsWidget,
    required this.showSuggestions,
    this.hintText,
    this.maxSuggestionsHeight = 300.0,
  });

  @override
  State<SearchBarWithSuggestions> createState() => _SearchBarWithSuggestionsState();
}

class _SearchBarWithSuggestionsState extends State<SearchBarWithSuggestions>
    with SingleTickerProviderStateMixin {
  late AnimationController _suggestionsAnimationController;
  late Animation<double> _suggestionsAnimation;

  @override
  void initState() {
    super.initState();
    
    _suggestionsAnimationController = AnimationController(
      duration: const Duration(milliseconds: 250),
      vsync: this,
    );
    
    _suggestionsAnimation = CurvedAnimation(
      parent: _suggestionsAnimationController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void didUpdateWidget(SearchBarWithSuggestions oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    if (widget.showSuggestions != oldWidget.showSuggestions) {
      if (widget.showSuggestions) {
        _suggestionsAnimationController.forward();
      } else {
        _suggestionsAnimationController.reverse();
      }
    }
  }

  @override
  void dispose() {
    _suggestionsAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SearchBarWidget(
          controller: widget.controller,
          focusNode: widget.focusNode,
          onSubmitted: widget.onSubmitted,
          onClear: widget.onClear,
          hintText: widget.hintText,
        ),
        AnimatedBuilder(
          animation: _suggestionsAnimation,
          builder: (context, child) {
            return ClipRect(
              child: SizeTransition(
                sizeFactor: _suggestionsAnimation,
                axisAlignment: -1,
                child: Container(
                  constraints: BoxConstraints(
                    maxHeight: widget.maxSuggestionsHeight,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(14),
                      bottomRight: Radius.circular(14),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: widget.suggestionsWidget ?? const SizedBox.shrink(),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

/// Widget de barre de recherche compacte pour usage dans AppBar
class CompactSearchBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final Function(String) onSubmitted;
  final VoidCallback onClear;
  final String? hintText;
  final bool autofocus;

  const CompactSearchBar({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.onSubmitted,
    required this.onClear,
    this.hintText,
    this.autofocus = false,
  });

  @override
  Widget build(BuildContext context) {
    return SearchBarWidget(
      controller: controller,
      focusNode: focusNode,
      onSubmitted: onSubmitted,
      onClear: onClear,
      hintText: hintText ?? 'Rechercher...',
      backgroundColor: Colors.white.withOpacity(0.9),
      borderColor: Colors.transparent,
      borderRadius: 25.0,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leadingIcon: const Padding(
        padding: EdgeInsets.all(8),
        child: Icon(
          Icons.search,
          color: Colors.black54,
          size: 20,
        ),
      ),
    );
  }
}

/// Widget de barre de recherche avec bouton de filtre
class SearchBarWithFilter extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final Function(String) onSubmitted;
  final VoidCallback onClear;
  final VoidCallback onFilterTap;
  final String? hintText;
  final bool hasActiveFilters;

  const SearchBarWithFilter({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.onSubmitted,
    required this.onClear,
    required this.onFilterTap,
    this.hintText,
    this.hasActiveFilters = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: SearchBarWidget(
            controller: controller,
            focusNode: focusNode,
            onSubmitted: onSubmitted,
            onClear: onClear,
            hintText: hintText,
          ),
        ),
        const SizedBox(width: 12),
        Material(
          color: hasActiveFilters ? Colors.black : Colors.grey[100],
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            onTap: onFilterTap,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                Icons.tune,
                color: hasActiveFilters ? Colors.white : Colors.black54,
                size: 22,
              ),
            ),
          ),
        ),
      ],
    );
  }
}