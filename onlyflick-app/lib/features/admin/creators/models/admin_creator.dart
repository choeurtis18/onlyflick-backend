class AdminCreator {
  final int id;
  final String username;
  final int totalPosts;
  final int followers;
  final int totalLikes;

  AdminCreator({
    required this.id,
    required this.username,
    required this.totalPosts,
    required this.followers,
    required this.totalLikes,
  });

  factory AdminCreator.fromJson(Map<String, dynamic> json) {
    return AdminCreator(
      id: json['id'],
      username: json['first_name'] + ' ' + json['last_name'],
      totalPosts: json['posts_count'] ?? 0,
      followers: json['subscribers_count'] ?? 0,
      totalLikes: json['likes_count'] ?? 0,
    );
  }
}
