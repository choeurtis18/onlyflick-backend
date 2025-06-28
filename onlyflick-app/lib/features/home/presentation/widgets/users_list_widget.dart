// lib/features/search/presentation/widgets/users_list_widget.dart

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/models/search_models.dart';

/// Widget pour afficher une liste d'utilisateurs avec pagination
class UsersListWidget extends StatefulWidget {
  final List<UserSearchResult> users;
  final bool hasMore;
  final bool isLoadingMore;
  final VoidCallback onLoadMore;
  final Function(UserSearchResult) onUserTap;
  final Function(UserSearchResult)? onFollowToggle;
  final EdgeInsets? padding;
  final bool showFollowButton;
  final bool showStats;
  final bool showBio;

  const UsersListWidget({
    super.key,
    required this.users,
    required this.hasMore,
    required this.isLoadingMore,
    required this.onLoadMore,
    required this.onUserTap,
    this.onFollowToggle,
    this.padding,
    this.showFollowButton = true,
    this.showStats = true,
    this.showBio = true,
  });

  @override
  State<UsersListWidget> createState() => _UsersListWidgetState();
}

class _UsersListWidgetState extends State<UsersListWidget> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= 
        _scrollController.position.maxScrollExtent - 200) {
      if (widget.hasMore && !widget.isLoadingMore) {
        widget.onLoadMore();
      }
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.users.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.separated(
      controller: _scrollController,
      padding: widget.padding ?? const EdgeInsets.all(16),
      itemCount: widget.users.length + (widget.hasMore ? 1 : 0),
      separatorBuilder: (context, index) => const Divider(
        height: 1,
        color: Colors.grey,
        indent: 60,
      ),
      itemBuilder: (context, index) {
        if (index >= widget.users.length) {
          return _buildLoadingTile();
        }

        final user = widget.users[index];
        return UserListTile(
          user: user,
          onTap: () => widget.onUserTap(user),
          onFollowToggle: widget.onFollowToggle != null 
              ? () => widget.onFollowToggle!(user)
              : null,
          showFollowButton: widget.showFollowButton,
          showStats: widget.showStats,
          showBio: widget.showBio,
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.people_outline,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'Aucun utilisateur trouvé',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Essayez avec un autre terme de recherche',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingTile() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: const Row(
        children: [
          SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              color: Colors.black,
              strokeWidth: 2,
            ),
          ),
          SizedBox(width: 16),
          Text(
            'Chargement...',
            style: TextStyle(
              color: Colors.grey,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

/// Widget pour une tuile d'utilisateur individuelle
class UserListTile extends StatefulWidget {
  final UserSearchResult user;
  final VoidCallback onTap;
  final VoidCallback? onFollowToggle;
  final bool showFollowButton;
  final bool showStats;
  final bool showBio;
  final bool isCompact;

  const UserListTile({
    super.key,
    required this.user,
    required this.onTap,
    this.onFollowToggle,
    this.showFollowButton = true,
    this.showStats = true,
    this.showBio = true,
    this.isCompact = false,
  });

  @override
  State<UserListTile> createState() => _UserListTileState();
}

class _UserListTileState extends State<UserListTile> 
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  bool _isFollowLoading = false;

  @override
  void initState() {
    super.initState();
    
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.98,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _onFollowPressed() async {
    if (widget.onFollowToggle == null) return;
    
    setState(() => _isFollowLoading = true);
    
    try {
      widget.onFollowToggle!();
      // Animation feedback
      _animationController.forward().then((_) {
        _animationController.reverse();
      });
    } finally {
      if (mounted) {
        setState(() => _isFollowLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.onTap,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: EdgeInsets.all(widget.isCompact ? 8 : 12),
                child: Row(
                  children: [
                    _buildAvatar(),
                    const SizedBox(width: 12),
                    Expanded(child: _buildUserInfo()),
                    if (widget.showFollowButton) _buildFollowButton(),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAvatar() {
    final size = widget.isCompact ? 40.0 : 50.0;
    
    return Stack(
      children: [
        CircleAvatar(
          radius: size / 2,
          backgroundColor: Colors.grey[200],
          backgroundImage: widget.user.avatarUrl != null
              ? CachedNetworkImageProvider(widget.user.avatarUrl!)
              : null,
          child: widget.user.avatarUrl == null
              ? Text(
                  _getInitials(widget.user.firstName, widget.user.lastName),
                  style: TextStyle(
                    fontSize: widget.isCompact ? 16 : 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[700],
                  ),
                )
              : null,
        ),
        if (widget.user.isCreator)
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              width: widget.isCompact ? 16 : 18,
              height: widget.isCompact ? 16 : 18,
              decoration: const BoxDecoration(
                color: Colors.blue,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.verified,
                color: Colors.white,
                size: widget.isCompact ? 10 : 12,
              ),
            ),
          ),
        if (_isOnline()) // Simulé - à connecter avec un système de présence réel
          Positioned(
            bottom: 2,
            right: 2,
            child: Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: Colors.green,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildUserInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                widget.user.fullName,
                style: TextStyle(
                  fontSize: widget.isCompact ? 14 : 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (widget.user.mutualFollowers > 0) _buildMutualFollowersBadge(),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          widget.user.displayName,
          style: TextStyle(
            fontSize: widget.isCompact ? 12 : 14,
            color: Colors.grey[600],
            fontWeight: FontWeight.w400,
          ),
        ),
        if (widget.showBio && widget.user.bio != null && widget.user.bio!.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            widget.user.bio!,
            style: TextStyle(
              fontSize: widget.isCompact ? 11 : 13,
              color: Colors.grey[700],
            ),
            maxLines: widget.isCompact ? 1 : 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
        if (widget.showStats && !widget.isCompact) ...[
          const SizedBox(height: 6),
          _buildStatsRow(),
        ],
      ],
    );
  }

  Widget _buildStatsRow() {
    return Row(
      children: [
        _buildStatItem(
          widget.user.followersCount,
          'abonnés',
          Icons.people_outline,
        ),
        const SizedBox(width: 16),
        _buildStatItem(
          widget.user.postsCount,
          'posts',
          Icons.photo_library_outlined,
        ),
      ],
    );
  }

  Widget _buildStatItem(int count, String label, IconData icon) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 14,
          color: Colors.grey[500],
        ),
        const SizedBox(width: 4),
        Text(
          '${_formatCount(count)} $label',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildMutualFollowersBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: Text(
        '${widget.user.mutualFollowers} en commun',
        style: TextStyle(
          fontSize: 10,
          color: Colors.blue[700],
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildFollowButton() {
    if (_isFollowLoading) {
      return const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(
          color: Colors.black,
          strokeWidth: 2,
        ),
      );
    }

    final isFollowing = widget.user.isFollowing;
    
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      child: ElevatedButton(
        onPressed: _onFollowPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: isFollowing ? Colors.grey[200] : Colors.black,
          foregroundColor: isFollowing ? Colors.black : Colors.white,
          elevation: 0,
          padding: EdgeInsets.symmetric(
            horizontal: widget.isCompact ? 12 : 16,
            vertical: widget.isCompact ? 6 : 8,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          minimumSize: Size(widget.isCompact ? 60 : 80, 32),
        ),
        child: Text(
          isFollowing ? 'Suivi' : 'Suivre',
          style: TextStyle(
            fontSize: widget.isCompact ? 12 : 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  String _getInitials(String firstName, String lastName) {
    final first = firstName.isNotEmpty ? firstName[0] : '';
    final last = lastName.isNotEmpty ? lastName[0] : '';
    return (first + last).toUpperCase();
  }

  String _formatCount(int count) {
    if (count < 1000) return count.toString();
    if (count < 1000000) return '${(count / 1000).toStringAsFixed(1)}k';
    return '${(count / 1000000).toStringAsFixed(1)}M';
  }

  bool _isOnline() {
    // Simulé - à remplacer par une vraie logique de présence
    return widget.user.id % 3 == 0; // 1/3 des utilisateurs "en ligne"
  }
}

/// Widget compact pour afficher des utilisateurs dans une liste horizontale
class HorizontalUsersWidget extends StatelessWidget {
  final List<UserSearchResult> users;
  final Function(UserSearchResult) onUserTap;
  final double itemWidth;
  final double height;

  const HorizontalUsersWidget({
    super.key,
    required this.users,
    required this.onUserTap,
    this.itemWidth = 120,
    this.height = 140,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: users.length,
        separatorBuilder: (context, index) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final user = users[index];
          return SizedBox(
            width: itemWidth,
            child: _buildUserCard(user),
          );
        },
      ),
    );
  }

  Widget _buildUserCard(UserSearchResult user) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onUserTap(user),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[200]!),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              Stack(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.grey[200],
                    backgroundImage: user.avatarUrl != null
                        ? CachedNetworkImageProvider(user.avatarUrl!)
                        : null,
                    child: user.avatarUrl == null
                        ? Text(
                            user.firstName[0].toUpperCase(),
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[700],
                            ),
                          )
                        : null,
                  ),
                  if (user.isCreator)
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        width: 20,
                        height: 20,
                        decoration: const BoxDecoration(
                          color: Colors.blue,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.verified,
                          color: Colors.white,
                          size: 14,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                user.firstName,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 2),
              Text(
                user.displayName,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                '${_formatCount(user.followersCount)} abonnés',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[500],
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatCount(int count) {
    if (count < 1000) return count.toString();
    if (count < 1000000) return '${(count / 1000).toStringAsFixed(1)}k';
    return '${(count / 1000000).toStringAsFixed(1)}M';
  }
}

/// Widget de grille d'utilisateurs pour les pages de followers/following
class UsersGridWidget extends StatelessWidget {
  final List<UserSearchResult> users;
  final Function(UserSearchResult) onUserTap;
  final Function(UserSearchResult)? onFollowToggle;
  final int crossAxisCount;

  const UsersGridWidget({
    super.key,
    required this.users,
    required this.onUserTap,
    this.onFollowToggle,
    this.crossAxisCount = 2,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 0.75,
      ),
      itemCount: users.length,
      itemBuilder: (context, index) {
        final user = users[index];
        return _buildUserGridTile(user);
      },
    );
  }

  Widget _buildUserGridTile(UserSearchResult user) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          const SizedBox(height: 16),
          Stack(
            children: [
              CircleAvatar(
                radius: 35,
                backgroundColor: Colors.grey[200],
                backgroundImage: user.avatarUrl != null
                    ? CachedNetworkImageProvider(user.avatarUrl!)
                    : null,
                child: user.avatarUrl == null
                    ? Text(
                        user.firstName[0].toUpperCase(),
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[700],
                        ),
                      )
                    : null,
              ),
              if (user.isCreator)
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: const BoxDecoration(
                      color: Colors.blue,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.verified,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              user.fullName,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            user.displayName,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            '${_formatCount(user.followersCount)} abonnés',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[500],
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
          const Spacer(),
          if (onFollowToggle != null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => onFollowToggle!(user),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: user.isFollowing ? Colors.grey[200] : Colors.black,
                    foregroundColor: user.isFollowing ? Colors.black : Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    user.isFollowing ? 'Suivi' : 'Suivre',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _formatCount(int count) {
    if (count < 1000) return count.toString();
    if (count < 1000000) return '${(count / 1000).toStringAsFixed(1)}k';
    return '${(count / 1000000).toStringAsFixed(1)}M';
  }
}