import 'package:matchmaker/core/services/api_service.dart';
import '../models/admin_creator.dart';

class AdminCreatorService {
  final _api = ApiService();

  Future<List<AdminCreator>> fetchCreators() async {
    final response = await _api.get<List<dynamic>>(
      '/admin/creators',
      fromJson: (json) => json as List<dynamic>,
    );

    if (response.isSuccess && response.data != null) {
      return response.data!.map((e) => AdminCreator.fromJson(e)).toList();
    }

    return [];
  }
}
