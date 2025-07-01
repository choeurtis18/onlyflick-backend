// lib/router.dart - Avec protection créateur + page recherche

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:matchmaker/features/home/presentation/pages/main_screen.dart';
import 'package:matchmaker/features/home/presentation/pages/create_post_page.dart';
import 'package:matchmaker/features/auth/presentation/pages/login_page.dart';
import 'package:matchmaker/features/auth/presentation/pages/register_page.dart';
import 'package:matchmaker/features/auth/auth_provider.dart';
import 'package:matchmaker/features/home/presentation/pages/search_page.dart';
import 'package:matchmaker/features/home/presentation/pages/websocket_test_page.dart';

final GoRouter router = GoRouter(
  initialLocation: '/login',
  
  // Gestion de la redirection selon l'état d'authentification et rôle
  redirect: (BuildContext context, GoRouterState state) {
    final authProvider = context.read<AuthProvider>();
    final isAuthRoute = ['/login', '/register'].contains(state.uri.toString());
    final isCreatePostRoute = state.uri.toString() == '/create-post';
    
    // Si l'utilisateur est connecté et essaie d'accéder aux pages d'auth
    if (authProvider.isAuthenticated && isAuthRoute) {
      return '/';
    }
    
    // Si l'utilisateur n'est pas connecté et essaie d'accéder aux pages protégées
    if (!authProvider.isAuthenticated && !isAuthRoute) {
      return '/login';
    }
    
    // Protection spéciale pour la création de post
    if (isCreatePostRoute && authProvider.isAuthenticated) {
      final user = authProvider.user;
      if (user?.isCreator != true) {
        // Rediriger vers la page principale si pas créateur
        return '/';
      }
    }
    
    // Pas de redirection nécessaire
    return null;
  },
  
  routes: [
    GoRoute(
      path: '/',
      name: 'main',
      builder: (BuildContext context, GoRouterState state) => const MainScreen(),
    ),
    GoRoute(
      path: '/login',
      name: 'login',
      builder: (BuildContext context, GoRouterState state) => const LoginPage(),
    ),
    GoRoute(
      path: '/register',
      name: 'register',
      builder: (BuildContext context, GoRouterState state) => const RegisterPage(),
    ),
    
    // Route pour la création de post (protégée pour les créateurs)
    GoRoute(
      path: '/create-post',
      name: 'createPost',
      builder: (BuildContext context, GoRouterState state) => const CreatePostPage(),
    ),
    
    // Route pour la page de recherche et découverte
    GoRoute(
      path: '/search',
      name: 'search',
      builder: (BuildContext context, GoRouterState state) => const SearchPage(),
    ),

    GoRoute(
      path: '/websocket-test',
      name: 'websocketTest',
      builder: (BuildContext context, GoRouterState state) => const WebSocketTestPage(),
    ),
  ],
);