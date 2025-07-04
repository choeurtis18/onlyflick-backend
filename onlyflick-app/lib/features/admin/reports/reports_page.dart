import 'package:flutter/material.dart';
import './models/report.dart';
import './services/report_service.dart';
import '../widgets/admin_scaffold.dart';

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  List<Report> reports = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  Future<void> _loadReports() async {
    reports = await ReportService().fetchReports();
    setState(() => isLoading = false);
  }

  Future<void> _handleAction(Report report, String action) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(
          action == 'approved'
              ? 'Marquer comme contenu inapproprié ?'
              : 'Ignorer ce signalement ?',
        ),
        content: Text(
          '${report.contentType == "post" ? "Post" : "Commentaire"} ID: ${report.contentId}',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Confirmer')),
        ],
      ),
    );

    if (confirm != true) return;

    final updated = await ReportService().setReportStatus(report.id, action);
    if (updated) {
      setState(() => reports.remove(report));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erreur traitement du signalement')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdminScaffold(
      title: 'Signalements',
      child: isLoading
          ? const Center(child: CircularProgressIndicator())
          : reports.isEmpty
              ? const Center(child: Text('Aucun signalement à traiter'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: reports.length,
                  itemBuilder: (context, index) {
                    final r = reports[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: r.imageUrl != null
                            ? Image.network(r.imageUrl!, width: 48, height: 48, fit: BoxFit.cover)
                            : const Icon(Icons.comment, size: 32),
                        title: Text(
                          r.text,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          '${r.contentType == "post" ? "Post" : "Commentaire"} signalé par ${r.reporterUsername}\nMotif : ${r.reason}\nStatut : ${r.status}\nCréé le : ${r.createdAt.toLocal().toIso8601String()}',
                        ),
                        isThreeLine: true,
                        trailing: Wrap(
                          spacing: 8,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.flag, color: Colors.red),
                              tooltip: 'Approuver le signalement',
                              onPressed: () => _handleAction(r, 'approved'),
                            ),
                            IconButton(
                              icon: const Icon(Icons.cancel_outlined),
                              tooltip: 'Ignorer',
                              onPressed: () => _handleAction(r, 'rejected'),
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
