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
import '../../../../core/services/api_service.dart';

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
  final ApiService _apiService = ApiService();
  
  // État de la demande de créateur
  bool _isRequestingCreator = false;
  bool _hasExistingRequest = false;

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
                    
                    // Widget BecomeCreator pour les non-créateurs - AMÉLIORÉ
                    if (!userIsCreator) 
                      _buildBecomeCreatorWidget(),
                    
                    if (userIsCreator) const _ProfileTabs(),
                    const SizedBox(height: 8),
                    Expanded(
                      child: userIsCreator 
                        ? TabBarView(
                            children: [
                              _buildGrid(type: 'normal', profileProvider: profileProvider, userIsCreator: userIsCreator),
                              _buildGrid(type: 'shop', profileProvider: profileProvider, userIsCreator: userIsCreator),
                            ],
                          )
                        : _buildGrid(type: 'normal', profileProvider: profileProvider, userIsCreator: userIsCreator),
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
              postsCount: userIsCreator ? profileProvider.postsCount : 0,
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
          //  NOM D'AFFICHAGE PUBLIC : @USERNAME 
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

  /// 🚀 WIDGET DEVENIR CRÉATEUR AMÉLIORÉ
  Widget _buildBecomeCreatorWidget() {
    if (_hasExistingRequest) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.orange[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.orange[200]!),
        ),
        child: Row(
          children: [
            Icon(Icons.hourglass_top, color: Colors.orange[600], size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Demande en cours de traitement',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange[800],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Votre demande de passage en créateur a été envoyée et est en cours d\'examen.',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: Colors.orange[700],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

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
              onPressed: _isRequestingCreator ? null : () => _handleCreatorUpgrade(),
              child: _isRequestingCreator
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.purple),
                      ),
                    )
                  : const Text(
                      'Faire une demande',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  //  Gestion différenciée pour créateurs et abonnés
  Widget _buildGrid({required String type, required ProfileProvider profileProvider, required bool userIsCreator}) {
    //  État de chargement
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

    //  GESTION D'ERREUR DIFFÉRENCIÉE PAR RÔLE
    if (profileProvider.error != null) {
      // Pour les créateurs : afficher l'erreur avec possibilité de retry
      if (userIsCreator) {
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
      } else {
        // Pour les abonnés : état vide élégant au lieu d'une erreur
        return _buildSubscriberEmptyState();
      }
    }

    // Filtrer les posts selon le type d'onglet
    List<dynamic> filteredPosts = profileProvider.userPosts;
    if (type == 'shop') {
      filteredPosts = profileProvider.userPosts
          .where((post) => post.visibility == 'subscriber')
          .toList();
    }

    //  ÉTAT VIDE DIFFÉRENCIÉ PAR RÔLE
    if (filteredPosts.isEmpty) {
      //  Vérifier si on est encore en train d'initialiser
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
      
      // ÉTAT VIDE POUR ABONNÉS (subscribers)
      if (!userIsCreator) {
        return _buildSubscriberEmptyState();
      }
      
      //  ÉTAT VIDE POUR CRÉATEURS
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
            ElevatedButton.icon(
              onPressed: () {
                // Navigation vers création de post pour les créateurs
                context.pushNamed('createPost');
              },
              icon: const Icon(Icons.add),
              label: const Text('Créer un post'),
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

  Widget _buildSubscriberEmptyState() {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Container(
        constraints: BoxConstraints(
          minHeight: MediaQuery.of(context).size.height * 0.5,
        ),
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icône
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.blue.withOpacity(0.1),
              ),
              child: Icon(
                Icons.explore_outlined,
                size: 48,
                color: Colors.blue[400],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Titre
            Text(
              'Découvrez du contenu incroyable !',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
              textAlign: TextAlign.center,
            ),
            
            const SizedBox(height: 12),
            
            // Description
            Text(
              'En tant qu\'abonné, explorez le contenu des créateurs, likez et commentez leurs posts.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            
            const SizedBox(height: 24),
            
            // Boutons Call-to-Action
            Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      // Navigation vers la page de recherche
                      context.pushNamed('search');
                    },
                    icon: const Icon(Icons.search),
                    label: const Text('Rechercher du contenu'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height: 12),
                
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      // Navigation vers l'accueil/découverte
                      context.pushNamed('main');
                    },
                    icon: const Icon(Icons.home),
                    label: const Text('Retour à l\'accueil'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            
            SizedBox(height: MediaQuery.of(context).viewInsets.bottom + 20),
          ],
        ),
      ),
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

  //  Menu des paramètres avec option WebSocket Test
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
                context.pushNamed('websocketTest');  
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
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text(
                'Déconnexion',
                style: TextStyle(color: Colors.red),
              ),
              onTap: () {
                Navigator.of(context).pop();
                _showLogoutConfirmation();
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Demande de passage en créateur avec API
  Future<void> _handleCreatorUpgrade() async {
    // Confirmer l'action avec l'utilisateur
    final confirmed = await _showCreatorUpgradeDialog();
    if (!confirmed) return;

    setState(() {
      _isRequestingCreator = true;
    });

    try {
      debugPrint('🚀 [ProfileScreen] Requesting creator upgrade...');
      
      final response = await _apiService.post('/profile/request-upgrade');
      
      if (response.isSuccess) {
        setState(() {
          _hasExistingRequest = true;
          _isRequestingCreator = false;
        });
        
        // Afficher un message de succès
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text('Demande de passage en créateur envoyée avec succès !'),
                  ),
                ],
              ),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 4),
            ),
          );
        }
        
        debugPrint('✅ [ProfileScreen] Creator upgrade request sent successfully');
      } else {
        setState(() {
          _isRequestingCreator = false;
        });
        
        // Afficher le message d'erreur
        final errorMessage = response.error ?? 'Erreur lors de la demande de passage en créateur';
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.error, color: Colors.white),
                  const SizedBox(width: 8),
                  Expanded(child: Text(errorMessage)),
                ],
              ),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 4),
            ),
          );
        }
        
        debugPrint('❌ [ProfileScreen] Creator upgrade request failed: $errorMessage');
      }
    } catch (e) {
      setState(() {
        _isRequestingCreator = false;
      });
      
      final errorMessage = 'Erreur de connexion: ${e.toString()}';
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(child: Text(errorMessage)),
              ],
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
      
      debugPrint('❌ [ProfileScreen] Creator upgrade request error: $e');
    }
  }

  /// DIALOGUE DE CONFIRMATION POUR DEVENIR CRÉATEUR
  Future<bool> _showCreatorUpgradeDialog() async {
    return await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.star, color: Colors.amber, size: 28),
              const SizedBox(width: 8),
              Text(
                'Devenir Créateur',
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Êtes-vous sûr de vouloir demander le passage en compte créateur ?',
                style: GoogleFonts.inter(fontSize: 16),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'En tant que créateur, vous pourrez :',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildBenefitItem('✅ Publier du contenu premium'),
                    _buildBenefitItem('💰 Recevoir des abonnements payants'),
                    _buildBenefitItem('👥 Gérer votre communauté d\'abonnés'),
                    _buildBenefitItem('📊 Accéder aux statistiques avancées'),
                    _buildBenefitItem('🎯 Définir vos propres tarifs'),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'ℹ️ Votre demande sera examinée par notre équipe dans les 24-48h.',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.blue[700],
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                'Annuler',
                style: GoogleFonts.inter(color: Colors.grey[600]),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              child: Text(
                'Envoyer la demande',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        );
      },
    ) ?? false;
  }

  /// 📝 ÉLÉMENT DE BÉNÉFICE
  Widget _buildBenefitItem(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.inter(fontSize: 13),
            ),
          ),
        ],
      ),
    );
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

  /// 🚪 DIALOGUE DE CONFIRMATION POUR LA DÉCONNEXION
  Future<void> _showLogoutConfirmation() async {
    final user = context.read<AuthProvider>().user;
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.logout, color: Colors.red[600], size: 24),
              const SizedBox(width: 8),
              Text(
                'Déconnexion',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Êtes-vous sûr de vouloir vous déconnecter ?',
                style: GoogleFonts.inter(fontSize: 16),
              ),
              const SizedBox(height: 12),
              if (user != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: Colors.blue[100],
                        backgroundImage: user.avatarUrl?.isNotEmpty == true
                            ? NetworkImage(user.avatarUrl!)
                            : null,
                        child: user.avatarUrl?.isEmpty != false
                            ? Text(
                                user.username.isNotEmpty 
                                    ? user.username[0].toUpperCase()
                                    : '?',
                                style: GoogleFonts.inter(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue[800],
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user.displayName,
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              user.email,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.amber[50],
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'ℹ️ Vous devrez vous reconnecter pour accéder à votre compte.',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.amber[700],
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                'Annuler',
                style: GoogleFonts.inter(color: Colors.grey[600]),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              child: Text(
                'Se déconnecter',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        );
      },
    ) ?? false;

    if (confirmed) {
      await _performLogout();
    }
  }

  /// 🚪 DÉCONNEXION AVEC FEEDBACK UTILISATEUR
  Future<void> _performLogout() async {
    try {
      // Afficher un indicateur de chargement
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return Dialog(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(width: 16),
                  Text(
                    'Déconnexion en cours...',
                    style: GoogleFonts.inter(fontSize: 16),
                  ),
                ],
              ),
            ),
          );
        },
      );

      // Effectuer la déconnexion
      debugPrint('🚪 [ProfileScreen] Starting logout process...');
      await context.read<AuthProvider>().logout();
      debugPrint('✅ [ProfileScreen] Logout completed successfully');

      // Fermer le dialogue de chargement
      if (mounted) {
        Navigator.of(context).pop();
        
        // Afficher un message de confirmation
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Déconnexion réussie. À bientôt !',
                    style: GoogleFonts.inter(),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );

       
      }

    } catch (e) {
      debugPrint('❌ [ProfileScreen] Logout error: $e');
      
      // Fermer le dialogue de chargement en cas d'erreur
      if (mounted) {
        Navigator.of(context).pop();
        
        // Afficher un message d'erreur
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Erreur lors de la déconnexion. Veuillez réessayer.',
                    style: GoogleFonts.inter(),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
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