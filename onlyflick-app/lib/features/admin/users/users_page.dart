import 'package:flutter/material.dart';
import 'models/admin_user.dart';
import 'services/admin_user_service.dart';
import '../widgets/admin_scaffold.dart';

class UsersPage extends StatefulWidget {
  const UsersPage({super.key});

  @override
  State<UsersPage> createState() => _UsersPageState();
}

class _UsersPageState extends State<UsersPage> {
  List<AdminUser> users = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    users = await AdminUserService().fetchUsers();
    setState(() => isLoading = false);
  }

  Future<void> _deleteUser(AdminUser user) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Supprimer cet utilisateur ?'),
        content: Text('ID: ${user.id}\nUsername: ${user.username}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Supprimer')),
        ],
      ),
    );

    if (confirm == true) {
      final success = await AdminUserService().deleteUser(user.id);
      if (success) {
        setState(() => users.remove(user));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Échec de la suppression')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdminScaffold(
      title: 'Utilisateurs',
      child: isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.separated(
              itemCount: users.length,
              padding: const EdgeInsets.all(16),
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, index) {
                final user = users[index];
                return ListTile(
                  title: Text(user.username),
                  subtitle: Text('${user.email} (${user.role})'),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _deleteUser(user),
                  ),
                );
              },
            ),
    );
  }
}
