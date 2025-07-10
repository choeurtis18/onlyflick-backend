//lib/features/home/presentation/pages/subscription_management_page.dart
import 'package:flutter/material.dart';

import '../../../../core/models/subscription_model.dart';
import '../../../../core/services/subscription_service.dart';
import '../widgets/buttons/subscription_button.dart';



class SubscriptionManagementPage extends StatefulWidget {
  final int? userId; // Si null, utilise l'utilisateur connecté

  const SubscriptionManagementPage({
    Key? key,
    this.userId,
  }) : super(key: key);

  @override
  State<SubscriptionManagementPage> createState() => _SubscriptionManagementPageState();
}

class _SubscriptionManagementPageState extends State<SubscriptionManagementPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  List<Subscription> _following = [];
  List<Subscription> _followers = [];
  Map<String, int> _stats = {};
  
  bool _isLoadingFollowing = true;
  bool _isLoadingFollowers = true;
  bool _isLoadingStats = true;
  
  String? _errorFollowing;
  String? _errorFollowers;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final userId = widget.userId ?? 1; 
    
    await Future.wait([
      _loadFollowing(userId),
      _loadFollowers(userId),
      _loadStats(userId),
    ]);
  }

  Future<void> _loadFollowing(int userId) async {
    try {
      setState(() {
        _isLoadingFollowing = true;
        _errorFollowing = null;
      });

      final response = await SubscriptionService.getFollowing(userId);
      
      if (mounted) {
        setState(() {
          _following = response.subscriptions;
          _isLoadingFollowing = false;
        });
      }
    } catch (e) {
      print('❌ [SubscriptionManagement] Erreur chargement following: $e');
      if (mounted) {
        setState(() {
          _errorFollowing = e.toString();
          _isLoadingFollowing = false;
        });
      }
    }
  }

  Future<void> _loadFollowers(int userId) async {
    try {
      setState(() {
        _isLoadingFollowers = true;
        _errorFollowers = null;
      });

      final response = await SubscriptionService.getFollowers(userId);
      
      if (mounted) {
        setState(() {
          _followers = response.subscriptions;
          _isLoadingFollowers = false;
        });
      }
    } catch (e) {
      print('❌ [SubscriptionManagement] Erreur chargement followers: $e');
      if (mounted) {
        setState(() {
          _errorFollowers = e.toString();
          _isLoadingFollowers = false;
        });
      }
    }
  }

  Future<void> _loadStats(int userId) async {
    try {
      setState(() {
        _isLoadingStats = true;
      });

      final stats = await SubscriptionService.getSubscriptionStats(userId);
      
      if (mounted) {
        setState(() {
          _stats = stats;
          _isLoadingStats = false;
        });
      }
    } catch (e) {
      print('❌ [SubscriptionManagement] Erreur chargement stats: $e');
      if (mounted) {
        setState(() {
          _isLoadingStats = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mes Abonnements'),
        elevation: 0,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        foregroundColor: Theme.of(context).textTheme.titleLarge?.color,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(100),
          child: Column(
            children: [
              // Statistiques
              _buildStatsSection(),
              
              // Tabs
              TabBar(
                controller: _tabController,
                labelColor: Theme.of(context).primaryColor,
                unselectedLabelColor: Colors.grey,
                indicatorColor: Theme.of(context).primaryColor,
                tabs: [
                  Tab(
                    text: 'Abonnements (${_following.length})',
                    icon: const Icon(Icons.favorite, size: 20),
                  ),
                  Tab(
                    text: 'Abonnés (${_followers.length})',
                    icon: const Icon(Icons.people, size: 20),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildFollowingTab(),
          _buildFollowersTab(),
        ],
      ),
    );
  }

  Widget _buildStatsSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildStatItem(
            'Abonnements',
            _isLoadingStats ? '...' : '${_stats['following_count'] ?? 0}',
            Icons.favorite_outline,
            Colors.red,
          ),
          _buildStatItem(
            'Abonnés',
            _isLoadingStats ? '...' : '${_stats['followers_count'] ?? 0}',
            Icons.people_outline,
            Colors.blue,
          ),
          _buildStatItem(
            'Posts',
            _isLoadingStats ? '...' : '${_stats['posts_count'] ?? 0}',
            Icons.article_outlined,
            Colors.green,
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildFollowingTab() {
    if (_isLoadingFollowing) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorFollowing != null) {
      return _buildErrorWidget(
        _errorFollowing!,
        () => _loadFollowing(widget.userId ?? 1),
      );
    }

    if (_following.isEmpty) {
      return _buildEmptyWidget(
        'Aucun abonnement',
        'Vous ne suivez encore aucun créateur.\nDécouvrez du contenu et abonnez-vous !',
        Icons.favorite_border,
      );
    }

    return RefreshIndicator(
      onRefresh: () => _loadFollowing(widget.userId ?? 1),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _following.length,
        itemBuilder: (context, index) {
          final subscription = _following[index];
          return _buildSubscriptionCard(subscription, isFollowing: true);
        },
      ),
    );
  }

  Widget _buildFollowersTab() {
    if (_isLoadingFollowers) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorFollowers != null) {
      return _buildErrorWidget(
        _errorFollowers!,
        () => _loadFollowers(widget.userId ?? 1),
      );
    }

    if (_followers.isEmpty) {
      return _buildEmptyWidget(
        'Aucun abonné',
        'Personne ne vous suit encore.\nCréez du contenu pour attirer des abonnés !',
        Icons.people_outline,
      );
    }

    return RefreshIndicator(
      onRefresh: () => _loadFollowers(widget.userId ?? 1),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _followers.length,
        itemBuilder: (context, index) {
          final subscription = _followers[index];
          return _buildSubscriptionCard(subscription, isFollowing: false);
        },
      ),
    );
  }

  Widget _buildSubscriptionCard(Subscription subscription, {required bool isFollowing}) {
    final userProfile = isFollowing ? subscription.creatorProfile : subscription.subscriberProfile;
    
    if (userProfile == null) {
      return const SizedBox.shrink();
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Avatar
            CircleAvatar(
              radius: 30,
              backgroundImage: userProfile.avatarUrl != null
                  ? NetworkImage(userProfile.avatarUrl!)
                  : null,
              child: userProfile.avatarUrl == null
                  ? Text(
                      userProfile.username.isNotEmpty
                          ? userProfile.username[0].toUpperCase()
                          : '?',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    )
                  : null,
            ),
            
            const SizedBox(width: 16),
            
            // Informations utilisateur
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    userProfile.fullName.isNotEmpty 
                        ? userProfile.fullName 
                        : userProfile.username,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '@${userProfile.username}',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                  if (userProfile.bio != null && userProfile.bio!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      userProfile.bio!,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[700],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _buildStatusChip(subscription.status),
                      const SizedBox(width: 8),
                      Text(
                        'Depuis ${_formatDate(subscription.createdAt)}',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            // Bouton d'action
            if (isFollowing) ...[
              CompactSubscriptionButton(
                creatorId: subscription.creatorId,
                creatorProfile: userProfile,
                onSubscriptionChanged: () {
                  _loadFollowing(widget.userId ?? 1);
                  _loadStats(widget.userId ?? 1);
                },
              ),
            ] else ...[
              IconButton(
                onPressed: () {
                  // Navigation vers le profil de l'abonné
                },
                icon: const Icon(Icons.person),
                tooltip: 'Voir le profil',
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(bool isActive) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isActive ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isActive ? Colors.green : Colors.red,
          width: 1,
        ),
      ),
      child: Text(
        isActive ? 'Actif' : 'Inactif',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: isActive ? Colors.green : Colors.red,
        ),
      ),
    );
  }

  Widget _buildErrorWidget(String error, VoidCallback onRetry) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'Erreur de chargement',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error.contains('404') 
                  ? 'Service temporairement indisponible'
                  : 'Vérifiez votre connexion internet',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Réessayer'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyWidget(String title, String subtitle, IconData icon) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays < 1) {
      return 'aujourd\'hui';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}j';
    } else if (difference.inDays < 30) {
      return '${(difference.inDays / 7).floor()}sem';
    } else if (difference.inDays < 365) {
      return '${(difference.inDays / 30).floor()}mois';
    } else {
      return '${(difference.inDays / 365).floor()}an';
    }
  }
}