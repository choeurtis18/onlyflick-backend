// lib/widgets/subscription_stats_widget.dart

import 'package:flutter/material.dart';
import '../pages/subscriptions_page.dart';
import '../../../../core/utils/constants.dart';

class SubscriptionStatsWidget extends StatelessWidget {
  final int postsCount;
  final int followersCount;
  final int followingCount;
  final double totalEarnings;
  final int userId;
  final bool isCreator;
  final bool isCurrentUser;
  final bool isLoadingStats;

  const SubscriptionStatsWidget({
    Key? key,
    required this.postsCount,
    required this.followersCount,
    required this.followingCount,
    required this.totalEarnings,
    required this.userId,
    required this.isCreator,
    required this.isCurrentUser,
    this.isLoadingStats = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (isLoadingStats) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: List.generate(3, (index) => const _LoadingStatColumn()),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        // Posts (non cliquable)
        _StatColumn(
          value: _formatCount(postsCount),
          title: 'Posts',
          onTap: null,
        ),
        
        // Abonnés (cliquable si créateur ou si on regarde un autre profil)
        _StatColumn(
          value: _formatCount(followersCount),
          title: 'Abonnés',
          onTap: (isCreator || !isCurrentUser) ? () {
            _navigateToFollowers(context);
          } : null,
        ),
        
        // Revenus pour créateur / Abonnements pour autres
        if (isCreator && isCurrentUser)
          _StatColumn(
            value: '${totalEarnings.toStringAsFixed(1)}€',
            title: 'Revenus',
            onTap: null,
          )
        else
          _StatColumn(
            value: _formatCount(followingCount),
            title: 'Abonnements',
            onTap: () {
              _navigateToFollowing(context);
            },
          ),
      ],
    );
  }

  void _navigateToFollowers(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SubscriptionsPage(
          userId: userId,
          initialTab: "followers",
          isCurrentUser: isCurrentUser,
        ),
      ),
    );
  }

  void _navigateToFollowing(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SubscriptionsPage(
          userId: userId,
          initialTab: "following",
          isCurrentUser: isCurrentUser,
        ),
      ),
    );
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

class _StatColumn extends StatelessWidget {
  final String value;
  final String title;
  final VoidCallback? onTap;
  
  const _StatColumn({
    required this.title, 
    required this.value,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Widget content = Column(
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

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: Colors.transparent,
          ),
          child: content,
        ),
      );
    }

    return content;
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