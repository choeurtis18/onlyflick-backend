// lib/core/models/report_models.dart

import 'package:json_annotation/json_annotation.dart';

part 'report_models.g.dart';

/// Énumération des types de contenu signalable
enum ContentType {
  @JsonValue('post')
  post,
  @JsonValue('comment')
  comment;

  String get displayName {
    switch (this) {
      case ContentType.post:
        return 'Publication';
      case ContentType.comment:
        return 'Commentaire';
    }
  }
}

/// Énumération des statuts de signalement
enum ReportStatus {
  @JsonValue('pending')
  pending,
  @JsonValue('approved')
  approved,
  @JsonValue('refused')
  refused;

  String get displayName {
    switch (this) {
      case ReportStatus.pending:
        return 'En attente';
      case ReportStatus.approved:
        return 'Approuvé';
      case ReportStatus.refused:
        return 'Refusé';
    }
  }
}

/// Requête pour créer un signalement
@JsonSerializable()
class CreateReportRequest {
  @JsonKey(name: 'content_type')
  final String contentType;
  
  @JsonKey(name: 'content_id')
  final int contentId;
  
  final String reason;

  const CreateReportRequest({
    required this.contentType,
    required this.contentId,
    required this.reason,
  });

  factory CreateReportRequest.fromJson(Map<String, dynamic> json) =>
      _$CreateReportRequestFromJson(json);

  Map<String, dynamic> toJson() => _$CreateReportRequestToJson(this);
}

/// Modèle pour un signalement
@JsonSerializable()
class Report {
  final int id;
  
  @JsonKey(name: 'user_id')
  final int userId;
  
  @JsonKey(name: 'content_type')
  final ContentType contentType;
  
  @JsonKey(name: 'content_id')
  final int contentId;
  
  final String reason;
  final ReportStatus status;
  
  @JsonKey(name: 'created_at')
  final DateTime createdAt;
  
  @JsonKey(name: 'updated_at')
  final DateTime? updatedAt;

  const Report({
    required this.id,
    required this.userId,
    required this.contentType,
    required this.contentId,
    required this.reason,
    required this.status,
    required this.createdAt,
    this.updatedAt,
  });

  factory Report.fromJson(Map<String, dynamic> json) => _$ReportFromJson(json);

  Map<String, dynamic> toJson() => _$ReportToJson(this);
}

/// Réponse après création d'un signalement
@JsonSerializable()
class CreateReportResponse {
  final String message;

  const CreateReportResponse({
    required this.message,
  });

  factory CreateReportResponse.fromJson(Map<String, dynamic> json) =>
      _$CreateReportResponseFromJson(json);

  Map<String, dynamic> toJson() => _$CreateReportResponseToJson(this);
}

/// Résultat d'une opération de signalement
class ReportResult<T> {
  final bool isSuccess;
  final T? data;
  final String? error;

  const ReportResult.success(this.data)
      : isSuccess = true,
        error = null;

  const ReportResult.failure(this.error)
      : isSuccess = false,
        data = null;
}

/// Énumération des raisons de signalement prédéfinies
enum ReportReason {
  spam('Spam ou contenu indésirable'),
  harassment('Harcèlement'),
  inappropriate('Contenu inapproprié'),
  copyright('Violation de droits d\'auteur'),
  misinformation('Désinformation'),
  violence('Contenu violent'),
  other('Autre raison');

  const ReportReason(this.displayName);
  
  final String displayName;
}