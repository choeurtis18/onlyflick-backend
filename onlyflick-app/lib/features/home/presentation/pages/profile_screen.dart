// lib/features/home/presentation/pages/profile_screen.dart
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import '../../../auth/auth_provider.dart';
import '../../../../core/providers/profile_provider.dart';
import '../pages/post_detail_page.dart';
import '../widgets/subscription_stats_widget.dart';
import '../../../../core/utils/constants.dart';
import '../../../../core/utils/auth_storage.dart';

class ProfileScreen extends StatefulWidget {
  final bool isCreator;

  const ProfileScreen({super.key, this.isCreator = false});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    
    // Initialiser le TabController
    final user = context.read<AuthProvider>().user;
    final userIsCreator = user?.isCreator ?? false;
    _tabController = TabController(length: userIsCreator ? 2 : 1, vsync: this);
    
    // S'assurer que les données sont initialisées (y compris les stats d'abonnements)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final profileProvider = context.read<ProfileProvider>();
      profileProvider.ensureInitialized();
      debugPrint('🔄 [ProfileScreen] Initialization requested');
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<AuthProvider, ProfileProvider>(
      builder: (context, authProvider, profileProvider, child) {
        final user = authProvider.user;
        final userIsCreator = user?.isCreator ?? false;
        
        return DefaultTabController(
          length: userIsCreator ? 2 : 1,
          child: Scaffold(
            backgroundColor: Colors.white,
            body: SafeArea(
              child: RefreshIndicator(
                onRefresh: () => profileProvider.refreshAllData(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildHeader(),
                    _buildAvatarAndStats(user, profileProvider),
                    _buildBioSection(user, userIsCreator, profileProvider),
                    _buildButtons(userIsCreator, context, profileProvider),
                    
                    // Widget BecomeCreator pour les non-créateurs
                    if (!userIsCreator) 
                      BecomeCreatorWidget(
                        onRequestUpgrade: () => _handleCreatorUpgrade(profileProvider),
                      ),
                    
                    if (userIsCreator) const _ProfileTabs(),
                    const SizedBox(height: 8),
                    Expanded(
                      child: TabBarView(
                        children: [
                          _buildGrid(type: 'normal', profileProvider: profileProvider),
                          if (userIsCreator) _buildGrid(type: 'shop', profileProvider: profileProvider),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'OnlyFlick',
            style: GoogleFonts.pacifico(fontSize: 24, color: Colors.black),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined, size: 28, color: Colors.black),
            onPressed: _showSettingsMenu,
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarAndStats(dynamic user, ProfileProvider profileProvider) {
    final userIsCreator = user?.isCreator ?? false;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          // Avatar avec possibilité de modification
          _buildAvatar(user, profileProvider),
          const SizedBox(width: 16),
          Expanded(
            child: SubscriptionStatsWidget(
              // Utiliser les données du provider avec stats d'abonnements intégrées
              postsCount: profileProvider.postsCount,
              followersCount: profileProvider.followersCount,
              followingCount: profileProvider.followingCount,
              totalEarnings: profileProvider.totalEarnings,
              userId: user?.id ?? 0,
              isCreator: userIsCreator,
              isCurrentUser: true, // C'est le profil de l'utilisateur connecté
              isLoadingStats: profileProvider.isLoadingStats,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar(dynamic user, ProfileProvider profileProvider) {
    return Stack(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.grey[300]!, width: 2),
          ),
          child: CircleAvatar(
            radius: 38,
            backgroundColor: Colors.grey[300],
            backgroundImage: user?.avatarUrl?.isNotEmpty == true
                ? NetworkImage(user!.avatarUrl)
                : null,
            child: user?.avatarUrl?.isEmpty != false
                ? Text(
                    user?.initials ?? '?',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  )
                : null,
          ),
        ),
        
        // Bouton d'édition
        Positioned(
          bottom: 0,
          right: 0,
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.black,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(Icons.camera_alt, color: Colors.white, size: 16),
              onPressed: profileProvider.isUploadingAvatar 
                  ? null 
                  : () => _changeAvatar(profileProvider),
              constraints: const BoxConstraints(
                minWidth: 32,
                minHeight: 32,
              ),
            ),
          ),
        ),
        
        // Indicateur de chargement pour l'upload
        if (profileProvider.isUploadingAvatar)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black.withOpacity(0.5),
              ),
              child: const Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildBioSection(dynamic user, bool userIsCreator, ProfileProvider profileProvider) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ===== NOM D'AFFICHAGE PUBLIC : @USERNAME =====
          Text(
            user?.displayName ?? 'Utilisateur',  // displayName retourne @username ou fullName
            style: const TextStyle(
              fontWeight: FontWeight.bold, 
              fontSize: 18,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 4),
          
          // ===== NOM COMPLET (PRIVÉ) - Plus petit et discret =====
          if (user?.fullName?.isNotEmpty == true) ...[
            Text(
              user!.fullName,  // Prénom Nom (données privées)
              style: TextStyle(
                fontSize: 14, 
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
          ],
          
          // Bio avec possibilité de modification
          GestureDetector(
            onTap: () => _editBio(user?.bio ?? '', profileProvider),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.transparent),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                user?.bio?.isNotEmpty == true 
                    ? user!.bio 
                    : 'Ajoutez une bio... (tapez ici)',
                style: TextStyle(
                  fontSize: 14,
                  color: user?.bio?.isNotEmpty == true ? Colors.black : Colors.grey[500],
                  fontStyle: user?.bio?.isNotEmpty == true ? FontStyle.normal : FontStyle.italic,
                ),
              ),
            ),
          ),
          
          const SizedBox(height: 8),
          
          // Badge du rôle
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: userIsCreator ? Colors.purple.withOpacity(0.1) : Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: userIsCreator ? Colors.purple : Colors.blue,
                width: 1,
              ),
            ),
            child: Text(
              userIsCreator ? '✨ Créateur' : '👤 Abonné',
              style: TextStyle(
                fontSize: 12,
                color: userIsCreator ? Colors.purple : Colors.blue,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          
          if (userIsCreator) ...[
            const SizedBox(height: 8),
            const Text(
              'Abonnement : 4,99€ / mois',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildButtons(bool userIsCreator, BuildContext context, ProfileProvider profileProvider) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          SizedBox(
            height: 44,
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: profileProvider.isUpdatingBio 
                  ? null 
                  : () => _editProfile(context, profileProvider),
              child: profileProvider.isUpdatingBio
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text(
                      'Modifier le profil',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                    ),
            ),
          ),
          
          if (userIsCreator) ...[
            const SizedBox(height: 8),
            SizedBox(
              height: 36,
              width: double.infinity,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.black),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () => _showCreatorStats(profileProvider),
                child: const Text(
                  'Voir les statistiques',
                  style: TextStyle(color: Colors.black, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // 🔥 GRILLE AMÉLIORÉE : Meilleure gestion des états avec le flag isInitialized
  Widget _buildGrid({required String type, required ProfileProvider profileProvider}) {
    // 🔥 État de chargement
    if (profileProvider.isLoadingPosts) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Chargement des posts...'),
          ],
        ),
      );
    }

    // 🔥 Gestion d'erreur avec bouton de retry
    if (profileProvider.error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error, size: 64, color: Colors.red[400]),
            const SizedBox(height: 16),
            Text('Erreur: ${profileProvider.error}'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                debugPrint('🔄 [ProfileScreen] Retry button pressed');
                profileProvider.loadUserPosts(refresh: true);
              },
              child: const Text('Réessayer'),
            ),
          ],
        ),
      );
    }

    // Filtrer les posts selon le type d'onglet
    List<dynamic> filteredPosts = profileProvider.userPosts;
    if (type == 'shop') {
      filteredPosts = profileProvider.userPosts
          .where((post) => post.visibility == 'subscriber')
          .toList();
    }

    // 🔥 État vide avec vérification d'initialisation
    if (filteredPosts.isEmpty) {
      // 🔥 NOUVEAU : Vérifier si on est encore en train d'initialiser
      if (!profileProvider.isInitialized) {
        return const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Initialisation...'),
            ],
          ),
        );
      }
      
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              type == 'shop' ? Icons.shopping_bag_outlined : Icons.grid_on_rounded,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              type == 'shop' 
                  ? 'Aucun contenu premium'
                  : 'Aucun post encore',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              type == 'shop'
                  ? 'Créez du contenu exclusif pour vos abonnés'
                  : 'Commencez à partager vos moments',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                debugPrint('🔄 [ProfileScreen] Refresh button pressed');
                profileProvider.loadUserPosts(refresh: true);
              },
              child: const Text('🔄 Actualiser'),
            ),
          ],
        ),
      );
    }

    // Grille des posts
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: filteredPosts.length,
      itemBuilder: (context, index) {
        final post = filteredPosts[index];
        
        return GestureDetector(
          onTap: () => _onPostTap(post),
          child: _buildPostThumbnail(post),
        );
      },
    );
  }

  Widget _buildPostThumbnail(dynamic post) {
    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: Colors.grey[300],
          ),
          child: post.imageUrl.isNotEmpty
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    post.imageUrl,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: Colors.grey[300],
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.error, color: Colors.red, size: 24),
                            SizedBox(height: 4),
                            Text('Erreur', style: TextStyle(fontSize: 8)),
                          ],
                        ),
                      );
                    },
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Container(
                        color: Colors.grey[300],
                        child: Center(
                          child: CircularProgressIndicator(
                            value: loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded / 
                                  loadingProgress.expectedTotalBytes!
                                : null,
                            strokeWidth: 2,
                          ),
                        ),
                      );
                    },
                  ),
                )
              : Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: Colors.grey[300],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.image, color: Colors.grey, size: 32),
                      const SizedBox(height: 4),
                      Padding(
                        padding: const EdgeInsets.all(4.0),
                        child: Text(
                          post.content.length > 20 
                              ? '${post.content.substring(0, 20)}...'
                              : post.content,
                          style: const TextStyle(fontSize: 10),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
        ),
        
        // Indicateur de visibilité
        Positioned(
          top: 4,
          right: 4,
          child: _buildVisibilityIndicator(post.visibility),
        ),
        
        // Overlay avec stats du post
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(8),
                bottomRight: Radius.circular(8),
              ),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withOpacity(0.7),
                ],
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.favorite, color: Colors.white, size: 12),
                const SizedBox(width: 2),
                Text(
                  '${post.likesCount}',
                  style: const TextStyle(color: Colors.white, fontSize: 10),
                ),
                const Spacer(),
                const Icon(Icons.comment, color: Colors.white, size: 12),
                const SizedBox(width: 2),
                Text(
                  '${post.commentsCount}',
                  style: const TextStyle(color: Colors.white, fontSize: 10),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildVisibilityIndicator(String visibility) {
    IconData icon;
    Color color;
    
    switch (visibility.toLowerCase()) {
      case 'public':
        icon = Icons.public;
        color = Colors.green;
        break;
      case 'subscriber':
        icon = Icons.lock;
        color = Colors.orange;
        break;
      default:
        icon = Icons.visibility;
        color = Colors.grey;
    }
    
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.7),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Icon(
        icon,
        color: color,
        size: 12,
      ),
    );
  }

  // ===== MÉTHODES D'INTERACTION =====

  Future<void> _changeAvatar(ProfileProvider profileProvider) async {
    final ImageSource? source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Prendre une photo'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Galerie'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.cancel),
              title: const Text('Annuler'),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );

    if (source != null) {
      final XFile? image = await _imagePicker.pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 80,
      );
      
      if (image != null && mounted) {
        final File imageFile = File(image.path);
        final success = await profileProvider.uploadAvatar(imageFile);
        if (success && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Avatar mis à jour avec succès !'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    }
  }

  void _editBio(String currentBio, ProfileProvider profileProvider) {
    final TextEditingController controller = TextEditingController(text: currentBio);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Modifier la bio'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'Parlez-nous de vous...',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
          maxLength: 200,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () async {
              final newBio = controller.text.trim();
              Navigator.pop(context);
              
              if (newBio != currentBio) {
                final success = await profileProvider.updateBio(newBio);
                if (success && mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Bio mise à jour avec succès !'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              }
            },
            child: const Text('Sauvegarder'),
          ),
        ],
      ),
    );
  }

  void _editProfile(BuildContext context, ProfileProvider profileProvider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Modifier le profil'),
        content: const Text('Fonctionnalité en cours de développement'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showCreatorStats(ProfileProvider profileProvider) {
    final stats = profileProvider.stats;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Statistiques créateur'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Posts publiés: ${stats.postsCount}'),
            Text('Abonnés: ${stats.followersCount}'),
            Text('Likes reçus: ${stats.likesReceived}'),
            Text('Revenus totaux: ${stats.totalEarnings.toStringAsFixed(2)}€'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  // ✅ MÉTHODE MODIFIÉE : Menu des paramètres avec option WebSocket Test
  void _showSettingsMenu() {
    final user = context.read<AuthProvider>().user;
    
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ===== AFFICHAGE USERNAME DANS SETTINGS =====
            if (user?.username?.isNotEmpty == true) ...[
              ListTile(
                leading: const Icon(Icons.person),
                title: const Text('Connecté en tant que'),
                subtitle: Text(user!.displayName),  // @username
              ),
              const Divider(),
            ],
            
            // ===== 🧪 OPTION TEST WEBSOCKET (DÉVELOPPEMENT) =====
            ListTile(
              leading: const Icon(Icons.wifi_tethering, color: Colors.blue),
              title: const Text('Test WebSocket'),
              subtitle: const Text('Tester la messagerie en temps réel'),
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blue[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'DEV',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[800],
                  ),
                ),
              ),
              onTap: () {
                Navigator.of(context).pop();
                context.pushNamed('websocketTest');  // ✅ Navigation avec GoRouter
              },
            ),
            
            const Divider(),
            
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('Paramètres'),
              onTap: () {
                Navigator.of(context).pop();
                // TODO: Navigation vers paramètres
              },
            ),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Déconnexion'),
              onTap: () {
                Navigator.of(context).pop();
                _logout();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleCreatorUpgrade(ProfileProvider profileProvider) async {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Fonctionnalité en cours de développement'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  // ✅ MÉTHODE MODIFIÉE : Navigation vers PostDetailPage
  void _onPostTap(dynamic post) {
    debugPrint('🎯 [ProfileScreen] Post tapped - ID: ${post.id}, Title: ${post.title}');
    
    // Navigation vers la page de détail avec le post initial
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => PostDetailPage(
          postId: post.id,
          initialPost: post, // Passer le post complet pour éviter un rechargement
        ),
      ),
    );
  }

  Future<void> _logout() async {
    await context.read<AuthProvider>().logout();
  }

  String _formatCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    }
    return count.toString();
  }
}

