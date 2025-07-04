class AdminStats {
  final int totalUsers;
  final int totalPosts;
  final int totalReports;
  final int totalRevenue;


  AdminStats({
    required this.totalUsers,
    required this.totalPosts,
    required this.totalReports,
    required this.totalRevenue,
  });

  factory AdminStats.fromJson(Map<String, dynamic> json) {
    return AdminStats(
      totalUsers: json['total_users'] ?? 0,
      totalPosts: json['total_posts'] ?? 0,
      totalReports: json['total_reports'] ?? 0,
      totalRevenue: json['total_revenue'] ?? 0,
    );
  }
}
