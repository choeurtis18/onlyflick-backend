// lib/main.dart 

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import 'package:matchmaker/app/router.dart';
import 'package:matchmaker/features/auth/auth_provider.dart';
import 'package:matchmaker/core/providers/posts_providers.dart';
import 'package:matchmaker/core/services/app_initializer.dart';
import 'package:matchmaker/core/services/api_service.dart';
import 'package:matchmaker/core/providers/app_providers_wrapper.dart';
import './core/providers/profile_provider.dart';
import 'package:matchmaker/core/providers/messaging_provider.dart';
import 'package:matchmaker/core/providers/search_provider.dart';

import 'package:matchmaker/core/config/stripe_config.dart';
import 'package:matchmaker/core/services/api_health_service.dart';
import 'package:matchmaker/core/config/app_config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  AppConfig.printDebugInfo();
  
  try {
    print('🔧 [Main] Initialisation de Stripe...');
    await StripeConfig.initialize();
    print('✅ [Main] Stripe initialisé avec succès (${StripeConfig.getCurrentEnvironment()})');
  } catch (e) {
    print('❌ [Main] Erreur d\'initialisation Stripe: $e');
    // Continue quand même l'app, Stripe sera désactivé
  }
  
  runApp(const OnlyFlickBootstrap());
}

/// Widget de bootstrap qui gère l'initialisation de l'application
class OnlyFlickBootstrap extends StatelessWidget {
  const OnlyFlickBootstrap({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _initializeApp(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _LoadingScreen();
        }
        
        if (snapshot.hasError) {
          return _ErrorScreen(error: snapshot.error.toString());
        }

        // ===== CONFIGURATION DES PROVIDERS MULTIPLES =====
        return MultiProvider(
          providers: [
            // Provider d'authentification (en premier car les autres en dépendent)
            ChangeNotifierProvider(
              create: (_) => AuthProvider()..checkAuth(),
            ),
            
            // Provider de profil (dépend d'AuthProvider)
            ChangeNotifierProxyProvider<AuthProvider, ProfileProvider>(
              create: (context) => ProfileProvider(context.read<AuthProvider>()),
              update: (context, auth, previous) => previous ?? ProfileProvider(auth),
            ),
            
            //  Provider des posts
            ChangeNotifierProvider(
              create: (_) => PostsProvider(),
            ),
            
            //  Provider de recherche et découverte
            ChangeNotifierProvider(
              create: (_) => SearchProvider(),
            ),
            
            // Provider de messagerie (pour le chat temps réel)
            ChangeNotifierProvider(
              create: (_) => MessagingProvider(),
            ),
          ],
          child: const AppProvidersWrapper(
            child: OnlyFlickApp(),
          ),
        );
      },
    );
  }

  /// Initialise l'application avec test de connexion API
  Future<void> _initializeApp() async {
    print('🚀 [Bootstrap] Initializing OnlyFlick...');
    
    print('🔍 [Bootstrap] Testing API connection...');
    final healthService = ApiHealthService();
    final healthResult = await healthService.testConnection();
    
    // Afficher le résultat du test
    healthResult.printResult();
    
    if (!healthResult.success) {
      print('❌ [Bootstrap] API connection failed - continuing anyway...');
      if (AppConfig.isProduction) {
        // En production, on peut continuer même si l'API ne répond pas temporairement
        print('⚠️ [Bootstrap] Production mode - API may be temporarily unavailable');
      }
    } else {
      print('✅ [Bootstrap] API connection successful!');
      
      print('🔍 [Bootstrap] Testing essential endpoints...');
      final endpointsResults = await healthService.testEssentialEndpoints();
      
      print('📊 [Bootstrap] Endpoints test results:');
      for (final result in endpointsResults) {
        result.printResult();
      }
    }
    
    await ApiService().initialize();
    
    if (StripeConfig.isConfigured()) {
      print(' [Bootstrap] Stripe configuré et prêt');
    } else {
      print('⚠️ [Bootstrap] Stripe non configuré - paiements désactivés');
    }
    
    // Simulation d'initialisation pour l'écran de chargement
    await Future.delayed(const Duration(milliseconds: 1500));
    
    print('[Bootstrap] OnlyFlick initialized successfully');
  }
}

class OnlyFlickApp extends StatelessWidget {
  const OnlyFlickApp({super.key});

  @override
  Widget build(BuildContext context) {
    //  ROUTER RÉACTIF AUX CHANGEMENTS D'AUTHPROVIDER
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        final routerInstance = createRouter(authProvider);
        
        router = routerInstance;
        
        return MaterialApp.router(
          title: 'OnlyFlick',
          theme: ThemeData.dark(useMaterial3: true),
          
          routerConfig: routerInstance,
          
          debugShowCheckedModeBanner: false,
        );
      },
    );
  }
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo OnlyFlick
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.camera_alt,
                  color: Colors.black,
                  size: 40,
                ),
              ),
              const SizedBox(height: 32),
              
              // Nom de l'app avec style
              const Text(
                'OnlyFlick',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              
              // Sous-titre
              const Text(
                'Créateurs de contenu exclusif',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 48),
              
              // Indicateur de chargement stylé
              const SizedBox(
                width: 40,
                height: 40,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              const SizedBox(height: 20),
              
             
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorScreen extends StatelessWidget {
  final String error;
  
  const _ErrorScreen({super.key, required this.error});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Icône d'erreur stylée
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.red.shade900,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    Icons.error_outline,
                    color: Colors.red.shade300,
                    size: 40,
                  ),
                ),
                const SizedBox(height: 32),
                
                // Titre d'erreur
                Text(
                  AppConfig.isProduction 
                    ? 'Impossible de se connecter à la production'
                    : 'Impossible de se connecter au serveur local',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                
                Text(
                  AppConfig.isProduction
                    ? 'Le serveur de production OnlyFlick semble indisponible. Veuillez réessayer dans quelques minutes.'
                    : 'Vérifiez que votre backend OnlyFlick est démarré sur le port 8080',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 16),
                
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade900,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'URL tentée:',
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        AppConfig.baseUrl,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                
                Text(
                  'Erreur: $error',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.red,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 48),
                
                // Bouton de retry stylé
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    onPressed: () {
                      // Relance l'application
                      main();
                    },
                    child: const Text(
                      'Réessayer',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                
               
               
              ],
            ),
          ),
        ),
      ),
    );
  }
}