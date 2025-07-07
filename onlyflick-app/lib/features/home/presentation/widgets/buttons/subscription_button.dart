// lib/widgets/buttons/subscription_button.dart

import 'package:flutter/material.dart';

import '../../../../../core/models/subscription_model.dart';
import '../../widgets/subscription_payment_widget.dart';
import '../../../../../core/services/subscription_service.dart';


class SubscriptionButton extends StatefulWidget {
  final int creatorId;
  final UserProfile creatorProfile;
  final VoidCallback? onSubscriptionChanged;
  final bool showPrice;
  final ButtonStyle? customStyle;

  const SubscriptionButton({
    Key? key,
    required this.creatorId,
    required this.creatorProfile,
    this.onSubscriptionChanged,
    this.showPrice = true,
    this.customStyle,
  }) : super(key: key);

  @override
  State<SubscriptionButton> createState() => _SubscriptionButtonState();
}

class _SubscriptionButtonState extends State<SubscriptionButton> {
  bool _isSubscribed = false;
  bool _isLoading = false;
  bool _isCheckingStatus = true;

  @override
  void initState() {
    super.initState();
    _checkSubscriptionStatus();
  }

  Future<void> _checkSubscriptionStatus() async {
    try {
      final isSubscribed = await SubscriptionService.isFollowing(widget.creatorId);
      if (mounted) {
        setState(() {
          _isSubscribed = isSubscribed;
          _isCheckingStatus = false;
        });
      }
    } catch (e) {
      print('❌ [SubscriptionButton] Erreur vérification statut: $e');
      if (mounted) {
        setState(() {
          _isCheckingStatus = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isCheckingStatus) {
      return _buildLoadingButton();
    }

    return _isSubscribed ? _buildUnsubscribeButton() : _buildSubscribeButton();
  }

  Widget _buildLoadingButton() {
    return ElevatedButton(
      onPressed: null,
      style: widget.customStyle ?? _getDefaultStyle(context, false),
      child: const SizedBox(
        height: 20,
        width: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(Colors.white54),
        ),
      ),
    );
  }

  Widget _buildSubscribeButton() {
    return ElevatedButton.icon(
      onPressed: _isLoading ? null : _handleSubscribe,
      style: widget.customStyle ?? _getDefaultStyle(context, false),
      icon: _isLoading
          ? const SizedBox(
              height: 16,
              width: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
          : const Icon(Icons.add, size: 18),
      label: Text(
        widget.showPrice ? 'S\'abonner 4,99€' : 'S\'abonner',
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
      ),
    );
  }

  Widget _buildUnsubscribeButton() {
    return ElevatedButton.icon(
      onPressed: _isLoading ? null : _handleUnsubscribe,
      style: widget.customStyle ?? _getDefaultStyle(context, true),
      icon: _isLoading
          ? const SizedBox(
              height: 16,
              width: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
          : const Icon(Icons.check, size: 18),
      label: const Text(
        'Abonné',
        style: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
      ),
    );
  }

  ButtonStyle _getDefaultStyle(BuildContext context, bool isSubscribed) {
    return ElevatedButton.styleFrom(
      backgroundColor: isSubscribed 
          ? Colors.green 
          : Theme.of(context).primaryColor,
      foregroundColor: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      elevation: 2,
    );
  }

  Future<void> _handleSubscribe() async {
    setState(() {
      _isLoading = true;
    });

    try {
      print('🔄 [SubscriptionButton] Tentative d\'abonnement au créateur ${widget.creatorId}');
      
      // Afficher le widget de paiement
      final success = await PaymentHelper.showSubscriptionPayment(
        context: context,
        creatorId: widget.creatorId,
        creatorProfile: widget.creatorProfile,
        onSuccess: () {
          print('✅ [SubscriptionButton] Paiement réussi');
        },
        onCancel: () {
          print('❌ [SubscriptionButton] Paiement annulé');
        },
      );

      if (success == true && mounted) {
        setState(() {
          _isSubscribed = true;
        });
        widget.onSubscriptionChanged?.call();
        _showSuccessSnackBar();
      }

    } catch (e) {
      print('❌ [SubscriptionButton] Erreur abonnement: $e');
      if (mounted) {
        _showErrorSnackBar(e.toString());
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleUnsubscribe() async {
    // Afficher une confirmation avant de se désabonner
    final confirmed = await _showUnsubscribeConfirmation();
    if (!confirmed) return;

    setState(() {
      _isLoading = true;
    });

    try {
      print('🔄 [SubscriptionButton] Tentative de désabonnement du créateur ${widget.creatorId}');
      
      final result = await SubscriptionService.unsubscribe(widget.creatorId);
      
      if (result['success'] && mounted) {
        setState(() {
          _isSubscribed = false;
        });
        widget.onSubscriptionChanged?.call();
        _showUnsubscribeSuccessSnackBar();
      } else {
        throw Exception(result['message'] ?? 'Erreur lors du désabonnement');
      }

    } catch (e) {
      print('❌ [SubscriptionButton] Erreur désabonnement: $e');
      if (mounted) {
        _showErrorSnackBar(e.toString());
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<bool> _showUnsubscribeConfirmation() async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmer le désabonnement'),
        content: Text(
          'Êtes-vous sûr de vouloir vous désabonner de ${widget.creatorProfile.username} ?\n\n'
          'Vous perdrez l\'accès au contenu premium et à la messagerie privée.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Se désabonner'),
          ),
        ],
      ),
    ) ?? false;
  }

  void _showSuccessSnackBar() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Vous êtes maintenant abonné à ${widget.creatorProfile.username} !',
              ),
            ),
          ],
        ),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
        action: SnackBarAction(
          label: 'Voir le profil',
          textColor: Colors.white,
          onPressed: () {
            // Navigation vers le profil du créateur
            // Navigator.pushNamed(context, '/profile/${widget.creatorId}');
          },
        ),
      ),
    );
  }

  void _showUnsubscribeSuccessSnackBar() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.info, color: Colors.white),
            const SizedBox(width: 8),
            Text('Désabonnement de ${widget.creatorProfile.username} réussi'),
          ],
        ),
        backgroundColor: Colors.orange,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showErrorSnackBar(String error) {
    String message = 'Une erreur est survenue';
    
    if (error.contains('déjà abonné')) {
      message = 'Vous êtes déjà abonné à ce créateur';
    } else if (error.contains('Session expirée')) {
      message = 'Session expirée, veuillez vous reconnecter';
    } else if (error.contains('réseau')) {
      message = 'Erreur de connexion, vérifiez votre réseau';
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'Réessayer',
          textColor: Colors.white,
          onPressed: () {
            if (_isSubscribed) {
              _handleUnsubscribe();
            } else {
              _handleSubscribe();
            }
          },
        ),
      ),
    );
  }
}

