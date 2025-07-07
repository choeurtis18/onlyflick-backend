// lib/widgets/payment/subscription_payment_widget.dart

import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import '../../../../core/models/subscription_model.dart';
import '../../../../core/services/subscription_service.dart';



class SubscriptionPaymentWidget extends StatefulWidget {
  final int creatorId;
  final UserProfile creatorProfile;
  final VoidCallback? onPaymentSuccess;
  final VoidCallback? onPaymentCancel;

  const SubscriptionPaymentWidget({
    Key? key,
    required this.creatorId,
    required this.creatorProfile,
    this.onPaymentSuccess,
    this.onPaymentCancel,
  }) : super(key: key);

  @override
  State<SubscriptionPaymentWidget> createState() => _SubscriptionPaymentWidgetState();
}

class _SubscriptionPaymentWidgetState extends State<SubscriptionPaymentWidget> {
  bool _isLoading = false;
  String? _errorMessage;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header avec avatar du créateur
          _buildHeader(),
          
          const SizedBox(height: 20),
          
          // Détails de l'abonnement
          _buildSubscriptionDetails(),
          
          const SizedBox(height: 20),
          
          // Message d'erreur si présent
          if (_errorMessage != null) ...[
            _buildErrorMessage(),
            const SizedBox(height: 16),
          ],
          
          // Boutons d'action
          _buildActionButtons(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        // Avatar du créateur
        CircleAvatar(
          radius: 30,
          backgroundImage: widget.creatorProfile.avatarUrl != null
              ? NetworkImage(widget.creatorProfile.avatarUrl!)
              : null,
          child: widget.creatorProfile.avatarUrl == null
              ? Text(
                  widget.creatorProfile.username.isNotEmpty
                      ? widget.creatorProfile.username[0].toUpperCase()
                      : '?',
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                )
              : null,
        ),
        
        const SizedBox(width: 16),
        
        // Informations du créateur
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'S\'abonner à',
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).textTheme.bodySmall?.color,
                ),
              ),
              Text(
                widget.creatorProfile.fullName.isNotEmpty 
                    ? widget.creatorProfile.fullName 
                    : widget.creatorProfile.username,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (widget.creatorProfile.bio != null) ...[
                const SizedBox(height: 4),
                Text(
                  widget.creatorProfile.bio!,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).textTheme.bodySmall?.color,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSubscriptionDetails() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).primaryColor.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Abonnement mensuel',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Text(
                '4,99 €',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          const Text(
            '✓ Accès au contenu premium\n'
            '✓ Messagerie privée avec le créateur\n'
            '✓ Support du créateur\n'
            '✓ Renouvelé automatiquement chaque mois',
            style: TextStyle(fontSize: 14, height: 1.5),
          ),
          
          const SizedBox(height: 12),
          
          Text(
            'Vous pouvez annuler votre abonnement à tout moment.',
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).textTheme.bodySmall?.color,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorMessage() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _errorMessage!,
              style: const TextStyle(color: Colors.red, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        // Bouton Annuler
        Expanded(
          child: OutlinedButton(
            onPressed: _isLoading ? null : () {
              widget.onPaymentCancel?.call();
              Navigator.of(context).pop();
            },
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'Annuler',
              style: TextStyle(fontSize: 16),
            ),
          ),
        ),
        
        const SizedBox(width: 12),
        
        // Bouton Payer
        Expanded(
          flex: 2,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _handlePayment,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: _isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Text(
                    'Payer 4,99 €',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
          ),
        ),
      ],
    );
  }

  Future<void> _handlePayment() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      print('🔄 [PaymentWidget] Début du processus de paiement pour le créateur ${widget.creatorId}');
      
      // 1. Créer l'abonnement et récupérer le client_secret
      final paymentData = await SubscriptionService.subscribeWithPayment(widget.creatorId);
      
      if (!paymentData['success']) {
        throw Exception(paymentData['message'] ?? 'Erreur lors de la création de l\'abonnement');
      }

      final clientSecret = paymentData['client_secret'] as String?;
      if (clientSecret == null) {
        throw Exception('Client secret manquant dans la réponse du serveur');
      }

      print('✅ [PaymentWidget] Client secret reçu: ${clientSecret.substring(0, 20)}...');

      // 2. Confirmer le paiement avec Stripe
      await Stripe.instance.confirmPayment(
        paymentIntentClientSecret: clientSecret,
        data: const PaymentMethodParams.card(
          paymentMethodData: PaymentMethodData(
            billingDetails: BillingDetails(),
          ),
        ),
      );

      print('✅ [PaymentWidget] Paiement confirmé avec succès');

      // 3. Afficher le message de succès
      if (mounted) {
        _showSuccessMessage();
        widget.onPaymentSuccess?.call();
        
        // Fermer le widget après 2 secondes
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            Navigator.of(context).pop(true); // Retourner true pour indiquer le succès
          }
        });
      }

    } catch (e) {
      print('❌ [PaymentWidget] Erreur de paiement: $e');
      
      if (mounted) {
        setState(() {
          _errorMessage = _getErrorMessage(e);
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _getErrorMessage(dynamic error) {
    final errorString = error.toString().toLowerCase();
    
    if (errorString.contains('canceled') || errorString.contains('cancelled')) {
      return 'Paiement annulé par l\'utilisateur';
    } else if (errorString.contains('insufficient_funds')) {
      return 'Fonds insuffisants sur votre carte';
    } else if (errorString.contains('card_declined')) {
      return 'Carte refusée. Veuillez vérifier vos informations';
    } else if (errorString.contains('expired_card')) {
      return 'Votre carte a expiré';
    } else if (errorString.contains('invalid_cvc')) {
      return 'Code CVC invalide';
    } else if (errorString.contains('processing_error')) {
      return 'Erreur de traitement. Veuillez réessayer';
    } else if (errorString.contains('déjà abonné')) {
      return 'Vous êtes déjà abonné à ce créateur';
    } else {
      return 'Une erreur est survenue. Veuillez réessayer.';
    }
  }

  void _showSuccessMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 8),
            Text('Abonnement à ${widget.creatorProfile.username} réussi !'),
          ],
        ),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }
}

// Fonction utilitaire pour afficher le widget de paiement
class PaymentHelper {
  static Future<bool?> showSubscriptionPayment({
    required BuildContext context,
    required int creatorId,
    required UserProfile creatorProfile,
    VoidCallback? onSuccess,
    VoidCallback? onCancel,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: SubscriptionPaymentWidget(
          creatorId: creatorId,
          creatorProfile: creatorProfile,
          onPaymentSuccess: onSuccess,
          onPaymentCancel: onCancel,
        ),
      ),
    );
  }
}