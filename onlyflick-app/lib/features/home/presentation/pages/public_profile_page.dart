// lib/features/user/presentation/pages/public_profile_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/models/user_models.dart';
import '../../../../core/services/user_service.dart';
import '../../../../features/auth/auth_provider.dart';

/// Page pour afficher le profil public d'un utilisateur avec statistiques
/// Permet de s'abonner si c'est un créateur
class PublicProfilePage extends StatefulWidget {
  final int userId;
  final String? username;

  const PublicProfilePage({
    Key? key,
    required this.userId,
    this.username,
  }) : super(key: key);

  @override
  State<PublicProfilePage> createState() => _PublicProfilePageState();
}

class _PublicProfilePageState extends State<PublicProfilePage> {
  final UserService _userService = UserService();
  
  // État du profil
  PublicUserProfile? _profile;
  SubscriptionStatus? _subscriptionStatus;
  bool _isLoadingProfile = false;
  bool _isLoadingSubscription = false;
  bool _isSubscriptionAction = false;
  String? _profileError;
  
  // État des posts
  List<UserPost> _posts = [];
  bool _isLoadingPosts = false;
  bool _hasMorePosts = false;
  int _currentPage = 1;
  String? _postsError;

  @override
  void initState() {
    super.initState();
    _initializeProfile();
  }

  /// 🚀 INITIALISATION COMPLÈTE DU PROFIL
  Future<void> _initializeProfile() async {
    await _loadProfile();
    if (_profile != null) {
      if (_profile!.isCreator) {
        _loadSubscriptionStatus();
      }
      _loadUserPosts(refresh: true);
    }
  }

  /// 📋 CHARGE LE PROFIL PUBLIC
  Future<void> _loadProfile() async {
    setState(() {
      _isLoadingProfile = true;
      _profileError = null;
    });

    try {
      final result = await _userService.getUserProfile(widget.userId);
      
      if (result.isSuccess && result.data != null) {
        setState(() {
          _profile = result.data!;
          _isLoadingProfile = false;
        });
        debugPrint('✅ [PublicProfile] Profile loaded for user ${widget.userId}');
      } else {
        setState(() {
          _profileError = result.error?.message ?? 'Erreur lors du chargement du profil';
          _isLoadingProfile = false;
        });
        debugPrint('❌ [PublicProfile] Failed to load profile: ${result.error?.message}');
      }
    } catch (e) {
      setState(() {
        _profileError = 'Erreur de connexion';
        _isLoadingProfile = false;
      });
      debugPrint('❌ [PublicProfile] Exception loading profile: $e');
    }
  }

  /// 🎯 CHARGE LE STATUT D'ABONNEMENT
  Future<void> _loadSubscriptionStatus() async {
    if (!_profile!.isCreator) return;

    setState(() => _isLoadingSubscription = true);

    try {
      final result = await _userService.checkSubscriptionStatus(widget.userId);
      
      setState(() {
        _subscriptionStatus = result.isSuccess ? result.data : null;
        _isLoadingSubscription = false;
      });
    } catch (e) {
      setState(() => _isLoadingSubscription = false);
      debugPrint('❌ [PublicProfile] Failed to load subscription status: $e');
    }
  }

