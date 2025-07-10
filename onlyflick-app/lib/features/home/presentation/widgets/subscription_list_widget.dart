// lib/features/home/presentation/widgets/subscription_list_widget.dart

import 'package:flutter/material.dart';
import '../../../../core/models/subscription_model.dart';
import '../../../../core/services/subscription_service.dart';
import '../../../../core/utils/constants.dart';

class SubscriptionListWidget extends StatefulWidget {
  final int userId;
  final String listType; // "followers" ou "following"
  final bool isCurrentUser; // Si c'est le profil de l'utilisateur connecté
  final bool showHeader; // Pour contrôler l'affichage du header

  const SubscriptionListWidget({
    Key? key,
    required this.userId,
    required this.listType,
    this.isCurrentUser = false,
    this.showHeader = true, // Par défaut, on affiche le header
  }) : super(key: key);

  @override
  State<SubscriptionListWidget> createState() => _SubscriptionListWidgetState();
}

class _SubscriptionListWidgetState extends State<SubscriptionListWidget> {
  List<Subscription> subscriptions = [];
  bool isLoading = true;
  String? errorMessage;
  int totalCount = 0;

  @override
  void initState() {
    super.initState();
    _loadSubscriptions();
  }

  Future<void> _loadSubscriptions() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      SubscriptionListResponse response;
      
      if (widget.listType == "followers") {
        response = await SubscriptionService.getFollowers(widget.userId);
      } else {
        response = await SubscriptionService.getFollowing(widget.userId);
      }

      setState(() {
        subscriptions = response.subscriptions;
        totalCount = response.total;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        errorMessage = e.toString().replaceAll('Exception: ', '');
        isLoading = false;
      });
    }
  }

  Future<void> _handleUnfollow(int creatorId, int index) async {
    try {
      bool success = await SubscriptionService.unfollowCreator(creatorId);
      if (success) {
        setState(() {
          subscriptions.removeAt(index);
          totalCount--;
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Désabonnement réussi'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: ${e.toString().replaceAll('Exception: ', '')}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showUnfollowDialog(UserProfile user, int index) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirmer le désabonnement'),
          content: Text('Voulez-vous vraiment vous désabonner de ${user.fullName} ?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Annuler'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _handleUnfollow(user.id, index);
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Se désabonner'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Si showHeader est true, on affiche avec Scaffold et AppBar
    if (widget.showHeader) {
      return Scaffold(
        appBar: AppBar(
          title: Text(
            widget.listType == "followers" 
              ? 'Abonnés ($totalCount)' 
              : 'Abonnements ($totalCount)'
          ),
          backgroundColor: const Color(AppColors.primaryColor),
          foregroundColor: Colors.white,
        ),
        body: _buildBody(),
      );
    }
    
    // Sinon, on affiche juste le body sans header
    return _buildBody();
  }

  Widget _buildBody() {
    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          color: Color(AppColors.primaryColor),
        ),
      );
    }

    if (errorMessage != null) {
      return Center(
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
              errorMessage!,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadSubscriptions,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(AppColors.primaryColor),
                foregroundColor: Colors.white,
              ),
              child: const Text('Réessayer'),
            ),
          ],
        ),
      );
    }

    if (subscriptions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              widget.listType == "followers" 
                ? Icons.people_outline 
                : Icons.person_add_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              widget.listType == "followers"
                ? 'Aucun abonné pour le moment'
                : 'Aucun abonnement pour le moment',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadSubscriptions,
      color: const Color(AppColors.primaryColor),
      child: ListView.builder(
        itemCount: subscriptions.length,
        itemBuilder: (context, index) {
          final subscription = subscriptions[index];
          final user = widget.listType == "followers" 
            ? subscription.subscriberProfile 
            : subscription.creatorProfile;

          if (user == null) return const SizedBox.shrink();

          return _buildUserTile(user, index);
        },
      ),
    );
  }

  Widget _buildUserTile(UserProfile user, int index) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          radius: AppConstants.avatarSize / 2,
          backgroundColor: const Color(AppColors.primaryColor),
          backgroundImage: user.avatarUrl?.isNotEmpty == true 
            ? NetworkImage(user.avatarUrl!)
            : null,
          child: user.avatarUrl?.isEmpty != false
            ? Text(
                user.fullName.isNotEmpty 
                  ? user.fullName[0].toUpperCase()
                  : user.username[0].toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              )
            : null,
        ),
        title: Text(
          user.fullName.isNotEmpty ? user.fullName : user.username,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '@${user.username}',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
            if (user.bio?.isNotEmpty == true) ...[
              const SizedBox(height: 4),
              Text(
                user.bio!,
                style: TextStyle(
                  color: Colors.grey[700],
                  fontSize: 13,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
        trailing: widget.isCurrentUser && widget.listType == "following"
          ? IconButton(
              onPressed: () => _showUnfollowDialog(user, index),
              icon: const Icon(Icons.person_remove),
              color: Colors.red,
              tooltip: 'Se désabonner',
            )
          : user.role == AppConstants.creatorRole
            ? Icon(
                Icons.verified,
                color: const Color(AppColors.primaryColor),
                size: 20,
              )
            : null,
        onTap: () {
          // Navigation vers le profil de l'utilisateur
          Navigator.pushNamed(
            context, 
            '/profile',
            arguments: {'userId': user.id},
          );
        },
      ),
    );
  }
}