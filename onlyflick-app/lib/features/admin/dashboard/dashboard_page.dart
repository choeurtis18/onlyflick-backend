import 'package:flutter/material.dart';
import 'services/admin_service.dart';
import 'models/admin_stats.dart';
import '../widgets/admin_scaffold.dart';

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  AdminStats? stats;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final data = await AdminService().fetchStats();
    setState(() {
      stats = data;
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AdminScaffold(
      title: 'Dashboard Admin',
      child: isLoading
          ? const Center(child: CircularProgressIndicator())
          : stats == null
              ? const Center(child: Text('Erreur de chargement des stats'))
              : Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: GridView.count(
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    children: [
                      _buildStatCard('Utilisateurs', stats!.totalUsers),
                      _buildStatCard('Revenues', stats!.totalRevenue),
                      _buildStatCard('Posts', stats!.totalPosts),
                      _buildStatCard('Signalements', stats!.totalReports),
                    ],
                  ),
                ),
    );
  }

  Widget _buildStatCard(String label, int value) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(label, style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 8),
            Text(
              value.toString(),
              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}
