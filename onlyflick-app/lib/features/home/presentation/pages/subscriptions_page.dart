// lib/pages/subscriptions_page.dart

import 'package:flutter/material.dart';
import '../widgets/subscription_list_widget.dart';
import ' ../../../../../../core/utils/constants.dart';
import ' ../../../../../../core/utils/auth_storage.dart';


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
    _initializeTabController();
    _loadCurrentUserData();
  }

  void _initializeTabController() {
    // Initialiser avec 2 onglets par défaut
    _tabController = TabController(length: 2, vsync: this);
    
    // Définir l'onglet initial si spécifié
    if (widget.initialTab == "following") {
      _tabController.index = 1;
    }
  }

  Future<void> _loadCurrentUserData() async {
    try {
      currentUserId = await AuthStorage.getUserId();
      currentUserRole = await AuthStorage.getUserRole();
      
      setState(() {
        isLoadingUserData = false;
      });
      
      // Réorganiser les onglets selon le rôle et si c'est le profil courant
      _updateTabsBasedOnRole();
    } catch (e) {
      setState(() {
        isLoadingUserData = false;
      });
    }
  }

  void _updateTabsBasedOnRole() {
    // Si c'est un utilisateur non-créateur regardant son propre profil,
    // on ne montre que les abonnements
    if (widget.isCurrentUser && currentUserRole != AppConstants.creatorRole) {
      _tabController.dispose();
      _tabController = TabController(length: 1, vsync: this);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
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
      ));
    }
    
    if (_showFollowingTab) {
      views.add(SubscriptionListWidget(
        userId: widget.userId,
        listType: "following",
        isCurrentUser: widget.isCurrentUser,
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

    // Si on n'a qu'un seul onglet, afficher directement le contenu
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