// lib/features/home/presentation/widgets/subscription_stats_widget.dart

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
   return Row(
  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
  children: [
    if (isCreator)
      _buildStatColumn(
        title: 'Posts',
        value: _formatCount(postsCount),
        onTap: null,
      ),

    _buildStatColumn(
      title: 'Abonnés',
      value: _formatCount(followersCount),
      onTap: () => _navigateToFollowers(context),
    ),

    _buildStatColumn(
      title: isCreator ? 'Revenus' : 'Abonnements',
      value: isCreator
          ? '${totalEarnings.toStringAsFixed(2)}€'
          : _formatCount(followingCount),
      onTap: isCreator ? null : () => _navigateToFollowing(context),
    ),
  ],
);

  }

  Widget _buildStatColumn({
    required String title,
    required String value,
    VoidCallback? onTap,
  }) {
    Widget child = Column(
      children: [
        if (isLoadingStats)
          _buildLoadingIndicator()
        else
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        const SizedBox(height: 2),
        Text(
          title,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.black87,
          ),
        ),
      ],
    );

    // Si cliquable, entourer d'un GestureDetector
    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: Colors.transparent,
          ),
          child: child,
        ),
      );
    }

    return child;
  }

  Widget _buildLoadingIndicator() {
    return Container(
      width: 30,
      height: 16,
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(4),
      ),
      child: const Center(
        child: SizedBox(
          width: 12,
          height: 12,
          child: CircularProgressIndicator(
            strokeWidth: 1,
            color: Colors.grey,
          ),
        ),
      ),
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