class CreatorRequest {
  final int id;
  final int userId;
  final String username;
  final String email;
  final String bio;
  final DateTime requestedAt;
  final String statut;

  CreatorRequest({
    required this.id,
    required this.userId,
    required this.username,
    required this.email,
    required this.bio,
    required this.requestedAt,
    required this.statut,
  });

  factory CreatorRequest.fromJson(Map<String, dynamic> json) {
    return CreatorRequest(
      id: json['id'],
      userId: json['user_id'],
      username: json['username'],
      email: json['email'],
      bio: json['bio'] ?? '',
      requestedAt: DateTime.parse(json['created_at']),
      statut: json['status'] ?? '',
    );
  }
}
