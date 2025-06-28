// lib/features/search/presentation/pages/search_page.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/models/search_models.dart';
import '../../../../core/providers/search_provider.dart';
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

  // Variables pour les tags
  String _selectedTag = 'Tous';
  final List<String> _tags = [
    'Tous',
    'Photography',
    'Art', 
    'Music',
    'Fitness',
    'Travel',
    'Food',
    'Fashion',
    'Design',
    'Tech'
  ];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchTextChanged);
    _setupScrollListener();
    
    // Animation pour l'arrière-plan
    _backgroundAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _backgroundAnimation = Tween<double>(
      begin: 1.0,
      end: 0.6, // Plus visible que 0.3
    ).animate(CurvedAnimation(
      parent: _backgroundAnimationController,
      curve: Curves.easeInOut,
    ));
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
          _showSuggestions = true; // Toujours afficher la dropdown, même si vide
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
  final selectedTagParam = tag.toLowerCase() == 'tous' ? null : tag.toLowerCase();

  await provider.searchPosts(
    tags: selectedTagParam != null ? [selectedTagParam] : [],
  );
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
    
    // Ne pas refaire une recherche, les suggestions ont déjà été chargées
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
                        TagsFilterWidget(
                          tags: _tags,
                          selectedTag: _selectedTag,
                          onTagSelected: _onTagSelected,
                        ),
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
                top: 80, // Légèrement plus bas pour éviter le chevauchement
                left: 0,
                right: 0,
                bottom: 0,
                child: _suggestions.isNotEmpty
                    ? SearchSuggestionsWidget(
                        suggestions: _suggestions,
                        onUserTap: _onUserTap,
                        onDismiss: _hideSuggestions,
                        maxHeight: MediaQuery.of(context).size.height * 0.5, // Un peu moins haut
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

  // Contenu principal : toujours afficher les posts recommandés
  Widget _buildContent() {
    return const SingleChildScrollView(
      child: RecommendedPostsSection(),
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