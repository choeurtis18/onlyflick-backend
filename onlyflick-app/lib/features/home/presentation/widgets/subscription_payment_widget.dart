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
    return Dialog(
  insetPadding: const EdgeInsets.all(16),
  child: LayoutBuilder(
    builder: (context, constraints) {
      return SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: constraints.maxHeight,
            maxWidth: constraints.maxWidth,
          ),
          child: IntrinsicHeight(
            child: Container(
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
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 20),
                  _buildSubscriptionDetails(),
                  const SizedBox(height: 20),
                  _buildCardForm(),
                  const SizedBox(height: 20),
                  if (_errorMessage != null) ...[
                    _buildErrorMessage(),
                    const SizedBox(height: 16),
                  ],
                  _buildActionButtons(),
                ],
              ),
            ),
          ),
        ),
      );
    },
  ),
);
  }

Widget _buildHeader() {
  return Row(
    crossAxisAlignment: CrossAxisAlignment.start,
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

      // Bouton Close
      IconButton(
        icon: const Icon(Icons.close),
        splashRadius: 20,
        tooltip: 'Fermer',
        onPressed: () {
          widget.onPaymentCancel?.call();
          Navigator.of(context).pop();
        },
      ),
    ],
  );
}

  Widget _buildSubscriptionDetails() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.purple.shade50,
            Colors.blue.shade50,
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.purple.withOpacity(0.2),
          width: 1.5,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Abonnement mensuel',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1A1A1A),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.green.shade400, Colors.green.shade600],
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.green.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Text(
              '4,99 €',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardForm() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.grey.shade200,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header avec icône
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue.shade400, Colors.blue.shade600],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.credit_card,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Informations de paiement',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A1A1A),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 20),
          
          // Champ numéro de carte
          _buildInputField(
            label: 'Numéro de carte',
            child: CardField(
              onCardChanged: (card) {
                print('🔄 [PaymentWidget] Card changed: ${card?.complete}');
              },
              enablePostalCode: false,
              decoration: const InputDecoration(
                hintText: '1234 5678 9012 3456',
                hintStyle: TextStyle(
                  color: Color(0xFF9CA3AF),
                  fontSize: 14,
                ),
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF1A1A1A),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Champ nom du porteur
          _buildInputField(
            label: 'Nom du porteur',
            child: TextFormField(
              decoration: const InputDecoration(
                hintText: 'Nom tel qu\'il apparaît sur la carte',
                hintStyle: TextStyle(
                  color: Color(0xFF9CA3AF),
                  fontSize: 14,
                ),
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF1A1A1A),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
         
          const SizedBox(height: 20),
          
          // Badge sécurité et cartes acceptées
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              // Badge sécurité
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.green.shade200,
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.security,
                      color: Colors.green.shade700,
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Sécurisé par Stripe',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.green.shade700,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              
              // Cartes acceptées
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Cartes: ',
                    style: TextStyle(
                      fontSize: 11,
                      color: Color(0xFF6B7280),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  _buildCardLogo('Visa', Colors.blue.shade800),
                  const SizedBox(width: 3),
                  _buildCardLogo('MC', Colors.red.shade600),
                  const SizedBox(width: 3),
                  _buildCardLogo('Amex', Colors.green.shade700),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInputField({required String label, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFF374151),
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: Colors.grey.shade200,
              width: 1.5,
            ),
          ),
          child: child,
        ),
      ],
    );
  }

  Widget _buildCardLogo(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 0.5,
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: color,
        ),
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
    return Column(
      children: [
        // Bouton principal de paiement
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _handlePayment,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1A1A1A),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 0,
              shadowColor: Colors.transparent,
            ),
            child: _isLoading
                ? const SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Text(
                    'Payer 4,99 €',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          ),
        ),
        
        const SizedBox(height: 16),
        
        // Bouton annuler discret
        TextButton(
          onPressed: _isLoading ? null : () {
            widget.onPaymentCancel?.call();
            Navigator.of(context).pop();
          },
          style: TextButton.styleFrom(
            foregroundColor: const Color(0xFF6B7280),
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
          child: const Text(
            'Annuler',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
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
      final paymentResult = await SubscriptionService.subscribeWithPayment(widget.creatorId);
      
      // Vérifier si la requête a réussi
      if (!paymentResult['success']) {
        // Gérer les différents types d'erreurs
        final errorType = paymentResult['error_type'];
        final errorMessage = paymentResult['message'] ?? 'Erreur inconnue';
        
        if (errorType == 'already_subscribed') {
          // Cas spécial : utilisateur déjà abonné
          print('⚠️ [PaymentWidget] Utilisateur déjà abonné');
          
          if (mounted) {
            // Afficher un message d'information plutôt qu'une erreur
            _showAlreadySubscribedMessage();
            
            // Appeler le callback de succès car l'utilisateur est effectivement abonné
            widget.onPaymentSuccess?.call();
            
            // Fermer le widget après 2 secondes avec succès
            Future.delayed(const Duration(seconds: 2), () {
              if (mounted) {
                Navigator.of(context).pop(true); // Retourner true car l'abonnement existe
              }
            });
          }
          return; // Sortir de la fonction sans traiter comme une erreur
        } else {
          // Autres types d'erreurs (authentication, bad_request, etc.)
          throw Exception(errorMessage);
        }
      }

      // Si on arrive ici, la requête a réussi
      final clientSecret = paymentResult['client_secret'] as String?;
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
    } else if (errorString.contains('authentication')) {
      return 'Session expirée. Veuillez vous reconnecter';
    } else if (errorString.contains('not_found')) {
      return 'Créateur non trouvé';
    } else if (errorString.contains('network_error')) {
      return 'Erreur de connexion. Vérifiez votre connexion internet';
    } else if (errorString.contains('card details not complete')) {
      return 'Veuillez remplir tous les champs de la carte';
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

  // Nouvelle méthode pour afficher un message informatif quand l'utilisateur est déjà abonné
  void _showAlreadySubscribedMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.info_outline, color: Colors.white),
            const SizedBox(width: 8),
            Text('Vous êtes déjà abonné à ${widget.creatorProfile.username} !'),
          ],
        ),
        backgroundColor: Colors.orange,
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
      builder: (context) => SubscriptionPaymentWidget(
        creatorId: creatorId,
        creatorProfile: creatorProfile,
        onPaymentSuccess: onSuccess,
        onPaymentCancel: onCancel,
      ),
    );
  }
}