// ===== WIDGETS AUXILIAIRES =====

class _StatColumn extends StatelessWidget {
  final String value;
  final String title;
  
  const _StatColumn({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 2),
        Text(
          title,
          style: const TextStyle(fontSize: 12, color: Colors.black87),
        ),
      ],
    );
  }
}

class _LoadingStatColumn extends StatelessWidget {
  const _LoadingStatColumn();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 30,
          height: 16,
          decoration: BoxDecoration(
            color: Colors.grey[300],
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(height: 4),
        Container(
          width: 50,
          height: 12,
          decoration: BoxDecoration(
            color: Colors.grey[300],
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ],
    );
  }
}

class _ProfileTabs extends StatelessWidget {
  const _ProfileTabs();

  @override
  Widget build(BuildContext context) {
    return const TabBar(
      indicatorColor: Colors.black,
      tabs: [
        Tab(icon: Icon(Icons.grid_on_rounded, color: Colors.black)),
        Tab(icon: Icon(Icons.shopping_bag_outlined, color: Colors.black)),
      ],
    );
  }
}

// Widget BecomeCreator intégré avec callback
class BecomeCreatorWidget extends StatelessWidget {
  final VoidCallback onRequestUpgrade;

  const BecomeCreatorWidget({
    super.key,
    required this.onRequestUpgrade,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Colors.purple, Colors.pink, Colors.orange],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '✨ Devenez créateur',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Partagez du contenu exclusif et gagnez de l\'argent avec vos abonnés !',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.purple,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: onRequestUpgrade,
              child: const Text(
                'Faire une demande',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}