  /// 📚 CHARGE LES POSTS DE L'UTILISATEUR - VERSION CORRIGÉE
  Future<void> _loadUserPosts({bool refresh = false}) async {
    if (_isLoadingPosts) return;

    setState(() {
      _isLoadingPosts = true;
      if (refresh) {
        _posts.clear();
        _currentPage = 1;
        _postsError = null;
      }
    });

    try {
      debugPrint('🔍 [PublicProfile] Loading posts for user ${widget.userId} (page $_currentPage)');
      
      final result = await _userService.getUserPosts(
        widget.userId,
        page: _currentPage,
        limit: 50, // 🔧 LIMITE AUGMENTÉE pour récupérer plus de posts
      );

      if (result.isSuccess && result.data != null) {
        final response = result.data!;
        
        setState(() {
          if (refresh || _currentPage == 1) {
            _posts = List.from(response.posts);
          } else {
            _posts.addAll(response.posts);
          }
          
          _hasMorePosts = response.hasMore;
          if (response.posts.isNotEmpty) {
            _currentPage++;
          }
          _isLoadingPosts = false;
          _postsError = null;
        });

        debugPrint('✅ [PublicProfile] Loaded ${response.posts.length} posts (total: ${_posts.length})');
      } else {
        setState(() {
          _postsError = result.error?.message ?? 'Erreur lors du chargement des posts';
          _isLoadingPosts = false;
        });
        debugPrint('❌ [PublicProfile] Failed to load posts: ${result.error?.message}');
      }
    } catch (e) {
      setState(() {
        _postsError = 'Erreur de connexion';
        _isLoadingPosts = false;
      });
      debugPrint('❌ [PublicProfile] Exception loading posts: $e');
    }
  }

  /// 🔄 GÈRE L'ABONNEMENT/DÉSABONNEMENT
  Future<void> _toggleSubscription() async {
    if (_profile == null || !_profile!.isCreator || _isSubscriptionAction) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (!authProvider.isAuthenticated) {
      _showSnackBar('Vous devez être connecté pour vous abonner', isError: true);
      return;
    }

    setState(() => _isSubscriptionAction = true);

    try {
      UserServiceResult<String> result;
      
      if (_subscriptionStatus?.isActive == true) {
        result = await _userService.unsubscribeFromCreator(widget.userId);
      } else {
        result = await _userService.subscribeToCreator(widget.userId);
      }

      if (result.isSuccess) {
        _showSnackBar(result.data ?? 'Action réussie', isError: false);
        await _loadSubscriptionStatus();
      } else {
        _showSnackBar(result.error?.message ?? 'Erreur lors de l\'action', isError: true);
      }
    } catch (e) {
      _showSnackBar('Erreur inattendue: $e', isError: true);
    } finally {
      setState(() => _isSubscriptionAction = false);
    }
  }

  /// 💳 GÈRE L'ABONNEMENT AVEC PAIEMENT
  Future<void> _handlePaymentSubscription() async {
    if (_profile == null || !_profile!.isCreator || _isSubscriptionAction) return;

    setState(() => _isSubscriptionAction = true);

    try {
      final result = await _userService.subscribeWithPayment(widget.userId);
      
      if (result.isSuccess && result.data != null) {
        final clientSecret = result.data!['client_secret'];
        _showSnackBar('Paiement initié. Client Secret: $clientSecret', isError: false);
        await _loadSubscriptionStatus();
      } else {
        _showSnackBar(result.error?.message ?? 'Erreur lors du paiement', isError: true);
      }
    } catch (e) {
      _showSnackBar('Erreur lors du paiement: $e', isError: true);
    } finally {
      setState(() => _isSubscriptionAction = false);
    }
  }

