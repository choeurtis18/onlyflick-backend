import 'package:matchmaker/core/services/api_service.dart';
import '../models/report.dart';

class ReportService {
  final _api = ApiService();

  Future<List<Report>> fetchReports() async {
    final response = await _api.get<List<dynamic>>(
      '/reports',
      fromJson: (json) => json as List<dynamic>,
    );

    if (response.isSuccess && response.data != null) {
      return response.data!.map((e) => Report.fromJson(e)).toList();
    }

    return [];
  }

  Future<bool> setReportStatus(int reportId, String action) async {
    final response = await _api.post(
      '/reports/$reportId/action',
      body: {'action': action}, // "approved", "rejected", "pending"
    );
    return response.isSuccess;
  }
}