// Variantes du bouton pour différents contextes
class CompactSubscriptionButton extends StatelessWidget {
  final int creatorId;
  final UserProfile creatorProfile;
  final VoidCallback? onSubscriptionChanged;

  const CompactSubscriptionButton({
    Key? key,
    required this.creatorId,
    required this.creatorProfile,
    this.onSubscriptionChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SubscriptionButton(
      creatorId: creatorId,
      creatorProfile: creatorProfile,
      onSubscriptionChanged: onSubscriptionChanged,
      showPrice: false,
      customStyle: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        minimumSize: const Size(80, 32),
        textStyle: const TextStyle(fontSize: 12),
      ),
    );
  }
}

class IconSubscriptionButton extends StatelessWidget {
  final int creatorId;
  final UserProfile creatorProfile;
  final VoidCallback? onSubscriptionChanged;

  const IconSubscriptionButton({
    Key? key,
    required this.creatorId,
    required this.creatorProfile,
    this.onSubscriptionChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SubscriptionButton(
      creatorId: creatorId,
      creatorProfile: creatorProfile,
      onSubscriptionChanged: onSubscriptionChanged,
      showPrice: false,
      customStyle: ElevatedButton.styleFrom(
        shape: const CircleBorder(),
        padding: const EdgeInsets.all(12),
        minimumSize: const Size(48, 48),
      ),
    );
  }
}