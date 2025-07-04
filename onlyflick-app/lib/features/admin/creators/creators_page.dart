import 'package:flutter/material.dart';
import '../creators/models/admin_creator.dart';
import '../creators/services/admin_creator_service.dart';
import '../widgets/admin_scaffold.dart';
import 'package:go_router/go_router.dart';

class CreatorsPage extends StatefulWidget {
  const CreatorsPage({super.key});

  @override
  State<CreatorsPage> createState() => _CreatorsPageState();
}

class _CreatorsPageState extends State<CreatorsPage> {
  List<AdminCreator> creators = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCreators();
  }

  Future<void> _loadCreators() async {
    creators = await AdminCreatorService().fetchCreators();
    setState(() => isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return AdminScaffold(
      title: 'Créateurs',
      child: isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: creators.length,
              itemBuilder: (context, index) {
                final creator = creators[index];
                return Card(
                  child: ListTile(
                    title: Text(creator.username),
                    trailing: Wrap(
                      spacing: 8,
                      children: [
                        Text('${creator.totalPosts} posts'),
                        Text('${creator.followers} abonnés'),
                        Text('${creator.totalLikes} likes'),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
