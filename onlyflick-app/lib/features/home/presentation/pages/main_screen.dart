//lib/features/home/presentation/pages/main_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'feed_screen.dart';
import 'search_page.dart';
import 'profile_screen.dart'; 
import '../../../auth/auth_provider.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
  }

  /// Navigation vers la page de création de post avec GoRouter
  void _navigateToCreatePost() {
    context.pushNamed('createPost').then((result) {
      // Si un post a été créé avec succès, actualiser le feed
      if (result == true && _selectedIndex == 0) {
        _showSuccessMessage();
        // TODO: Refresh du feed si nécessaire
      }
    });
  }

  /// Affiche un message de succès après création d'un post
  void _showSuccessMessage() {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text('Post créé avec succès !'),
            ],
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.all(16),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        final user = authProvider.user;
        final isCreator = user?.isCreator == true;
        
        // Construire les écrans dynamiquement selon le rôle
        final screens = [
          FeedScreen(isCreator: isCreator, onCreatePost: _navigateToCreatePost), // ← Passer la fonction
          const SearchPage(),
          ProfileScreen(isCreator: isCreator),
        ];
        
        return Scaffold(
          backgroundColor: Colors.white,
          body: Stack(
            children: [
              IndexedStack(
                index: _selectedIndex,
                children: screens,
              ),

              // ✅ Bouton admin flottant en haut à droite - visible seulement pour les administrateurs
              if (authProvider.isAdmin) // ← Condition ajoutée ici
                Positioned(
                  top: 40,
                  right: 16,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      context.go('/admin');
                    },
                    icon: const Icon(Icons.admin_panel_settings),
                    label: const Text('Admin'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          bottomNavigationBar: _buildCompactBottomNavigationBar(),
        );

      },
    );
  }

  /// Barre de navigation inférieure compacte sans overflow
  Widget _buildCompactBottomNavigationBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            offset: const Offset(0, -2),
            blurRadius: 12,
          ),
        ],
      ),
      child: SafeArea(
        child: Container(
          height: 50, // ← Hauteur très compacte
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildCompactNavIcon(Icons.home_rounded, 'Accueil', 0),
              _buildCompactNavIcon(Icons.search_rounded, 'Recherche', 1),
              _buildCompactProfileIcon(2),
            ],
          ),
        ),
      ),
    );
  }

  /// Item de navigation compact sans overflow
  Widget _buildCompactNavIcon(IconData icon, String label, int index) {
    final isSelected = _selectedIndex == index;
    
    return Expanded(
      child: GestureDetector(
        onTap: () => _onItemTapped(index),
        behavior: HitTestBehavior.opaque,
        child: Container(
          height: 50,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: isSelected ? Colors.black : Colors.grey[500],
                size: 22,
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 9,
                  color: isSelected ? Colors.black : Colors.grey[500],
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Item de navigation compact pour le profil
  Widget _buildCompactProfileIcon(int index) {
    final isSelected = _selectedIndex == index;
    
    return Expanded(
      child: Consumer<AuthProvider>(
        builder: (context, authProvider, child) {
          final user = authProvider.user;
          
          return GestureDetector(
            onTap: () => _onItemTapped(index),
            behavior: HitTestBehavior.opaque,
            child: Container(
              height: 50,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: isSelected 
                          ? Border.all(color: Colors.black, width: 1.5)
                          : null,
                    ),
                    child: CircleAvatar(
                      radius: 10,
                      backgroundColor: Colors.grey[300],
                      backgroundImage: user != null && user.avatarUrl.isNotEmpty
                          ? NetworkImage(user.avatarUrl)
                          : null,
                      child: user == null || user.avatarUrl.isEmpty
                          ? Icon(Icons.person, color: Colors.grey[600], size: 12)
                          : null,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Profil',
                    style: TextStyle(
                      fontSize: 9,
                      color: isSelected ? Colors.black : Colors.grey[500],
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}