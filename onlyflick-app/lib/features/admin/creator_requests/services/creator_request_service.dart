import 'package:matchmaker/core/services/api_service.dart';
import '../models/creator_request.dart';

class CreatorRequestService {
  final _api = ApiService();

  Future<List<CreatorRequest>> fetchRequests() async {
    final response = await _api.get<List<dynamic>>(
      '/admin/creator-requests',
    );

    if (response.isSuccess && response.data != null) {
      return response.data!.map((e) => CreatorRequest.fromJson(e)).toList();
    }

    return [];
  }

  Future<bool> approve(int requestId) async {
    final response = await _api.post('/admin/creator-requests/$requestId/approve');
    return response.isSuccess;
  }

  Future<bool> reject(int requestId) async {
    final response = await _api.post('/admin/creator-requests/$requestId/reject');
    return response.isSuccess;
  }
}
