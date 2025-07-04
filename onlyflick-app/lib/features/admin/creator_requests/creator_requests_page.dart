import 'package:flutter/material.dart';
import './models/creator_request.dart';
import './services/creator_request_service.dart';
import '../widgets/admin_scaffold.dart';

class CreatorRequestsPage extends StatefulWidget {
  const CreatorRequestsPage({super.key});

  @override
  State<CreatorRequestsPage> createState() => _CreatorRequestsPageState();
}

class _CreatorRequestsPageState extends State<CreatorRequestsPage> {
  List<CreatorRequest> requests = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  Future<void> _loadRequests() async {
    requests = await CreatorRequestService().fetchRequests();
    setState(() => isLoading = false);
  }

  Future<void> _handleAction(CreatorRequest request, bool approve) async {
    final success = approve
        ? await CreatorRequestService().approve(request.id)
        : await CreatorRequestService().reject(request.id);

    if (success) {
      setState(() => requests.remove(request));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Action échouée')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdminScaffold(
      title: 'Demandes de créateurs',
      child: isLoading
          ? const Center(child: CircularProgressIndicator())
          : requests.isEmpty
              ? const Center(child: Text('Aucune demande pour le moment'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: requests.length,
                  itemBuilder: (context, index) {
                    final req = requests[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        title: Text(req.username),
                        subtitle: Text('${req.email}\n${req.bio}\nStatut: ${req.statut}'),
                        isThreeLine: true,
                        trailing: req.statut == 'approved'
                            ? null
                            : Wrap(
                                spacing: 8,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.check, color: Colors.green),
                                    tooltip: 'Approuver',
                                    onPressed: () => _handleAction(req, true),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.close, color: Colors.red),
                                    tooltip: 'Rejeter',
                                    onPressed: () => _handleAction(req, false),
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
