// lib/features/home/presentation/pages/search_page.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/models/search_models.dart';
import '../../../../core/providers/search_provider.dart';
import '../../../../core/services/tags_service.dart';
import '../pages/public_profile_page.dart';
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
                        // ✅ BARRE DE RECHERCHE avec espacement amélioré
                        _buildSearchSection(),
                        
                        // ✅ ESPACEMENT entre recherche et tags
                        const SizedBox(height: 32),
                        
                        // ✅ TAGS avec espacement amélioré
                        _buildTagsSection(),
                        
                        // ✅ ESPACEMENT entre tags et contenu
                        const SizedBox(height: 40),
                        
                        // ✅ CONTENU PRINCIPAL
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
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0), // ✅ Plus d'espace en haut
      child: TextField(
        controller: _searchController,
        focusNode: _searchFocusNode,
        onSubmitted: _onSearchSubmitted,
        style: GoogleFonts.inter(
          fontSize: 16,
          color: Colors.black,
          fontWeight: FontWeight.w400,
        ),
        decoration: InputDecoration(
          hintText: 'Nom, prénom ou @username...',
          hintStyle: GoogleFonts.inter(
            color: Colors.grey[500],
            fontSize: 16,
            fontWeight: FontWeight.w400,
          ),
          prefixIcon: Container(
            padding: const EdgeInsets.all(12),
            child: Icon(
              Icons.search, 
              color: Colors.grey[600],
              size: 24,
            ),
          ),
          suffixIcon: _searchController.text.isNotEmpty
              ? Container(
                  padding: const EdgeInsets.all(4),
                  child: IconButton(
                    icon: Icon(
                      Icons.clear, 
                      color: Colors.grey[600],
                      size: 20,
                    ),
                    onPressed: _clearSearch,
                  ),
                )
              : null,
          filled: true,
          fillColor: Colors.grey[50], // ✅ Couleur plus douce
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18), // ✅ Plus de padding
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16), // ✅ Plus arrondi
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(
              color: Colors.grey[300]!,
              width: 1.5,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTagsSection() {
    // Section des tags avec gestion du chargement
    if (_isLoadingTags && _tags.length == 1) {
      return Container(
        height: 50, // ✅ Hauteur fixe pour consistance
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
          Container(
            height: 50, // ✅ Hauteur fixe pour les tags
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _tags.length,
              itemBuilder: (context, index) {
                final tag = _tags[index];
                final isSelected = tag == _selectedTag;
                
                return Container(
                  margin: EdgeInsets.only(
                    right: index == _tags.length - 1 ? 0 : 12, // ✅ Espacement entre tags
                  ),
                  child: FilterChip(
                    label: Text(
                      tag,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: isSelected ? Colors.white : Colors.grey[700],
                      ),
                    ),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (selected) {
                        _onTagSelected(tag);
                      }
                    },
                    backgroundColor: Colors.grey[100],
                    selectedColor: Colors.black,
                    checkmarkColor: Colors.white,
                    elevation: 0,
                    pressElevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20), // ✅ Plus arrondi
                      side: BorderSide(
                        color: isSelected ? Colors.black : Colors.grey[200]!,
                        width: 1,
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), // ✅ Plus de padding
                  ),
                );
              },
            ),
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16), // ✅ Padding horizontal consistant
      child: SingleChildScrollView(
        controller: _scrollController,
        child: RecommendedPostsSection(
          selectedTag: _selectedTag,
        ),
      ),
    );
  }

  // 🔥 NOUVELLE MÉTHODE : Navigation réelle vers le profil public avec abonnement
  void _navigateToUserProfile(UserSearchResult user, SearchProvider provider) {
    // Enregistrer l'interaction de vue de profil
    provider.trackProfileView(user);
    
    debugPrint('🔗 Navigation vers le profil de ${user.username} (ID: ${user.id})');
    
    // 🎯 NAVIGATION VERS LE PROFIL PUBLIC AVEC SYSTÈME D'ABONNEMENT
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => PublicProfilePage(
          userId: user.id,
          username: user.username,
        ),
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
            margin: const EdgeInsets.all(24), // ✅ Plus de marge
            padding: const EdgeInsets.all(32), // ✅ Plus de padding
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20), // ✅ Plus arrondi
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.search_off,
                    size: 48,
                    color: Colors.grey[400],
                  ),
                ),
                const SizedBox(height: 24), // ✅ Plus d'espace
                Text(
                  'Aucun résultat pour "$query"',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12), // ✅ Plus d'espace
                Text(
                  'Essayez avec un autre terme de recherche',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w400,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}