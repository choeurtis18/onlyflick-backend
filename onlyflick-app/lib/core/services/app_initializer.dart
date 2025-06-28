import 'package:flutter/foundation.dart';
import '../config/app_config.dart';
import '../utils/logger.dart';
import 'api_service.dart';
import 'package:flutter/material.dart';

/// Service d'initialisation de l'application
class AppInitializer {
  static bool _isInitialized = false;

  /// Initialise tous les services de l'application
  static Future<void> initialize() async {
    if (_isInitialized) {
      AppLogger.warning('App already initialized');
      return;
    }

    final stopwatch = Stopwatch()..start();
    AppLogger.info('🚀 Starting app initialization...');

    try {
      // 1. Configuration du logger
      await _initializeLogger();

      // 2. Affichage des informations de configuration
      _printConfigInfo();

      // 3. Initialisation du service API
      await _initializeApiService();

      // 4. Vérification de la connectivité (optionnel)
      await _checkConnectivity();

      // 5. Autres initialisations futures...
      // await _initializeNotifications();
      // await _initializeCrashlytics();
      // await _initializeAnalytics();

      stopwatch.stop();
      _isInitialized = true;

      AppLogger.performance('App initialization', stopwatch.elapsed);
      AppLogger.info('✅ App initialization completed successfully');

    } catch (error, stackTrace) {
      stopwatch.stop();
      AppLogger.fatal(
        'Failed to initialize app',
        'AppInitializer',
        error,
        stackTrace,
      );
      rethrow;
    }
  }

  /// Initialise le système de logs
  static Future<void> _initializeLogger() async {
    AppLogger.info('Initializing logger...');
    
    // Configure le niveau de log selon l'environnement
    if (AppConfig.isProduction) {
      AppLogger.setLevel(LogLevel.warning);
    } else {
      AppLogger.setLevel(LogLevel.debug);
    }

    AppLogger.info('✅ Logger initialized');
  }

  /// Affiche les informations de configuration
  static void _printConfigInfo() {
    AppLogger.info('Printing configuration info...');
    
    if (kDebugMode) {
      AppConfig.printDebugInfo();
    }

    AppLogger.info('Environment: ${AppConfig.currentEnvironment.displayName}');
    AppLogger.info('Base URL: ${AppConfig.baseUrl}');
    AppLogger.info('WebSocket URL: ${AppConfig.wsBaseUrl}');
  }

  /// Initialise le service API
  static Future<void> _initializeApiService() async {
    AppLogger.info('Initializing API service...');
    
    try {
      await ApiService().initialize();
      AppLogger.info('✅ API service initialized');
    } catch (error, stackTrace) {
      AppLogger.error(
        'Failed to initialize API service',
        'AppInitializer',
        error,
        stackTrace,
      );
      rethrow;
    }
  }

  /// Vérifie la connectivité réseau
  static Future<void> _checkConnectivity() async {
    AppLogger.info('Checking connectivity...');
    
    try {
      // Test simple de connectivité avec le health check
      final response = await ApiService().get(AppConfig.healthCheckUrl);
      
      if (response.isSuccess) {
        AppLogger.info('✅ Server connectivity OK');
      } else {
        AppLogger.warning('⚠️ Server connectivity issue: ${response.error}');
      }
    } catch (error) {
      AppLogger.warning('⚠️ Connectivity check failed: $error');
      // Note: On ne fait pas échouer l'initialisation pour des problèmes de réseau
    }
  }

  /// Vérifie si l'application est initialisée
  static bool get isInitialized => _isInitialized;

  /// Force la réinitialisation (utile pour les tests)
  static void reset() {
    _isInitialized = false;
    AppLogger.info('App initialization reset');
  }
}

/// Widget d'initialisation pour l'interface utilisateur
class AppInitializerWidget extends StatefulWidget {
  final Widget child;
  final Widget? loadingWidget;
  final Widget? errorWidget;

  const AppInitializerWidget({
    super.key,
    required this.child,
    this.loadingWidget,
    this.errorWidget,
  });

  @override
  State<AppInitializerWidget> createState() => _AppInitializerWidgetState();
}

class _AppInitializerWidgetState extends State<AppInitializerWidget> {
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      await AppInitializer.initialize();
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = null;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = error.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return widget.loadingWidget ?? _buildDefaultLoadingWidget();
    }

    if (_error != null) {
      return widget.errorWidget ?? _buildDefaultErrorWidget();
    }

    return widget.child;
  }

  Widget _buildDefaultLoadingWidget() {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text(
                'Initialisation de OnlyFlick...',
                style: TextStyle(fontSize: 16),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDefaultErrorWidget() {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 64,
                  color: Colors.red,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Erreur d\'initialisation',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _error ?? 'Une erreur inconnue s\'est produite',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _isLoading = true;
                      _error = null;
                    });
                    _initializeApp();
                  },
                  child: const Text('Réessayer'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

