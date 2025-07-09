///  lib/core//providers/report_provider.dart

import 'package:flutter/foundation.dart';
import '../../../core/models/report_models.dart';
import '../services/report_service.dart';

/// États possibles pour la création d'un signalement
enum ReportCreationState {
  initial,
  loading,
  success,
  error,
}

/// États possibles pour le chargement des signalements
enum ReportLoadingState {
  initial,
  loading,
  loaded,
  error,
}

class ReportProvider extends ChangeNotifier {
  final ReportService _reportService = ReportService();

  // États pour la création de signalement
  ReportCreationState _creationState = ReportCreationState.initial;
  String? _creationError;

  // États pour le chargement des signalements
  ReportLoadingState _loadingState = ReportLoadingState.initial;
  List<Report> _reports = [];
  List<Report> _pendingReports = [];
  String? _loadingError;

  // États pour la mise à jour du statut
  bool _isUpdatingStatus = false;
  String? _statusUpdateError;

  // Getters
  ReportCreationState get creationState => _creationState;
  String? get creationError => _creationError;
  
  ReportLoadingState get loadingState => _loadingState;
  List<Report> get reports => _reports;
  List<Report> get pendingReports => _pendingReports;
  String? get loadingError => _loadingError;
  
  bool get isUpdatingStatus => _isUpdatingStatus;
  String? get statusUpdateError => _statusUpdateError;

  // Getters utilitaires
  bool get isCreating => _creationState == ReportCreationState.loading;
  bool get isLoading => _loadingState == ReportLoadingState.loading;
  bool get hasReports => _reports.isNotEmpty;
  bool get hasPendingReports => _pendingReports.isNotEmpty;

  /// Créer un signalement
  Future<bool> createReport({
    required ContentType contentType,
    required int contentId,
    required String reason,
  }) async {
    _setCreationState(ReportCreationState.loading);
    _creationError = null;

    try {
      final result = await _reportService.createReport(
        contentType: contentType,
        contentId: contentId,
        reason: reason,
      );

      if (result.isSuccess) {
        _setCreationState(ReportCreationState.success);
        
        // Rafraîchir la liste des signalements en attente si elle est chargée
        if (_loadingState == ReportLoadingState.loaded) {
          await loadPendingReports();
        }
        
        debugPrint('✅ Report created successfully');
        return true;
      } else {
        _creationError = result.error;
        _setCreationState(ReportCreationState.error);
        debugPrint('❌ Failed to create report: ${result.error}');
        return false;
      }
    } catch (e) {
      _creationError = 'Erreur lors de la création du signalement';
      _setCreationState(ReportCreationState.error);
      debugPrint('❌ Report creation error: $e');
      return false;
    }
  }

  /// Charger tous les signalements
  Future<void> loadAllReports() async {
    _setLoadingState(ReportLoadingState.loading);
    _loadingError = null;

    try {
      final result = await _reportService.getAllReports();

      if (result.isSuccess && result.data != null) {
        _reports = result.data!;
        _setLoadingState(ReportLoadingState.loaded);
        debugPrint('✅ All reports loaded: ${_reports.length}');
      } else {
        _loadingError = result.error;
        _setLoadingState(ReportLoadingState.error);
        debugPrint('❌ Failed to load reports: ${result.error}');
      }
    } catch (e) {
      _loadingError = 'Erreur lors du chargement des signalements';
      _setLoadingState(ReportLoadingState.error);
      debugPrint('❌ Reports loading error: $e');
    }
  }

  /// Charger les signalements en attente
  Future<void> loadPendingReports() async {
    _setLoadingState(ReportLoadingState.loading);
    _loadingError = null;

    try {
      final result = await _reportService.getPendingReports();

      if (result.isSuccess && result.data != null) {
        _pendingReports = result.data!;
        _setLoadingState(ReportLoadingState.loaded);
        debugPrint('✅ Pending reports loaded: ${_pendingReports.length}');
      } else {
        _loadingError = result.error;
        _setLoadingState(ReportLoadingState.error);
        debugPrint('❌ Failed to load pending reports: ${result.error}');
      }
    } catch (e) {
      _loadingError = 'Erreur lors du chargement des signalements en attente';
      _setLoadingState(ReportLoadingState.error);
      debugPrint('❌ Pending reports loading error: $e');
    }
  }

