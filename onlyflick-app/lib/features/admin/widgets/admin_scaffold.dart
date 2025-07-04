import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AdminScaffold extends StatelessWidget {
  final String title;
  final Widget child;

  const AdminScaffold({
    super.key,
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // ===== NAVBAR LATÉRALE FIXE =====
          NavigationRail(
            selectedIndex: _getSelectedIndex(context),
            onDestinationSelected: (int index) {
              switch (index) {
                case 0:
                  context.go('/admin');
                  break;
                case 1:
                  context.go('/admin/users');
                  break;
                case 2:
                  context.go('/admin/creators');
                  break;
                case 3:
                  context.go('/admin/creator-requests');
                  break;
                case 4:
                  context.go('/admin/reports');
                  break;
              }
            },
            labelType: NavigationRailLabelType.all,
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.dashboard),
                label: Text('Dashboard'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.people),
                label: Text('Utilisateurs'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.star),
                label: Text('Créateurs'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.assignment_ind),
                label: Text('Demandes'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.report),
                label: Text('Signalements'),
              ),
            ],
          ),

          // ===== CONTENU PRINCIPAL =====
          Expanded(
            child: Scaffold(
              appBar: AppBar(
                title: Text(title),
                actions: [
                  TextButton.icon(
                    onPressed: () {
                      // À personnaliser avec AuthProvider
                      context.go('/');
                    },
                    icon: const Icon(Icons.logout, color: Colors.white),
                    label: const Text('Quitter', style: TextStyle(color: Colors.white)),
                  )
                ],
              ),
              body: child,
            ),
          ),
        ],
      ),
    );
  }

  int _getSelectedIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();

    if (location.startsWith('/admin/users')) return 1;
    if (location.startsWith('/admin/creators')) return 2;
    if (location.startsWith('/admin/creator-requests')) return 3;
    if (location.startsWith('/admin/reports')) return 4;

    return 0;
  }
}
