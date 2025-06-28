import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:matchmaker/features/auth/auth_provider.dart';
import 'package:matchmaker/core/providers/posts_providers.dart';

/// Widget qui synchronise l'AuthProvider avec le PostsProvider
class AppProvidersWrapper extends StatefulWidget {
  final Widget child;

  const AppProvidersWrapper({
    super.key,
    required this.child,
  });

  @override
  State<AppProvidersWrapper> createState() => _AppProvidersWrapperState();
}

class _AppProvidersWrapperState extends State<AppProvidersWrapper> {
  @override
  void initState() {
    super.initState();
    
    // Synchroniser les providers après le premier build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncProviders();
    });
  }

  void _syncProviders() {
    final authProvider = context.read<AuthProvider>();
    final postsProvider = context.read<PostsProvider>();
    
    // Définir l'utilisateur actuel dans le PostsProvider
    postsProvider.setCurrentUser(authProvider.user?.id);
    
    // Écouter les changements d'authentification
    authProvider.addListener(() {
      final user = authProvider.user;
      
      if (user != null) {
        // Utilisateur connecté
        postsProvider.setCurrentUser(user.id);
      } else {
        // Utilisateur déconnecté
        postsProvider.clearUserData();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}