  /// 📢 AFFICHE UNE SNACKBAR
  void _showSnackBar(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _buildAppBar(),
      body: _buildBody(),
    );
  }

  /// 🎨 APP BAR MODERNE
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios, color: Colors.black, size: 20),
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: Text(
        widget.username ?? 'Profil',
        style: GoogleFonts.inter(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: Colors.black,
        ),
      ),
      centerTitle: true,
      actions: [
        IconButton(
          icon: const Icon(Icons.more_vert, color: Colors.black),
          onPressed: () {
            // TODO: Menu contextuel (signaler, partager, etc.)
          },
        ),
      ],
    );
  }

  /// 🏗️ CORPS PRINCIPAL
  Widget _buildBody() {
    if (_isLoadingProfile) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.black),
            SizedBox(height: 16),
            Text('Chargement du profil...'),
          ],
        ),
      );
    }

    if (_profileError != null) {
      return _buildErrorState();
    }

    if (_profile == null) {
      return const Center(
        child: Text('Profil non trouvé'),
      );
    }

    return RefreshIndicator(
      color: Colors.black,
      onRefresh: _initializeProfile,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          children: [
            _buildProfileHeader(),
            const SizedBox(height: 24),
            _buildUserStats(),
            const SizedBox(height: 24),
            if (_profile!.bio?.isNotEmpty == true) ...[
              _buildBioSection(),
              const SizedBox(height: 24),
            ],
            if (_profile!.isCreator) ...[
              _buildSubscriptionSection(),
              const SizedBox(height: 24),
            ],
            _buildPublicationsSection(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  /// ❌ ÉTAT D'ERREUR
  Widget _buildErrorState() {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red[400]),
            const SizedBox(height: 16),
            Text(
              _profileError!,
              style: GoogleFonts.inter(
                fontSize: 16,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _initializeProfile,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Réessayer'),
            ),
          ],
        ),
      ),
    );
  }

  /// 👤 EN-TÊTE DU PROFIL
  Widget _buildProfileHeader() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          // Avatar avec bordure moderne
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: _profile!.isCreator 
                  ? LinearGradient(
                      colors: [Colors.purple, Colors.pink],
                    )
                  : null,
              color: _profile!.isCreator ? null : Colors.grey[300],
            ),
            padding: EdgeInsets.all(_profile!.isCreator ? 3 : 0),
            child: CircleAvatar(
              radius: 45,
              backgroundColor: Colors.grey[300],
              backgroundImage: _profile!.avatarUrl != null
                  ? NetworkImage(_profile!.avatarUrl!)
                  : null,
              child: _profile!.avatarUrl == null
                  ? Icon(Icons.person, size: 40, color: Colors.grey[600])
                  : null,
            ),
          ),
          const SizedBox(width: 20),
          
          // Informations utilisateur
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _profile!.displayName,
                  style: GoogleFonts.inter(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '@${_profile!.username}',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 12),
                
                // Badge du rôle moderne
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    gradient: _profile!.isCreator 
                        ? LinearGradient(
                            colors: [Colors.purple.withOpacity(0.1), Colors.pink.withOpacity(0.1)],
                          )
                        : null,
                    color: _profile!.isCreator ? null : Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _profile!.isCreator ? Colors.purple : Colors.blue,
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _profile!.isCreator ? '✨' : '👤',
                        style: const TextStyle(fontSize: 12),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _profile!.isCreator ? 'Créateur' : 'Abonné',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: _profile!.isCreator ? Colors.purple : Colors.blue,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 📊 STATISTIQUES UTILISATEUR
  Widget _buildUserStats() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(
            count: _profile!.postsCountFormatted,
            label: 'Posts',
            icon: Icons.grid_on,
            color: Colors.blue,
          ),
          _buildStatDivider(),
          _buildStatItem(
            count: _profile!.followersCountFormatted,
            label: _profile!.isCreator ? 'Abonnés' : 'Followers',
            icon: Icons.people,
            color: Colors.green,
          ),
          _buildStatDivider(),
          _buildStatItem(
            count: _profile!.followingCountFormatted,
            label: 'Abonnements',
            icon: Icons.person_add,
            color: Colors.orange,
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required String count,
    required String label,
    required IconData icon,
    required Color color,
  }) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(height: 8),
        Text(
          count,
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Colors.black,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildStatDivider() {
    return Container(
      height: 50,
      width: 1,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            Colors.grey[300]!,
            Colors.transparent,
          ],
        ),
      ),
    );
  }

  /// 📝 SECTION BIO
  Widget _buildBioSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, size: 18, color: Colors.grey[600]),
              const SizedBox(width: 8),
              Text(
                'À propos',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _profile!.bio ?? '',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: Colors.grey[700],
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  /// 💎 SECTION ABONNEMENT
  Widget _buildSubscriptionSection() {
    if (!_profile!.isCreator) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.purple.withOpacity(0.05), Colors.pink.withOpacity(0.05)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.purple.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.star, color: Colors.amber[600], size: 20),
              const SizedBox(width: 8),
              Text(
                'Abonnement Premium',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
              ),
            ],
          ),
          
          if (_profile!.subscriptionPriceFormatted.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              _profile!.subscriptionPriceFormatted,
              style: GoogleFonts.inter(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: Colors.purple,
              ),
            ),
          ],
          
          const SizedBox(height: 16),
          
          if (_isLoadingSubscription)
            const Center(child: CircularProgressIndicator(color: Colors.purple))
          else
            _buildSubscriptionButtons(),
        ],
      ),
    );
  }

  /// 🔘 BOUTONS D'ABONNEMENT
  Widget _buildSubscriptionButtons() {
    if (_subscriptionStatus?.isActive == true) {
      return Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green),
            ),
            child: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Vous êtes abonné',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.green[800],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: OutlinedButton(
              onPressed: _isSubscriptionAction ? null : _toggleSubscription,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.red, width: 2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isSubscriptionAction
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.red),
                      ),
                    )
                  : const Text('Se désabonner', style: TextStyle(fontSize: 16)),
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: _isSubscriptionAction ? null : _toggleSubscription,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purple,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            child: _isSubscriptionAction
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Text('S\'abonner', style: TextStyle(fontSize: 16)),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: OutlinedButton(
            onPressed: _isSubscriptionAction ? null : _handlePaymentSubscription,
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.purple,
              side: const BorderSide(color: Colors.purple, width: 2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: _isSubscriptionAction
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.purple),
                    ),
                  )
                : const Text('S\'abonner avec paiement', style: TextStyle(fontSize: 16)),
          ),
        ),
      ],
    );
  }

  /// 📱 SECTION PUBLICATIONS - VERSION CORRIGÉE
  Widget _buildPublicationsSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.grid_on, color: Colors.grey[600], size: 20),
              const SizedBox(width: 8),
              Text(
                'Publications',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_posts.length}',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: Colors.blue,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          
          if (_isLoadingPosts && _posts.isEmpty)
            _buildPostsLoading()
          else if (_postsError != null)
            _buildPostsError()
          else if (_posts.isEmpty)
            _buildNoPosts()
          else
            _buildPostsGrid(),
        ],
      ),
    );
  }

  /// ⏳ CHARGEMENT DES POSTS
  Widget _buildPostsLoading() {
    return Container(
      height: 250,
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.black),
            SizedBox(height: 16),
            Text('Chargement des publications...'),
          ],
        ),
      ),
    );
  }

  /// ❌ ERREUR DES POSTS
  Widget _buildPostsError() {
    return Container(
      height: 250,
      decoration: BoxDecoration(
        color: Colors.red[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red[200]!),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.red[400]),
            const SizedBox(height: 16),
            Text(
              _postsError!,
              style: GoogleFonts.inter(color: Colors.red[600], fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => _loadUserPosts(refresh: true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red[600],
                foregroundColor: Colors.white,
              ),
              child: const Text('Réessayer'),
            ),
          ],
        ),
      ),
    );
  }

  /// 📭 AUCUN POST
  Widget _buildNoPosts() {
    return Container(
      height: 250,
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.photo_library_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Aucune publication',
              style: GoogleFonts.inter(
                color: Colors.grey[500],
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Cet utilisateur n\'a pas encore publié de contenu',
              style: GoogleFonts.inter(color: Colors.grey[400], fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  /// 🎨 GRILLE DES POSTS - VERSION COMPLÈTEMENT CORRIGÉE
  Widget _buildPostsGrid() {
    return Column(
      children: [
        // 🔧 GRILLE AVEC HAUTEUR CALCULÉE DYNAMIQUEMENT
        LayoutBuilder(
          builder: (context, constraints) {
            const crossAxisCount = 3;
            const spacing = 8.0;
            final itemWidth = (constraints.maxWidth - (spacing * (crossAxisCount - 1))) / crossAxisCount;
            final rows = (_posts.length / crossAxisCount).ceil();
            final gridHeight = (rows * itemWidth) + ((rows - 1) * spacing);
            
            return SizedBox(
              height: gridHeight,
              child: GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: spacing,
                  mainAxisSpacing: spacing,
                  childAspectRatio: 1,
                ),
                itemCount: _posts.length,
                itemBuilder: (context, index) {
                  final post = _posts[index];
                  return _buildPostItem(post, index);
                },
              ),
            );
          },
        ),
        
        // Bouton charger plus
        if (_hasMorePosts) ...[
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: OutlinedButton(
              onPressed: _isLoadingPosts ? null : () => _loadUserPosts(),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.black,
                side: BorderSide(color: Colors.grey[400]!),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isLoadingPosts
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      'Charger plus de publications',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w500),
                    ),
            ),
          ),
        ],
      ],
    );
  }

  /// 🎯 ITEM DE POST MODERNE
  Widget _buildPostItem(UserPost post, int index) {
    return GestureDetector(
      onTap: () {
        debugPrint('🎯 Post tapped: ${post.id}');
        // TODO: Naviguer vers la page de détail du post
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Image ou placeholder
              if (post.imageUrl?.isNotEmpty == true)
                Image.network(
                  post.imageUrl!,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                      color: Colors.grey[200],
                      child: Center(
                        child: CircularProgressIndicator(
                          color: Colors.grey[400],
                          strokeWidth: 2,
                        ),
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return _buildPostPlaceholder(post, index);
                  },
                )
              else
                _buildPostPlaceholder(post, index),
              
              // Overlay moderne avec gradient
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.8),
                      ],
                    ),
                  ),
                  child: Row(
                    children: [
                      // Badge VIP
                      if (post.isSubscriberOnly)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Colors.orange, Colors.red],
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.lock, size: 10, color: Colors.white),
                              const SizedBox(width: 2),
                              Text(
                                'VIP',
                                style: TextStyle(
                                  fontSize: 8,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      
                      const Spacer(),
                      
                      // Likes
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              post.isLiked ? Icons.favorite : Icons.favorite_border,
                              color: post.isLiked ? Colors.red : Colors.white,
                              size: 12,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${post.likesCount}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
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
      ),
    );
  }

  /// 🎨 PLACEHOLDER AVEC COULEURS DYNAMIQUES
  Widget _buildPostPlaceholder(UserPost post, int index) {
    final gradients = [
      [const Color(0xFF667eea), const Color(0xFF764ba2)], // bleu-violet
      [const Color(0xFFf093fb), const Color(0xFFf5576c)], // rose-rouge
      [const Color(0xFF4facfe), const Color(0xFF00f2fe)], // bleu-cyan
      [const Color(0xFF43e97b), const Color(0xFF38f9d7)], // vert-turquoise
      [const Color(0xFFfa709a), const Color(0xFFfee140)], // rose-jaune
      [const Color(0xFFa8edea), const Color(0xFFfed6e3)], // turquoise-rose
      [const Color(0xFFffecd2), const Color(0xFFfcb69f)], // pêche-orange
    ];
    
    final gradient = gradients[index % gradients.length];
    
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradient,
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.image_outlined,
              color: Colors.white.withOpacity(0.9),
              size: 28,
            ),
            const SizedBox(height: 4),
            if ((post.content?.isNotEmpty ?? false))
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Text(
                  (post.content?.length ?? 0) > 25 
                      ? '${post.content!.substring(0, 25)}...'
                      : post.content ?? '',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 9,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
        ),
      ),
    );
  }
}