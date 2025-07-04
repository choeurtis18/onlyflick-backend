import 'package:matchmaker/core/services/api_service.dart';
import '../models/admin_stats.dart';

class AdminService {
  final _api = ApiService();

  Future<AdminStats?> fetchStats() async {
    final response = await _api.get<Map<String, dynamic>>(
      '/admin/dashboard',
      fromJson: (json) => json,
    );

    if (response.isSuccess && response.data != null) {
      return AdminStats.fromJson(response.data!);
    }

    return null;
  }
}
