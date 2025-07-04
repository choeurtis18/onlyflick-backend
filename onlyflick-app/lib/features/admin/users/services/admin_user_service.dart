import 'package:matchmaker/core/services/api_service.dart';
import '../models/admin_user.dart';

class AdminUserService {
  final _api = ApiService();

  Future<List<AdminUser>> fetchUsers() async {
    final response = await _api.get<List<dynamic>>(
      '/users/all',
      fromJson: (json) => json as List<dynamic>,
    );

    if (response.isSuccess && response.data != null) {
      return response.data!.map((e) => AdminUser.fromJson(e)).toList();
    }

    return [];
  }

  Future<bool> deleteUser(int id) async {
    final response = await _api.delete('/admin/users/$id');
    return response.isSuccess;
  }
}
