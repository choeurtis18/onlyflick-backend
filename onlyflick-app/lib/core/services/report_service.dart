/// lib/core/services/report_service.dart

import 'package:flutter/foundation.dart';
import '../../../core/services/api_service.dart';
import '../../../core/models/report_models.dart';

class ReportService {
  final ApiService _apiService = ApiService();

  /// Créer un signalement pour un post ou commentaire
  Future<ReportResult<CreateReportResponse>> createReport({
    required ContentType contentType,
    required int contentId,
    required String reason,
  }) async {
    try {
      debugPrint('📝 Creating report for ${contentType.name} $contentId');
      
      final request = CreateReportRequest(
        contentType: contentType.name, // 'post' ou 'comment'
        contentId: contentId,
        reason: reason,
      );

      final response = await _apiService.post<CreateReportResponse>(
        '/reports', 
        body: request.toJson(),
        fromJson: (json) => CreateReportResponse.fromJson(json),
      );

      if (response.isSuccess && response.data != null) {
        debugPrint('✅ Report created successfully');
        return ReportResult.success(response.data!);
      } else {
        debugPrint('❌ Failed to create report: ${response.error}');
        return ReportResult.failure(
          response.error ?? 'Erreur lors de la création du signalement',
        );
      }
    } catch (e) {
      debugPrint('❌ Report creation error: $e');
      return ReportResult.failure('Erreur réseau lors du signalement');
    }
  }

  /// Récupérer tous les signalements (pour les administrateurs)
  Future<ReportResult<List<Report>>> getAllReports() async {
    try {
      debugPrint('📋 Fetching all reports');
      
      final response = await _apiService.get<List<Report>>(
        '/reports', 
        fromJson: (json) => (json as List)
            .map((item) => Report.fromJson(item as Map<String, dynamic>))
            .toList(),
      );

      if (response.isSuccess && response.data != null) {
        debugPrint('✅ ${response.data!.length} reports fetched');
        return ReportResult.success(response.data!);
      } else {
        debugPrint('❌ Failed to fetch reports: ${response.error}');
        return ReportResult.failure(
          response.error ?? 'Erreur lors de la récupération des signalements',
        );
      }
    } catch (e) {
      debugPrint('❌ Reports fetch error: $e');
      return ReportResult.failure('Erreur réseau lors de la récupération');
    }
  }

  /// Récupérer les signalements en attente (pour les administrateurs)
  Future<ReportResult<List<Report>>> getPendingReports() async {
    try {
      debugPrint('⏳ Fetching pending reports');
      
      final response = await _apiService.get<List<Report>>(
        '/reports/pending',
        fromJson: (json) => (json as List)
            .map((item) => Report.fromJson(item as Map<String, dynamic>))
            .toList(),
      );

      if (response.isSuccess && response.data != null) {
        debugPrint('✅ ${response.data!.length} pending reports fetched');
        return ReportResult.success(response.data!);
      } else {
        debugPrint('❌ Failed to fetch pending reports: ${response.error}');
        return ReportResult.failure(
          response.error ?? 'Erreur lors de la récupération des signalements en attente',
        );
      }
    } catch (e) {
      debugPrint('❌ Pending reports fetch error: $e');
      return ReportResult.failure('Erreur réseau lors de la récupération');
    }
  }

  /// Mettre à jour le statut d'un signalement (pour les administrateurs)
  Future<ReportResult<void>> updateReportStatus({
    required int reportId,
    required ReportStatus status,
  }) async {
    try {
      debugPrint('🔄 Updating report $reportId status to ${status.name}');
      
      final response = await _apiService.patch<Map<String, dynamic>>(
        '/reports/$reportId/status', 
        body: {'status': status.name},
        fromJson: (json) => json as Map<String, dynamic>,
      );

      if (response.isSuccess) {
        debugPrint('✅ Report status updated successfully');
        return const ReportResult.success(null);
      } else {
        debugPrint('❌ Failed to update report status: ${response.error}');
        return ReportResult.failure(
          response.error ?? 'Erreur lors de la mise à jour du statut',
        );
      }
    } catch (e) {
      debugPrint('❌ Report status update error: $e');
      return ReportResult.failure('Erreur réseau lors de la mise à jour');
    }
  }

  /// Récupérer les signalements d'un utilisateur spécifique (pour les administrateurs)
  Future<ReportResult<List<Report>>> getReportsByUser(int userId) async {
    try {
      debugPrint('👤 Fetching reports by user $userId');
      
      final response = await _apiService.get<List<Report>>(
        '/reports/user/$userId',
        fromJson: (json) => (json as List)
            .map((item) => Report.fromJson(item as Map<String, dynamic>))
            .toList(),
      );

      if (response.isSuccess && response.data != null) {
        debugPrint('✅ ${response.data!.length} reports fetched for user $userId');
        return ReportResult.success(response.data!);
      } else {
        debugPrint('❌ Failed to fetch user reports: ${response.error}');
        return ReportResult.failure(
          response.error ?? 'Erreur lors de la récupération des signalements utilisateur',
        );
      }
    } catch (e) {
      debugPrint('❌ User reports fetch error: $e');
      return ReportResult.failure('Erreur réseau lors de la récupération');
    }
  }

  /// Récupérer les signalements pour un contenu spécifique
  Future<ReportResult<List<Report>>> getReportsForContent({
    required ContentType contentType,
    required int contentId,
  }) async {
    try {
      debugPrint('🎯 Fetching reports for ${contentType.name} $contentId');
      
      final response = await _apiService.get<List<Report>>(
        '/reports/${contentType.name}/$contentId',
        fromJson: (json) => (json as List)
            .map((item) => Report.fromJson(item as Map<String, dynamic>))
            .toList(),
      );

      if (response.isSuccess && response.data != null) {
        debugPrint('✅ ${response.data!.length} reports fetched for content');
        return ReportResult.success(response.data!);
      } else {
        debugPrint('❌ Failed to fetch content reports: ${response.error}');
        return ReportResult.failure(
          response.error ?? 'Erreur lors de la récupération des signalements du contenu',
        );
      }
    } catch (e) {
      debugPrint('❌ Content reports fetch error: $e');
      return ReportResult.failure('Erreur réseau lors de la récupération');
    }
  }
}