// lib/utils/auth_storage.dart

import 'package:shared_preferences/shared_preferences.dart';
import 'constants.dart';

class AuthStorage {
  static SharedPreferences? _preferences;

  // Initialiser SharedPreferences
  static Future<void> init() async {
    _preferences ??= await SharedPreferences.getInstance();
  }

  // Sauvegarder le token d'authentification
  static Future<bool> saveToken(String token) async {
    await init();
    return await _preferences!.setString(AppConstants.tokenKey, token);
  }

  // Récupérer le token d'authentification
  static Future<String?> getToken() async {
    await init();
    return _preferences!.getString(AppConstants.tokenKey);
  }

  // Supprimer le token d'authentification
  static Future<bool> removeToken() async {
    await init();
    return await _preferences!.remove(AppConstants.tokenKey);
  }

  // Sauvegarder l'ID de l'utilisateur
  static Future<bool> saveUserId(int userId) async {
    await init();
    return await _preferences!.setInt(AppConstants.userIdKey, userId);
  }

  // Récupérer l'ID de l'utilisateur
  static Future<int?> getUserId() async {
    await init();
    return _preferences!.getInt(AppConstants.userIdKey);
  }

  // Sauvegarder le nom d'utilisateur
  static Future<bool> saveUsername(String username) async {
    await init();
    return await _preferences!.setString(AppConstants.usernameKey, username);
  }

  // Récupérer le nom d'utilisateur
  static Future<String?> getUsername() async {
    await init();
    return _preferences!.getString(AppConstants.usernameKey);
  }

  // Sauvegarder le rôle de l'utilisateur
  static Future<bool> saveUserRole(String role) async {
    await init();
    return await _preferences!.setString(AppConstants.roleKey, role);
  }

  // Récupérer le rôle de l'utilisateur
  static Future<String?> getUserRole() async {
    await init();
    return _preferences!.getString(AppConstants.roleKey);
  }

  // Sauvegarder toutes les données utilisateur en une fois
  static Future<bool> saveUserData({
    required String token,
    required int userId,
    required String username,
    required String role,
  }) async {
    await init();
    
    final results = await Future.wait([
      saveToken(token),
      saveUserId(userId),
      saveUsername(username),
      saveUserRole(role),
    ]);
    
    // Retourne true si toutes les opérations ont réussi
    return results.every((result) => result == true);
  }

  // Vérifier si l'utilisateur est connecté
  static Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  // Vérifier si l'utilisateur est un créateur
  static Future<bool> isCreator() async {
    final role = await getUserRole();
    return role == AppConstants.creatorRole;
  }

  // Vérifier si l'utilisateur est un admin
  static Future<bool> isAdmin() async {
    final role = await getUserRole();
    return role == AppConstants.adminRole;
  }

  // Effacer toutes les données utilisateur (déconnexion)
  static Future<bool> clearAllUserData() async {
    await init();
    
    final results = await Future.wait([
      removeToken(),
      _preferences!.remove(AppConstants.userIdKey),
      _preferences!.remove(AppConstants.usernameKey),
      _preferences!.remove(AppConstants.roleKey),
    ]);
    
    // Retourne true si toutes les opérations de suppression ont réussi
    return results.every((result) => result == true);
  }

  // Obtenir toutes les données utilisateur
  static Future<Map<String, dynamic>?> getUserData() async {
    final token = await getToken();
    if (token == null) return null;

    return {
      'token': token,
      'user_id': await getUserId(),
      'username': await getUsername(),
      'role': await getUserRole(),
    };
  }

  // Méthode utilitaire pour débugger
  static Future<void> printStoredData() async {
    await init();
    print('=== DONNÉES STOCKÉES ===');
    print('Token: ${await getToken()}');
    print('User ID: ${await getUserId()}');
    print('Username: ${await getUsername()}');
    print('Role: ${await getUserRole()}');
    print('Is Logged In: ${await isLoggedIn()}');
    print('========================');
  }
}