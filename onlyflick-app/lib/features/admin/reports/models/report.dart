class Report {
  final int id;
  final int userId;
  final String reporterUsername;
  final String contentType; // "post" ou "comment"
  final int contentId;
  final String reason;
  final String status;
  final DateTime createdAt;
  final String text;
  final String? imageUrl;

  Report({
    required this.id,
    required this.userId,
    required this.reporterUsername,
    required this.contentType,
    required this.contentId,
    required this.reason,
    required this.status,
    required this.createdAt,
    required this.text,
    required this.imageUrl,
  });

  factory Report.fromJson(Map<String, dynamic> json) {
    return Report(
      id: json['id'],
      userId: json['user_id'],
      reporterUsername: json['reporter_username'],
      contentType: json['content_type'],
      contentId: json['content_id'],
      reason: json['reason'],
      status: json['status'],
      createdAt: DateTime.parse(json['created_at']),
      text: json['text'],
      imageUrl: json['image_url'],
    );
  }
}
