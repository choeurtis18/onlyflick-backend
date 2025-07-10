// lib/app/router.dart - 

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
import 'package:matchmaker/features/admin/dashboard/dashboard_page.dart';
import 'package:matchmaker/features/admin/users/users_page.dart';
import 'package:matchmaker/features/admin/creators/creators_page.dart';
import 'package:matchmaker/features/admin/creator_requests/creator_requests_page.dart';
import 'package:matchmaker/features/admin/reports/reports_page.dart';

///  FONCTION POUR CRÉER LE ROUTER AVEC AUTHPROVIDER
GoRouter createRouter(AuthProvider authProvider) {
  return GoRouter(
    initialLocation: '/login',
    
    // Écouter les changements d'AuthProvider
    refreshListenable: authProvider,
    
    // Gestion de la redirection selon l'état d'authentification et rôle
    redirect: (BuildContext context, GoRouterState state) {
      final isAuthenticated = authProvider.isAuthenticated;
      final user = authProvider.user;
      final currentPath = state.uri.toString();
      
      debugPrint('🔄 [Router] Redirect check - Path: $currentPath, Auth: $isAuthenticated');
      
      // Routes d'authentification
      final isAuthRoute = ['/login', '/register'].contains(currentPath);
      
      // Routes protégées qui nécessitent une authentification
      final isProtectedRoute = !isAuthRoute;
      
      // Routes spéciales
      final isCreatePostRoute = currentPath == '/create-post';
      final isAdminRoute = currentPath.startsWith('/admin');
      
      //  Si l'utilisateur N'EST PAS connecté
      if (!isAuthenticated) {
        if (isProtectedRoute) {
          debugPrint('🔄 [Router] User not authenticated, redirecting to login');
          return '/login';
        }
        // Si déjà sur une route d'auth, pas de redirection
        return null;
      }
      
      // Si l'utilisateur EST connecté
      if (isAuthenticated) {
        // Si sur une route d'auth, rediriger vers l'accueil
        if (isAuthRoute) {
          debugPrint('🔄 [Router] User authenticated, redirecting to main');
          return '/';
        }
        
        //  Protection spéciale pour la création de post (créateurs seulement)
        if (isCreatePostRoute && user?.isCreator != true) {
          debugPrint('[Router] Non-creator trying to access create post, redirecting to main');
          return '/';
        }
        
        // 👨‍💼 Protection spéciale pour l'admin (admins seulement)
        if (isAdminRoute && user?.role != 'admin') {
          debugPrint('[Router] Non-admin trying to access admin routes, redirecting to main');
          return '/';
        }
      }
      
      // Pas de redirection nécessaire
      return null;
    },
    
    routes: [
      //  Route principale
      GoRoute(
        path: '/',
        name: 'main',
        builder: (BuildContext context, GoRouterState state) => const MainScreen(),
      ),
      
      //  Routes d'authentification
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
      
      //  Route pour la page de recherche et découverte
      GoRoute(
        path: '/search',
        name: 'search',
        builder: (BuildContext context, GoRouterState state) => const SearchPage(),
      ),

      // Route de test WebSocket
      GoRoute(
        path: '/websocket-test',
        name: 'websocketTest',
        builder: (BuildContext context, GoRouterState state) => const WebSocketTestPage(),
      ),

      // Routes d'administration
      GoRoute(
        path: '/admin',
        name: 'adminDashboard',
        builder: (context, state) => const AdminDashboardPage(),
      ),
      GoRoute(
        path: '/admin/users',
        name: 'adminUsers',
        builder: (context, state) => const UsersPage(),
      ),
      GoRoute(
        path: '/admin/creators',
        name: 'adminCreators',
        builder: (context, state) => const CreatorsPage(),
      ),
      GoRoute(
        path: '/admin/creator-requests',
        name: 'adminCreatorRequests',
        builder: (context, state) => const CreatorRequestsPage(),
      ),
      GoRoute(
        path: '/admin/reports',
        name: 'adminReports',
        builder: (context, state) => const ReportsPage(),
      ),
    ],
  );
}

late GoRouter router;