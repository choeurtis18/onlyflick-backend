import 'dart:io';
import 'dart:convert';

/// Script de test de connexion à l'API OnlyFlick en production
/// Utilisation: dart run test_connection.dart
void main() async {
  print('🚀 Test de connexion à l\'API OnlyFlick en production');
  print('=' * 60);
  
  const apiUrl = 'https://massive-period-412821.lm.r.appspot.com';
  
  // Test 1: Health check
  await testHealthCheck(apiUrl);
  
  // Test 2: Endpoints essentiels
  await testEssentialEndpoints(apiUrl);
  
  // Test 3: Test CORS
  await testCors(apiUrl);
  
  print('\n✅ Tests terminés !');
}

/// Test du health check
Future<void> testHealthCheck(String baseUrl) async {
  print('\n🔍 Test 1: Health Check');
  print('-' * 30);
  
  try {
    final client = HttpClient();
    final request = await client.getUrl(Uri.parse('$baseUrl/health'));
    request.headers.set('Accept', 'application/json');
    
    final response = await request.close();
    final responseBody = await response.transform(utf8.decoder).join();
    
    print('Status Code: ${response.statusCode}');
    print('Response: $responseBody');
    
    if (response.statusCode == 200) {
      print('✅ Health check réussi !');
    } else {
      print('❌ Health check échoué');
    }
    
    client.close();
  } catch (e) {
    print('❌ Erreur lors du health check: $e');
  }
}

/// Test des endpoints essentiels
Future<void> testEssentialEndpoints(String baseUrl) async {
  print('\n🔍 Test 2: Endpoints essentiels');
  print('-' * 30);
  
  final endpoints = [
    '/health',
    '/login',
    '/register', 
    '/posts/all',
  ];
  
  final client = HttpClient();
  
  for (final endpoint in endpoints) {
    try {
      print('\nTesting: $endpoint');
      
      final request = await client.getUrl(Uri.parse('$baseUrl$endpoint'));
      request.headers.set('Accept', 'application/json');
      request.headers.set('Content-Type', 'application/json');
      
      final response = await request.close();
      final statusCode = response.statusCode;
      
      print('  Status: $statusCode');
      
      if (statusCode == 200) {
        print('  ✅ OK');
      } else if (statusCode == 401 || statusCode == 405) {
        print('  ⚠️  Normal (auth required or method not allowed)');
      } else if (statusCode == 404) {
        print('  ❌ Endpoint non trouvé');
      } else {
        print('  ⚠️  Status inattendu: $statusCode');
      }
      
    } catch (e) {
      print('  ❌ Erreur: $e');
    }
  }
  
  client.close();
}

/// Test CORS
Future<void> testCors(String baseUrl) async {
  print('\n🔍 Test 3: Configuration CORS');
  print('-' * 30);
  
  try {
    final client = HttpClient();
    
    // Test preflight OPTIONS
    final request = await client.openUrl('OPTIONS', Uri.parse('$baseUrl/health'));
    request.headers.set('Origin', 'http://localhost:3000');
    request.headers.set('Access-Control-Request-Method', 'GET');
    request.headers.set('Access-Control-Request-Headers', 'Content-Type');
    
    final response = await request.close();
    
    print('Preflight Status: ${response.statusCode}');
    
    // Vérifier les headers CORS
    final corsOrigin = response.headers.value('access-control-allow-origin');
    final corsMethods = response.headers.value('access-control-allow-methods');
    final corsHeaders = response.headers.value('access-control-allow-headers');
    
    print('CORS Origin: $corsOrigin');
    print('CORS Methods: $corsMethods');  
    print('CORS Headers: $corsHeaders');
    
    if (corsOrigin != null) {
      print('✅ CORS configuré');
    } else {
      print('⚠️  CORS peut-être non configuré');
    }
    
    client.close();
  } catch (e) {
    print('❌ Erreur lors du test CORS: $e');
  }
}