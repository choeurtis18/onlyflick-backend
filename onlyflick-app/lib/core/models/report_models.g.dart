// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'report_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CreateReportRequest _$CreateReportRequestFromJson(Map<String, dynamic> json) =>
    CreateReportRequest(
      contentType: json['content_type'] as String,
      contentId: (json['content_id'] as num).toInt(),
      reason: json['reason'] as String,
    );

Map<String, dynamic> _$CreateReportRequestToJson(
        CreateReportRequest instance) =>
    <String, dynamic>{
      'content_type': instance.contentType,
      'content_id': instance.contentId,
      'reason': instance.reason,
    };

Report _$ReportFromJson(Map<String, dynamic> json) => Report(
      id: (json['id'] as num).toInt(),
      userId: (json['user_id'] as num).toInt(),
      contentType: $enumDecode(_$ContentTypeEnumMap, json['content_type']),
      contentId: (json['content_id'] as num).toInt(),
      reason: json['reason'] as String,
      status: $enumDecode(_$ReportStatusEnumMap, json['status']),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] == null
          ? null
          : DateTime.parse(json['updated_at'] as String),
    );

Map<String, dynamic> _$ReportToJson(Report instance) => <String, dynamic>{
      'id': instance.id,
      'user_id': instance.userId,
      'content_type': _$ContentTypeEnumMap[instance.contentType]!,
      'content_id': instance.contentId,
      'reason': instance.reason,
      'status': _$ReportStatusEnumMap[instance.status]!,
      'created_at': instance.createdAt.toIso8601String(),
      'updated_at': instance.updatedAt?.toIso8601String(),
    };

const _$ContentTypeEnumMap = {
  ContentType.post: 'post',
  ContentType.comment: 'comment',
};

const _$ReportStatusEnumMap = {
  ReportStatus.pending: 'pending',
  ReportStatus.approved: 'approved',
  ReportStatus.refused: 'refused',
};

CreateReportResponse _$CreateReportResponseFromJson(
        Map<String, dynamic> json) =>
    CreateReportResponse(
      message: json['message'] as String,
    );

Map<String, dynamic> _$CreateReportResponseToJson(
        CreateReportResponse instance) =>
    <String, dynamic>{
      'message': instance.message,
    };
