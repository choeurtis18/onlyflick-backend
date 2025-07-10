/// lib/features/home/presentation/widgets/report_dialog.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/models/report_models.dart';
import '../../../../core/providers/report_provider.dart';

class ReportDialog extends StatefulWidget {
  final ContentType contentType;
  final int contentId;
  final String? contentTitle; // Titre du post ou début du commentaire pour affichage

  const ReportDialog({
    super.key,
    required this.contentType,
    required this.contentId,
    this.contentTitle,
  });

  @override
  State<ReportDialog> createState() => _ReportDialogState();

  /// Méthode statique pour afficher le dialogue
  static Future<bool?> show(
    BuildContext context, {
    required ContentType contentType,
    required int contentId,
    String? contentTitle,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false, 
      builder: (context) => ReportDialog(
        contentType: contentType,
        contentId: contentId,
        contentTitle: contentTitle,
      ),
    );
  }
}

class _ReportDialogState extends State<ReportDialog> {
  ReportReason? _selectedReason;
  final TextEditingController _customReasonController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _customReasonController.dispose();
    super.dispose();
  }

  String get _contentTypeDisplay => widget.contentType.displayName.toLowerCase();

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ReportProvider(),
      child: Consumer<ReportProvider>(
        builder: (context, provider, _) {
          // Écouter les changements d'état pour fermer le dialogue
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _handleStateChange(provider);
          });

          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                Icon(
                  Icons.flag_outlined,
                  color: Colors.red[600],
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  'Signaler ${_contentTypeDisplay}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: MediaQuery.of(context).size.width * 0.8,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.contentTitle != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            widget.contentType == ContentType.post
                                ? Icons.article_outlined
                                : Icons.comment_outlined,
                            color: Colors.grey[600],
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              widget.contentTitle!,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[800],
                                fontStyle: FontStyle.italic,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  
                  Text(
                    'Pourquoi signalez-vous ce ${_contentTypeDisplay} ?',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Liste des raisons prédéfinies
                  ...ReportReason.values.map((reason) => _buildReasonOption(reason)),
                  
                  const SizedBox(height: 16),
                  
                  // Zone de texte pour raison personnalisée
                  if (_selectedReason == ReportReason.other) ...[
                    TextField(
                      controller: _customReasonController,
                      decoration: InputDecoration(
                        hintText: 'Veuillez préciser la raison...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.blue[600]!),
                        ),
                      ),
                      maxLines: 3,
                      maxLength: 500,
                    ),
                    const SizedBox(height: 16),
                  ],
                  
                  // Affichage des erreurs
                  if (provider.creationError != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red[200]!),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.error_outline,
                            color: Colors.red[600],
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              provider.creationError!,
                              style: TextStyle(
                                color: Colors.red[800],
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
                child: const Text('Annuler'),
              ),
              ElevatedButton(
                onPressed: _canSubmit() && !_isSubmitting
                    ? () => _submitReport(provider)
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red[600],
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Signaler'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildReasonOption(ReportReason reason) {
    return RadioListTile<ReportReason>(
      value: reason,
      groupValue: _selectedReason,
      onChanged: (value) {
        setState(() {
          _selectedReason = value;
          if (value != ReportReason.other) {
            _customReasonController.clear();
          }
        });
      },
      title: Text(
        reason.displayName,
        style: const TextStyle(fontSize: 15),
      ),
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 0),
      activeColor: Colors.red[600],
    );
  }

  bool _canSubmit() {
    if (_selectedReason == null) return false;
    if (_selectedReason == ReportReason.other) {
      return _customReasonController.text.trim().isNotEmpty;
    }
    return true;
  }

  String _getReasonText() {
    if (_selectedReason == ReportReason.other) {
      return _customReasonController.text.trim();
    }
    return _selectedReason!.displayName;
  }

  Future<void> _submitReport(ReportProvider provider) async {
    setState(() {
      _isSubmitting = true;
    });

    final success = await provider.createReport(
      contentType: widget.contentType,
      contentId: widget.contentId,
      reason: _getReasonText(),
    );

    setState(() {
      _isSubmitting = false;
    });

    if (success) {
      // Le dialogue sera fermé par _handleStateChange
      return;
    }
  }

  void _handleStateChange(ReportProvider provider) {
    if (provider.creationState == ReportCreationState.success) {
      // Afficher un message de succès
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text('${widget.contentType.displayName} signalé avec succès'),
            ],
          ),
          backgroundColor: Colors.green[600],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          margin: const EdgeInsets.all(16),
          duration: const Duration(seconds: 3),
        ),
      );

      // Fermer le dialogue
      Navigator.of(context).pop(true);
    }
  }
}