  /// Mettre à jour le statut d'un signalement
  Future<bool> updateReportStatus({
    required int reportId,
    required ReportStatus status,
  }) async {
    _isUpdatingStatus = true;
    _statusUpdateError = null;
    notifyListeners();

    try {
      final result = await _reportService.updateReportStatus(
        reportId: reportId,
        status: status,
      );

      if (result.isSuccess) {
        // Mettre à jour localement le rapport dans les listes
        _updateLocalReportStatus(reportId, status);
        
        _isUpdatingStatus = false;
        debugPrint('✅ Report status updated successfully');
        notifyListeners();
        return true;
      } else {
        _statusUpdateError = result.error;
        _isUpdatingStatus = false;
        debugPrint('❌ Failed to update report status: ${result.error}');
        notifyListeners();
        return false;
      }
    } catch (e) {
      _statusUpdateError = 'Erreur lors de la mise à jour du statut';
      _isUpdatingStatus = false;
      debugPrint('❌ Report status update error: $e');
      notifyListeners();
      return false;
    }
  }

  /// Supprimer un signalement de la liste en attente (après traitement)
  void removeFromPendingReports(int reportId) {
    _pendingReports.removeWhere((report) => report.id == reportId);
    notifyListeners();
  }

  /// Réinitialiser l'état de création
  void resetCreationState() {
    _creationState = ReportCreationState.initial;
    _creationError = null;
    notifyListeners();
  }

  /// Réinitialiser l'état de chargement
  void resetLoadingState() {
    _loadingState = ReportLoadingState.initial;
    _loadingError = null;
    notifyListeners();
  }

  /// Réinitialiser l'erreur de mise à jour de statut
  void resetStatusUpdateError() {
    _statusUpdateError = null;
    notifyListeners();
  }

  /// Filtrer les signalements par type de contenu
  List<Report> getReportsByContentType(ContentType contentType) {
    return _reports.where((report) => report.contentType == contentType).toList();
  }

  /// Filtrer les signalements par statut
  List<Report> getReportsByStatus(ReportStatus status) {
    return _reports.where((report) => report.status == status).toList();
  }

  /// Obtenir le nombre de signalements par statut
  int getReportCountByStatus(ReportStatus status) {
    return _reports.where((report) => report.status == status).length;
  }

  /// Vérifier si un contenu a été signalé
  bool isContentReported(ContentType contentType, int contentId) {
    return _reports.any((report) => 
      report.contentType == contentType && 
      report.contentId == contentId
    );
  }

  // Méthodes privées
  void _setCreationState(ReportCreationState state) {
    _creationState = state;
    notifyListeners();
  }

  void _setLoadingState(ReportLoadingState state) {
    _loadingState = state;
    notifyListeners();
  }

  void _updateLocalReportStatus(int reportId, ReportStatus newStatus) {
    // Mettre à jour dans la liste complète
    final reportIndex = _reports.indexWhere((report) => report.id == reportId);
    if (reportIndex != -1) {
      _reports[reportIndex] = Report(
        id: _reports[reportIndex].id,
        userId: _reports[reportIndex].userId,
        contentType: _reports[reportIndex].contentType,
        contentId: _reports[reportIndex].contentId,
        reason: _reports[reportIndex].reason,
        status: newStatus,
        createdAt: _reports[reportIndex].createdAt,
        updatedAt: DateTime.now(),
      );
    }

    // Retirer de la liste en attente si le statut n'est plus pending
    if (newStatus != ReportStatus.pending) {
      _pendingReports.removeWhere((report) => report.id == reportId);
    }
  }
}