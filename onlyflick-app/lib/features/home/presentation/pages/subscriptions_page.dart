// lib/features/home/presentation/pages/subscriptions_page.dart

import 'package:flutter/material.dart';
import '../widgets/subscription_list_widget.dart';
import '../../../../core/utils/constants.dart';
import '../../../../core/utils/auth_storage.dart';

class SubscriptionsPage extends StatefulWidget {
  final int userId;
  final String? initialTab; // "followers" ou "following"
  final bool isCurrentUser;

  const SubscriptionsPage({
    Key? key,
    required this.userId,
    this.initialTab,
    this.isCurrentUser = false,
  }) : super(key: key);

  @override
  State<SubscriptionsPage> createState() => _SubscriptionsPageState();
}

class _SubscriptionsPageState extends State<SubscriptionsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int? currentUserId;
  String? currentUserRole;
  bool isLoadingUserData = true;

  @override
  void initState() {
    super.initState();
    _loadCurrentUserData();
  }

  void _initializeTabController() {
    // Calculer le nombre d'onglets nécessaires
    int tabCount = 0;
    if (_showFollowersTab) tabCount++;
    if (_showFollowingTab) tabCount++;
    
    _tabController = TabController(length: tabCount, vsync: this);
    
    // Définir l'onglet initial si spécifié
    if (widget.initialTab == "following") {
      // Si on veut l'onglet "following" mais qu'on n'a que l'onglet "followers"
      if (_showFollowersTab && !_showFollowingTab) {
        _tabController.index = 0;
      } else if (_showFollowersTab && _showFollowingTab) {
        _tabController.index = 1; // "following" est le second onglet
      } else if (!_showFollowersTab && _showFollowingTab) {
        _tabController.index = 0; // "following" est le seul onglet
      }
    }
  }

  Future<void> _loadCurrentUserData() async {
    try {
      currentUserId = await AuthStorage.getUserId();
      currentUserRole = await AuthStorage.getUserRole();
      
      setState(() {
        isLoadingUserData = false;
      });
      
      // Initialiser le TabController après avoir chargé les données
      _initializeTabController();
    } catch (e) {
      setState(() {
        isLoadingUserData = false;
      });
      // Initialiser avec des valeurs par défaut
      _initializeTabController();
    }
  }

  @override
  void dispose() {
    if (mounted) {
      _tabController.dispose();
    }
    super.dispose();
  }

  bool get _showFollowersTab {
    // Afficher l'onglet abonnés si :
    // - C'est un créateur
    // - OU ce n'est pas le profil de l'utilisateur connecté (pour voir les abonnés des autres)
    return currentUserRole == AppConstants.creatorRole || !widget.isCurrentUser;
  }

  bool get _showFollowingTab {
    // Toujours afficher l'onglet abonnements
    return true;
  }

  List<Tab> _buildTabs() {
    List<Tab> tabs = [];
    
    if (_showFollowersTab) {
      tabs.add(const Tab(
        icon: Icon(Icons.people),
        text: 'Abonnés',
      ));
    }
    
    if (_showFollowingTab) {
      tabs.add(const Tab(
        icon: Icon(Icons.person_add),
        text: 'Abonnements',
      ));
    }
    
    return tabs;
  }

  List<Widget> _buildTabViews() {
    List<Widget> views = [];
    
    if (_showFollowersTab) {
      views.add(SubscriptionListWidget(
        userId: widget.userId,
        listType: "followers",
        isCurrentUser: widget.isCurrentUser,
        showHeader: false, // Ne pas afficher le header interne
      ));
    }
    
    if (_showFollowingTab) {
      views.add(SubscriptionListWidget(
        userId: widget.userId,
        listType: "following",
        isCurrentUser: widget.isCurrentUser,
        showHeader: false, // Ne pas afficher le header interne
      ));
    }
    
    return views;
  }

  @override
  Widget build(BuildContext context) {
    if (isLoadingUserData) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Abonnements'),
          backgroundColor: const Color(AppColors.primaryColor),
          foregroundColor: Colors.white,
        ),
        body: const Center(
          child: CircularProgressIndicator(
            color: Color(AppColors.primaryColor),
          ),
        ),
      );
    }

    final tabs = _buildTabs();
    final tabViews = _buildTabViews();

    // Si on n'a qu'un seul onglet, afficher directement le contenu sans TabBar
    if (tabs.length == 1) {
      return Scaffold(
        appBar: AppBar(
          title: Text(tabs.first.text!),
          backgroundColor: const Color(AppColors.primaryColor),
          foregroundColor: Colors.white,
        ),
        body: tabViews.first,
      );
    }

    // Si on a plusieurs onglets, utiliser TabBar
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isCurrentUser ? 'Mes abonnements' : 'Abonnements'),
        backgroundColor: const Color(AppColors.primaryColor),
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          tabs: tabs,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: tabViews,
      ),
    );
  }
}

// Widget helper pour naviguer vers la page des abonnements
class SubscriptionsNavigator {
  static void navigateToFollowers(BuildContext context, int userId, {bool isCurrentUser = false}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SubscriptionsPage(
          userId: userId,
          initialTab: "followers",
          isCurrentUser: isCurrentUser,
        ),
      ),
    );
  }

  static void navigateToFollowing(BuildContext context, int userId, {bool isCurrentUser = false}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SubscriptionsPage(
          userId: userId,
          initialTab: "following",
          isCurrentUser: isCurrentUser,
        ),
      ),
    );
  }

  static void navigateToSubscriptions(BuildContext context, int userId, {bool isCurrentUser = false}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SubscriptionsPage(
          userId: userId,
          isCurrentUser: isCurrentUser,
        ),
      ),
    );
  }
}