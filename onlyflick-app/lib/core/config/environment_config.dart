import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Configuration des environnements pour le développement
enum Environment {
  development,
  staging,
  production,
}

class EnvironmentConfig {
  static Environment _currentEnvironment = kDebugMode 
      ? Environment.development 
      : Environment.production;

  /// Forcer un environnement spécifique (utile pour les tests)
  static void setEnvironment(Environment env) {
    _currentEnvironment = env;
  }

  /// Environnement actuel
  static Environment get current => _currentEnvironment;

  /// Configuration API selon l'environnement
  static String get apiBaseUrl {
    switch (_currentEnvironment) {
      case Environment.development:
        if (defaultTargetPlatform == TargetPlatform.android) {
          return 'http://10.0.2.2:8080'; // Android emulator
        } else if (defaultTargetPlatform == TargetPlatform.iOS) {
          return 'http://localhost:8080'; // iOS simulator
        } else {
          return 'http://localhost:8080'; // Desktop/Web
        }
        
      case Environment.staging:
        return 'https://staging-api.onlyflick.com';
        
      case Environment.production:
        return 'https://massive-period-412821.lm.r.appspot.com';
    }
  }

  static String get wsBaseUrl {
    switch (_currentEnvironment) {
      case Environment.development:
        return defaultTargetPlatform == TargetPlatform.android
            ? 'ws://10.0.2.2:8080/ws'
            : 'ws://localhost:8080/ws';
      case Environment.staging:
        return 'wss://staging-api.onlyflick.com/ws';
      case Environment.production:
        return 'wss://massive-period-412821.lm.r.appspot.com/ws';
    }
  }

  /// Configuration de debug selon l'environnement
  static bool get enableLogs {
    return _currentEnvironment != Environment.production;
  }

  /// Informations d'environnement pour le debug
  static Map<String, dynamic> get debugInfo => {
    'environment': _currentEnvironment.toString().split('.').last,
    'apiUrl': apiBaseUrl,
    'wsUrl': wsBaseUrl,
    'enableLogs': enableLogs,
    'platform': defaultTargetPlatform.name,
    'debugMode': kDebugMode,
    'releaseMode': kReleaseMode,
  };

  /// Widget de debug pour afficher l'environnement
  static void printEnvironmentInfo() {
    if (enableLogs) {
      print('🌍 Environment: ${_currentEnvironment.toString().split('.').last}');
      print('🔗 API: $apiBaseUrl');
      print('🔌 WebSocket: $wsBaseUrl');
      print('📱 Platform: ${defaultTargetPlatform.name}');
    }
  }
}

/// Widget pour basculer d'environnement en mode debug

class EnvironmentSwitcher extends StatefulWidget {
  final Widget child;

  const EnvironmentSwitcher({super.key, required this.child});

  @override
  State<EnvironmentSwitcher> createState() => _EnvironmentSwitcherState();
}

class _EnvironmentSwitcherState extends State<EnvironmentSwitcher> {
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        
        // Affichage de l'environnement en mode debug
        if (kDebugMode)
          Positioned(
            top: 50,
            right: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _getEnvironmentColor(),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white, width: 1),
              ),
              child: Text(
                EnvironmentConfig.current.toString().split('.').last.toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          
        // Bouton pour basculer d'environnement (debug uniquement)
        if (kDebugMode)
          Positioned(
            bottom: 100,
            right: 20,
            child: FloatingActionButton.small(
              heroTag: 'env_switcher',
              onPressed: _showEnvironmentDialog,
              backgroundColor: _getEnvironmentColor(),
              child: const Icon(Icons.settings, color: Colors.white),
            ),
          ),
      ],
    );
  }

  Color _getEnvironmentColor() {
    switch (EnvironmentConfig.current) {
      case Environment.development:
        return Colors.green;
      case Environment.staging:
        return Colors.orange;
      case Environment.production:
        return Colors.red;
    }
  }

  void _showEnvironmentDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Changer d\'environnement'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: Environment.values.map((env) {
            final isSelected = env == EnvironmentConfig.current;
            return ListTile(
              title: Text(env.toString().split('.').last),
              subtitle: Text(_getEnvironmentUrl(env)),
              leading: Radio<Environment>(
                value: env,
                groupValue: EnvironmentConfig.current,
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      EnvironmentConfig.setEnvironment(value);
                    });
                    Navigator.pop(context);
                    
                    // Redémarrer l'app pour appliquer les changements
                    _showRestartDialog();
                  }
                },
              ),
              tileColor: isSelected ? Colors.blue.withOpacity(0.1) : null,
            );
          }).toList(),
        ),
      ),
    );
  }

  String _getEnvironmentUrl(Environment env) {
    switch (env) {
      case Environment.development:
        return 'http://localhost:8080';
      case Environment.staging:
        return 'staging-api.onlyflick.com';
      case Environment.production:
        return 'massive-period-412821.lm.r.appspot.com';
    }
  }

  void _showRestartDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Redémarrage requis'),
        content: const Text('L\'app doit être redémarrée pour appliquer le nouvel environnement.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}