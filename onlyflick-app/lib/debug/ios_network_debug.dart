import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';

class IOSNetworkDebugPage extends StatefulWidget {
  @override
  _IOSNetworkDebugPageState createState() => _IOSNetworkDebugPageState();
}

class _IOSNetworkDebugPageState extends State<IOSNetworkDebugPage> {
  String _debugLog = '';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _runDiagnostics();
  }

  Future<void> _runDiagnostics() async {
    setState(() {
      _isLoading = true;
      _debugLog = '';
    });

    final log = StringBuffer();
    
    log.writeln('🔍 DIAGNOSTIC RÉSEAU iOS OnlyFlick');
    log.writeln('=' * 50);
    log.writeln('Date: ${DateTime.now()}');
    log.writeln('Platform: ${Platform.operatingSystem}');
    log.writeln('Debug Mode: $kDebugMode');
    log.writeln('');

    // Test 1: Configuration de base
    log.writeln('📱 CONFIGURATION PLATEFORME');
    log.writeln('-' * 30);
    log.writeln('Platform: ${defaultTargetPlatform.name}');
    log.writeln('iOS Version: ${Platform.operatingSystemVersion}');
    log.writeln('');

    // Test 2: Test de l'URL API
    const apiUrl = 'https://massive-period-412821.lm.r.appspot.com';
    log.writeln('🌐 CONFIGURATION API');
    log.writeln('-' * 30);
    log.writeln('URL de base: $apiUrl');
    log.writeln('');

    // Test 3: Test de connectivité basique
    log.writeln('🔌 TESTS DE CONNECTIVITÉ');
    log.writeln('-' * 30);

    // Test 3.1: Test Google (pour vérifier la connectivité internet)
    try {
      log.writeln('Test 1: Connectivité internet (google.com)...');
      final googleResponse = await http.get(
        Uri.parse('https://www.google.com'),
      ).timeout(Duration(seconds: 5));
      log.writeln('✅ Google accessible - Status: ${googleResponse.statusCode}');
    } catch (e) {
      log.writeln('❌ Problème connectivité internet: $e');
    }

    // Test 3.2: Test de l'API health check
    try {
      log.writeln('\nTest 2: Health check API OnlyFlick...');
      final healthResponse = await http.get(
        Uri.parse('$apiUrl/health'),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'User-Agent': 'OnlyFlick-iOS-Debug/1.0',
        },
      ).timeout(Duration(seconds: 10));
      
      log.writeln('✅ Health check réussi !');
      log.writeln('Status: ${healthResponse.statusCode}');
      log.writeln('Headers: ${healthResponse.headers}');
      log.writeln('Body: ${healthResponse.body}');
      
    } catch (e) {
      log.writeln('❌ Health check échoué: $e');
      
      // Analyser le type d'erreur
      if (e.toString().contains('HandshakeException')) {
        log.writeln('🔍 Type: Erreur SSL/TLS');
        log.writeln('💡 Solution: Vérifier les certificats ou Info.plist');
      } else if (e.toString().contains('SocketException')) {
        log.writeln('🔍 Type: Erreur de connexion réseau');
        log.writeln('💡 Solution: Vérifier la connectivité ou les paramètres ATS');
      } else if (e.toString().contains('TimeoutException')) {
        log.writeln('🔍 Type: Timeout');
        log.writeln('💡 Solution: Serveur lent ou inaccessible');
      } else if (e.toString().contains('Certificate')) {
        log.writeln('🔍 Type: Problème de certificat');
        log.writeln('💡 Solution: Vérifier NSAppTransportSecurity');
      }
    }

    // Test 3.3: Tests d'endpoints spécifiques
    final endpoints = ['/login', '/register', '/posts/all'];
    
    for (final endpoint in endpoints) {
      try {
        log.writeln('\nTest: $endpoint...');
        final response = await http.get(
          Uri.parse('$apiUrl$endpoint'),
          headers: {
            'Accept': 'application/json',
            'Content-Type': 'application/json',
          },
        ).timeout(Duration(seconds: 5));
        
        log.writeln('Status: ${response.statusCode}');
        if (response.statusCode >= 200 && response.statusCode < 500) {
          log.writeln('✅ Endpoint accessible');
        }
        
      } catch (e) {
        log.writeln('❌ Erreur: ${e.toString().substring(0, 100)}...');
      }
    }

    // Test 4: Test avec différentes configurations de headers
    log.writeln('\n🔧 TESTS DE CONFIGURATION');
    log.writeln('-' * 30);

    try {
      log.writeln('Test avec headers iOS spécifiques...');
      final response = await http.get(
        Uri.parse('$apiUrl/health'),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'User-Agent': 'OnlyFlick iOS/1.0.0 (iPhone; iOS ${Platform.operatingSystemVersion})',
          'X-Requested-With': 'OnlyFlickApp',
        },
      ).timeout(Duration(seconds: 10));
      
      log.writeln('✅ Headers iOS - Status: ${response.statusCode}');
      
    } catch (e) {
      log.writeln('❌ Headers iOS échoué: $e');
    }

    // Test 5: Configuration recommandée pour Info.plist
    log.writeln('\n📋 VÉRIFICATIONS CONFIGURATION');
    log.writeln('-' * 30);
    log.writeln('✓ Vérifiez que Info.plist contient :');
    log.writeln('  - NSAppTransportSecurity');
    log.writeln('  - NSAllowsArbitraryLoads = true (temporaire)');
    log.writeln('  - Domaine massive-period-412821.lm.r.appspot.com');
    log.writeln('');
    log.writeln('✓ Si le problème persiste :');
    log.writeln('  1. Redémarrez complètement l\'iPhone');
    log.writeln('  2. Vérifiez les paramètres réseau iPhone');
    log.writeln('  3. Testez sur WiFi ET données mobiles');
    log.writeln('  4. Vérifiez les restrictions d\'entreprise');

    setState(() {
      _debugLog = log.toString();
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Debug Réseau iOS'),
        backgroundColor: Colors.red,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _runDiagnostics,
          ),
        ],
      ),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            if (_isLoading)
              Center(
                child: Column(
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Diagnostic en cours...'),
                  ],
                ),
              ),
              
            SizedBox(height: 16),
            
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _runDiagnostics,
                    child: Text('Relancer diagnostic'),
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      // Test direct de l'URL dans Safari
                      // Note: Vous devrez implémenter url_launcher pour cela
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Testez dans Safari: https://massive-period-412821.lm.r.appspot.com/health'),
                          duration: Duration(seconds: 5),
                        ),
                      );
                    },
                    child: Text('Test Safari'),
                  ),
                ),
              ],
            ),
            
            SizedBox(height: 16),
            
            Expanded(
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SingleChildScrollView(
                  child: Text(
                    _debugLog,
                    style: TextStyle(
                      color: Colors.green,
                      fontFamily: 'monospace',
                      fontSize: 11,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Widget à ajouter temporairement dans votre app pour accéder au debug
class DebugFloatingButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    if (!kDebugMode) return SizedBox.shrink();
    
    return Positioned(
      bottom: 80,
      right: 20,
      child: FloatingActionButton(
        heroTag: 'debug_network',
        backgroundColor: Colors.red,
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => IOSNetworkDebugPage()),
          );
        },
        child: Icon(Icons.network_check, color: Colors.white),
      ),
    );
  }
}