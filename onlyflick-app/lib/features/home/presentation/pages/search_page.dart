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

class _SearchPageState extends State<SearchPage> 
    with TickerProviderStateMixin, WidgetsBindingObserver {
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

  // ✅ Variables pour le rafraîchissement
  bool _needsRefresh = false;
  String _currentKey = 'initial'; // Clé unique pour forcer le rebuild

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchTextChanged);
    _setupScrollListener();
    _loadAvailableTags(); // Charger les tags depuis l'API
    
    // ✅ Écouter les changements d'état de l'app
    WidgetsBinding.instance.addObserver(this);
    
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

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _searchController.removeListener(_onSearchTextChanged);
    _searchController.dispose();
    _searchFocusNode.dispose();
    _scrollController.dispose();
    _backgroundAnimationController.dispose();
    super.dispose();
  }

  // ✅ Détection quand l'app revient au premier plan
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    if (state == AppLifecycleState.resumed && _needsRefresh) {
      debugPrint('🔄 App resumed - Rafraîchissement automatique des données');
      _refreshAllData();
      _needsRefresh = false;
    }
  }

  // ✅ Rafraîchissement complet des données
  Future<void> _refreshAllData() async {
    debugPrint('🔄 Rafraîchissement complet des données...');
    
    try {
      // 1. Recharger les tags
      await _loadAvailableTags();
      
      // 2. Forcer le rafraîchissement des posts en changeant la clé
      setState(() {
        _currentKey = 'refresh_${DateTime.now().millisecondsSinceEpoch}';
      });
      
      debugPrint('✅ Rafraîchissement terminé avec nouvelle clé: $_currentKey');
      
    } catch (e) {
      debugPrint('❌ Erreur lors du rafraîchissement: $e');
    }
  }

  // ✅ Pull-to-refresh handler
  Future<void> _onRefresh() async {
    debugPrint('🔄 Pull-to-refresh déclenché');
    await _refreshAllData();
  }

  // Charge les tags disponibles depuis l'API
  Future<void> _loadAvailableTags() async {
    try {
      setState(() {
        _isLoadingTags = true;
        _hasTagsError = false;
      });

      // ✅ Utiliser la nouvelle méthode avec rafraîchissement forcé
      final tags = await TagsService.refreshTags();
      
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
          // ✅ Utiliser les bons tags par défaut en cas d'erreur
          _tags = [
            'Tous',
            'Art',
            'Musique',
            'Tech',
            'Cuisine',
            'Wellness',
            'Beauté',
            'Mode',
            'Football',
            'Basketball',
            'Cinéma',
            'Actualités',
            'Mangas',
            'Memes',
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

  // ✅ Gestion du changement de tag avec rafraîchissement
  void _onTagSelected(String tag) async {
    if (_selectedTag != tag) {
      setState(() {
        _selectedTag = tag;
        // Changer la clé pour forcer le refresh du RecommendedPostsSection
        _currentKey = 'tag_${tag}_${DateTime.now().millisecondsSinceEpoch}';
      });

      debugPrint('🏷️ Tag sélectionné: $tag (nouvelle clé: $_currentKey)');

      // Le widget RecommendedPostsSection se rechargera automatiquement
      // grâce à la nouvelle clé unique
    }
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
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _buildAppBar(), // ✅ AppBar avec bouton refresh
      body: RefreshIndicator(
        onRefresh: _onRefresh, // ✅ Pull-to-refresh
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
                    child: CustomScrollView(
                      controller: _scrollController,
                      slivers: [
                        // Contenu principal
                        SliverToBoxAdapter(
                          child: Column(
                            children: [
                              // ✅ BARRE DE RECHERCHE
                              _buildSearchSection(),
                              
                              // ✅ ESPACEMENT entre recherche et tags
                              const SizedBox(height: 24),
                              
                              // ✅ TAGS avec espacement amélioré
                              _buildTagsSection(),
                              
                              // ✅ ESPACEMENT entre tags et contenu
                              const SizedBox(height: 32),
                              
                              // ✅ CONTENU PRINCIPAL avec clé unique
                              _buildContent(),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            
            // Overlay des suggestions
            if (_showSuggestions) ...[
              Positioned(
                top: 0,
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

  // ✅ AppBar avec bouton de rafraîchissement
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      automaticallyImplyLeading: false,
      title: Text(
        'Recherche',
        style: GoogleFonts.inter(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: Colors.black87,
        ),
      ),
      actions: [
        IconButton(
          icon: Icon(
            Icons.refresh_rounded,
            color: Colors.grey[600],
            size: 24,
          ),
          onPressed: () {
            debugPrint('🔄 Rafraîchissement manuel déclenché');
            _refreshAllData();
          },
          tooltip: 'Actualiser',
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildSearchSection() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
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
              Icons.search_rounded, 
              color: Colors.grey[600],
              size: 22,
            ),
          ),
          suffixIcon: _searchController.text.isNotEmpty
              ? Container(
                  padding: const EdgeInsets.all(4),
                  child: IconButton(
                    icon: Icon(
                      Icons.clear_rounded, 
                      color: Colors.grey[600],
                      size: 20,
                    ),
                    onPressed: _clearSearch,
                  ),
                )
              : null,
          filled: true,
          fillColor: Colors.grey[50],
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
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
        height: 50,
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
            height: 50,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _tags.length,
              itemBuilder: (context, index) {
                final tag = _tags[index];
                final isSelected = tag == _selectedTag;
                
                return Container(
                  margin: EdgeInsets.only(
                    right: index == _tags.length - 1 ? 0 : 12,
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
                    selectedColor: Colors.black87,
                    checkmarkColor: Colors.white,
                    elevation: 0,
                    pressElevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(
                        color: isSelected ? Colors.black87 : Colors.grey[200]!,
                        width: 1,
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                );
              },
            ),
          ),
        
        // Message d'erreur pour les tags
        if (_hasTagsError)
          Container(
            padding: const EdgeInsets.all(12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.warning_rounded, size: 16, color: Colors.orange[600]),
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

  // ✅ Contenu principal avec clé unique pour forcer le rebuild
  Widget _buildContent() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: RecommendedPostsSection(
        key: ValueKey(_currentKey), // ✅ Clé unique qui change lors du refresh
        selectedTag: _selectedTag,
      ),
    );
  }

  // Navigation réelle vers le profil public avec abonnement
  void _navigateToUserProfile(UserSearchResult user, SearchProvider provider) {
    // Enregistrer l'interaction de vue de profil
    provider.trackProfileView(user);
    
    debugPrint('🔗 Navigation vers le profil de ${user.username} (ID: ${user.id})');
    
    // Navigation vers le profil public avec système d'abonnement
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

// ✅ Widget pour les suggestions vides (amélioré)
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
            margin: const EdgeInsets.all(24),
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
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
                    Icons.search_off_rounded,
                    size: 48,
                    color: Colors.grey[400],
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Aucun résultat pour "$query"',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  'Essayez avec un autre terme de recherche',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w400,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                TextButton(
                  onPressed: onDismiss,
                  child: Text(
                    'Fermer',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: Colors.blue[600],
                      fontWeight: FontWeight.w500,
                    ),
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