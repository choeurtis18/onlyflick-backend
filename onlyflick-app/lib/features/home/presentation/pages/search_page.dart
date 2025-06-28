// lib/features/home/presentation/pages/search_page.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/models/search_models.dart';
import '../../../../core/providers/search_provider.dart';
import '../../../../core/services/tags_service.dart';
import '../widgets/recommended_posts_section.dart';
import '../widgets/tags_filter_widget.dart';
import '../widgets/search_suggestions_widget.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> with TickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  
  // Variables pour gérer l'état des suggestions
  bool _showSuggestions = false;
  List<UserSearchResult> _suggestions = [];
  late AnimationController _backgroundAnimationController;
  late Animation<double> _backgroundAnimation;

  // Variables pour les tags - maintenant chargés dynamiquement
  String _selectedTag = 'Tous';
  List<String> _tags = ['Tous']; // Commencer avec "Tous" par défaut
  bool _isLoadingTags = true;
  bool _hasTagsError = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchTextChanged);
    _setupScrollListener();
    _loadAvailableTags(); // Charger les tags depuis l'API
    
    // Animation pour l'arrière-plan
    _backgroundAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _backgroundAnimation = Tween<double>(
      begin: 1.0,
      end: 0.6,
    ).animate(CurvedAnimation(
      parent: _backgroundAnimationController,
      curve: Curves.easeInOut,
    ));
  }

  // Charge les tags disponibles depuis l'API
  Future<void> _loadAvailableTags() async {
    try {
      setState(() {
        _isLoadingTags = true;
        _hasTagsError = false;
      });

      final tags = await TagsService.getAvailableTags();
      
      if (mounted) {
        setState(() {
          _tags = tags;
          _isLoadingTags = false;
          _hasTagsError = false;
        });
        
        debugPrint('✅ Tags chargés: $_tags');
      }
    } catch (e) {
      debugPrint('❌ Erreur chargement tags: $e');
      
      if (mounted) {
        setState(() {
          _isLoadingTags = false;
          _hasTagsError = true;
          // Garder les tags par défaut en cas d'erreur
          _tags = [
            'Tous',
            'Art',
            'Fitness',
            'Cuisine',
            'Mode',
            'Musique'
          ];
        });
      }
    }
  }

  void _setupScrollListener() {
    _scrollController.addListener(() {
      if (_searchController.text.isNotEmpty && 
          _scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 200) {
        final searchProvider = context.read<SearchProvider>();
        if (!searchProvider.isLoadingMoreSearch) {
          searchProvider.loadMoreUserSearchResults();
        }
      }
    });
  }

  void _onSearchTextChanged() {
    final query = _searchController.text.trim();
    final provider = context.read<SearchProvider>();

    if (query.length >= 2) {
      // Rechercher et afficher les suggestions en dropdown
      provider.searchUsers(query).then((_) {
        setState(() {
          _suggestions = provider.searchResult.users;
          _showSuggestions = true;
        });
        _backgroundAnimationController.forward();
      });
    } else {
      // Masquer les suggestions et nettoyer
      _hideSuggestions();
      provider.clearUserSearch();
    }
  }

  void _onTagSelected(String tag) async {
    setState(() {
      _selectedTag = tag;
    });

    final provider = context.read<SearchProvider>();
    
    // Convertir le nom d'affichage en clé backend
    final tagKey = TagsService.getTagKey(tag);
    
    // Utiliser la clé backend pour la recherche
    await provider.searchPosts(
      tags: tagKey == 'tous' ? [] : [tagKey],
    );

    debugPrint('Tag sélectionné: $tag -> clé backend: $tagKey');
  }

  void _hideSuggestions() {
    if (_showSuggestions) {
      _backgroundAnimationController.reverse().then((_) {
        setState(() {
          _showSuggestions = false;
          _suggestions = [];
        });
      });
    }
  }

  void _onUserTap(UserSearchResult user) {
    _searchController.text = '${user.firstName} ${user.lastName}';
    _hideSuggestions();
    _searchFocusNode.unfocus();
    
    final provider = context.read<SearchProvider>();
    _navigateToUserProfile(user, provider);
  }

  void _onSearchSubmitted(String query) {
    if (query.trim().isEmpty) return;
    
    _searchFocusNode.unfocus();
    _hideSuggestions();
  }

  void _clearSearch() {
    _searchController.clear();
    _searchFocusNode.unfocus();
    _hideSuggestions();
    final provider = context.read<SearchProvider>();
    provider.clearUserSearch();
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchTextChanged);
    _searchController.dispose();
    _searchFocusNode.dispose();
    _scrollController.dispose();
    _backgroundAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Stack(
          children: [
            // Contenu principal avec animation d'opacité
            AnimatedBuilder(
              animation: _backgroundAnimation,
              builder: (context, child) {
                return Opacity(
                  opacity: _backgroundAnimation.value,
                  child: AbsorbPointer(
                    absorbing: _showSuggestions,
                    child: Column(
                      children: [
                        _buildSearchSection(),
                        _buildTagsSection(),
                        Expanded(child: _buildContent()),
                      ],
                    ),
                  ),
                );
              },
            ),
            
            // Overlay des suggestions
            if (_showSuggestions) ...[
              Positioned(
                top: 80,
                left: 0,
                right: 0,
                bottom: 0,
                child: _suggestions.isNotEmpty
                    ? SearchSuggestionsWidget(
                        suggestions: _suggestions,
                        onUserTap: _onUserTap,
                        onDismiss: _hideSuggestions,
                        maxHeight: MediaQuery.of(context).size.height * 0.5,
                      )
                    : NoResultsSuggestionWidget(
                        query: _searchController.text,
                        onDismiss: _hideSuggestions,
                      ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSearchSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: TextField(
        controller: _searchController,
        focusNode: _searchFocusNode,
        onSubmitted: _onSearchSubmitted,
        style: const TextStyle(
          fontSize: 16,
          color: Colors.black,
        ),
        decoration: InputDecoration(
          hintText: 'Nom, prénom ou @username...',
          hintStyle: TextStyle(color: Colors.grey[500]),
          prefixIcon: const Icon(Icons.search, color: Colors.black54),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, color: Colors.black54),
                  onPressed: _clearSearch,
                )
              : null,
          filled: true,
          fillColor: Colors.grey[100],
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: Colors.grey[400]!),
          ),
        ),
      ),
    );
  }

  Widget _buildTagsSection() {
    // Section des tags avec gestion du chargement
    if (_isLoadingTags && _tags.length == 1) {
      return Container(
        height: 60,
        child: const Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.grey),
            ),
          ),
        ),
      );
    }

    return Column(
      children: [
        // Afficher les tags même pendant le chargement si on a plus que "Tous"
        if (_tags.length > 1)
          TagsFilterWidget(
            tags: _tags,
            selectedTag: _selectedTag,
            onTagSelected: _onTagSelected,
          ),
        
        // Message d'erreur pour les tags
        if (_hasTagsError)
          Container(
            padding: const EdgeInsets.all(8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.warning, size: 16, color: Colors.orange[600]),
                const SizedBox(width: 8),
                Text(
                  'Erreur de chargement des catégories',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.orange[600],
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _loadAvailableTags,
                  child: Text(
                    'Réessayer',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Colors.blue[600],
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  // Contenu principal : afficher les posts recommandés avec le tag sélectionné
  Widget _buildContent() {
    return SingleChildScrollView(
      child: RecommendedPostsSection(
        selectedTag: _selectedTag,
      ),
    );
  }

  void _navigateToUserProfile(UserSearchResult user, SearchProvider provider) {
    // Enregistrer l'interaction de vue de profil
    provider.trackProfileView(user);
    
    // TODO: Implémenter la navigation vers le profil utilisateur
    debugPrint('Navigation vers le profil de ${user.username}');
    
    // Placeholder pour la navigation
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Profil de ${user.firstName} ${user.lastName}',
          style: GoogleFonts.inter(fontWeight: FontWeight.w500),
        ),
        backgroundColor: Colors.black,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

// Widget pour les suggestions vides (si vous ne l'avez pas déjà)
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
        color: Colors.black54,
        child: Center(
          child: Container(
            margin: const EdgeInsets.all(20),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.search_off, size: 48, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  'Aucun résultat pour "$query"',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Essayez avec un autre terme de recherche',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}