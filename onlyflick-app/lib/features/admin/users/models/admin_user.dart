class AdminUser {
  final int id;
  final String username;
  final String email;
  final String role;

  AdminUser({
    required this.id,
    required this.username,
    required this.email,
    required this.role,
  });

  factory AdminUser.fromJson(Map<String, dynamic> json) {
    return AdminUser(
      id: json['id'],
      username: json['username'] ?? '',
      email: json['email'] ?? '',
      role: json['role'] ?? 'user',
    );
  }
}
