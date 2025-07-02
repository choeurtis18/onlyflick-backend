// lib/features/user/presentation/pages/public_profile_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/models/user_models.dart';
import '../../../../core/services/user_service.dart';
import '../../../../features/auth/auth_provider.dart';

/// Page pour afficher le profil public d'un utilisateur
/// Permet de s'abonner si c'est un créateur
class PublicProfilePage extends StatefulWidget {
  final int userId;
  final String? username; // Optionnel pour l'affichage initial

  const PublicProfilePage({
    Key? key,
    required this.userId,
    this.username,
  }) : super(key: key);

  @override
  State<PublicProfilePage> createState() => _PublicProfilePageState();
}

class _PublicProfilePageState extends State<PublicProfilePage> {
  final UserService _userService = UserService();
  
  PublicUserProfile? _profile;
  SubscriptionStatus? _subscriptionStatus;
  bool _isLoadingProfile = false;
  bool _isLoadingSubscription = false;
  bool _isSubscriptionAction = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  /// Charge le profil public de l'utilisateur
  Future<void> _loadProfile() async {
    setState(() {
      _isLoadingProfile = true;
      _error = null;
    });

    final result = await _userService.getUserProfile(widget.userId);
    
    if (result.isSuccess && result.data != null) {
      setState(() {
        _profile = result.data!;
        _isLoadingProfile = false;
      });
      
      // Si c'est un créateur, charger le statut d'abonnement
      if (_profile!.isCreator) {
        _loadSubscriptionStatus();
      }
    } else {
      setState(() {
        _error = result.error?.message ?? 'Erreur lors du chargement du profil';
        _isLoadingProfile = false;
      });
    }
  }

  /// Charge le statut d'abonnement pour un créateur
  Future<void> _loadSubscriptionStatus() async {
    if (!_profile!.isCreator) return;

    setState(() {
      _isLoadingSubscription = true;
    });

    final result = await _userService.checkSubscriptionStatus(widget.userId);
    
    if (result.isSuccess && result.data != null) {
      setState(() {
        _subscriptionStatus = result.data!;
        _isLoadingSubscription = false;
      });
    } else {
      setState(() {
        _isLoadingSubscription = false;
      });
      // Ne pas afficher d'erreur pour le statut d'abonnement, juste loguer
      debugPrint('Failed to load subscription status: ${result.error?.message}');
    }
  }

  /// Gère l'abonnement/désabonnement
  Future<void> _handleSubscriptionAction() async {
    if (_profile == null || !_profile!.isCreator || _isSubscriptionAction) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (!authProvider.isAuthenticated) {
      _showError('Vous devez être connecté pour vous abonner');
      return;
    }

    setState(() {
      _isSubscriptionAction = true;
    });

    try {
      UserServiceResult<String> result;
      
      if (_subscriptionStatus?.isActive == true) {
        // Se désabonner
        result = await _userService.unsubscribeFromCreator(widget.userId);
      } else {
        // S'abonner (sans paiement immédiat)
        result = await _userService.subscribeToCreator(widget.userId);
      }

      if (result.isSuccess) {
        // Afficher le message de succès
        _showSuccess(result.data ?? 'Action réussie');
        
        // Recharger le statut d'abonnement
        await _loadSubscriptionStatus();
      } else {
        _showError(result.error?.message ?? 'Erreur lors de l\'action');
      }
    } catch (e) {
      _showError('Erreur inattendue: $e');
    } finally {
      setState(() {
        _isSubscriptionAction = false;
      });
    }
  }

  /// Gère l'abonnement avec paiement
  Future<void> _handlePaymentSubscription() async {
    if (_profile == null || !_profile!.isCreator || _isSubscriptionAction) return;

    setState(() {
      _isSubscriptionAction = true;
    });

    try {
      final result = await _userService.subscribeWithPayment(widget.userId);
      
      if (result.isSuccess && result.data != null) {
        // Ici, on devrait intégrer Stripe pour finaliser le paiement
        // Pour l'instant, on montre juste le message
        final clientSecret = result.data!['client_secret'];
        _showSuccess('Paiement initié. Client Secret: $clientSecret');
        
        // Recharger le statut d'abonnement après paiement
        await _loadSubscriptionStatus();
      } else {
        _showError(result.error?.message ?? 'Erreur lors du paiement');
      }
    } catch (e) {
      _showError('Erreur lors du paiement: $e');
    } finally {
      setState(() {
        _isSubscriptionAction = false;
      });
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          widget.username ?? 'Profil',
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
        centerTitle: true,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoadingProfile) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.black),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              _error!,
              style: GoogleFonts.inter(
                fontSize: 16,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadProfile,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
              ),
              child: const Text('Réessayer'),
            ),
          ],
        ),
      );
    }

    if (_profile == null) {
      return const Center(child: Text('Profil non trouvé'));
    }

    return RefreshIndicator(
      onRefresh: _loadProfile,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildProfileHeader(),
            const SizedBox(height: 24),
            if (_profile!.isCreator) ...[
              _buildSubscriptionSection(),
              const SizedBox(height: 24),
            ],
            _buildBioSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader() {
    return Row(
      children: [
        // Avatar
        CircleAvatar(
          radius: 40,
          backgroundColor: Colors.grey[300],
          backgroundImage: _profile!.avatarUrl != null
              ? NetworkImage(_profile!.avatarUrl!)
              : null,
          child: _profile!.avatarUrl == null
              ? Icon(
                  Icons.person,
                  size: 40,
                  color: Colors.grey[600],
                )
              : null,
        ),
        const SizedBox(width: 16),
        
        // Informations utilisateur
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _profile!.displayName,
                style: GoogleFonts.inter(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: Colors.black,
                ),
              ),
              Text(
                '@${_profile!.username}',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 8),
              
              // Badge du rôle
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _profile!.isCreator 
                      ? Colors.purple.withOpacity(0.1) 
                      : Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _profile!.isCreator ? Colors.purple : Colors.blue,
                    width: 1,
                  ),
                ),
                child: Text(
                  _profile!.isCreator ? '✨ Créateur' : '👤 Abonné',
                  style: TextStyle(
                    fontSize: 12,
                    color: _profile!.isCreator ? Colors.purple : Colors.blue,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSubscriptionSection() {
    if (!_profile!.isCreator) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.star, color: Colors.amber[600], size: 20),
              const SizedBox(width: 8),
              Text(
                'Abonnement',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          if (_profile!.subscriptionPriceFormatted.isNotEmpty) ...[
            Text(
              _profile!.subscriptionPriceFormatted,
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Statut d'abonnement et boutons
          if (_isLoadingSubscription)
            const Center(child: CircularProgressIndicator(color: Colors.black))
          else
            _buildSubscriptionButtons(),
        ],
      ),
    );
  }

  Widget _buildSubscriptionButtons() {
    if (_subscriptionStatus == null) {
      // Statut inconnu, proposer l'abonnement
      return Column(
        children: [
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _isSubscriptionAction ? null : _handleSubscriptionAction,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: _isSubscriptionAction
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text('S\'abonner'),
            ),
          ),
        ],
      );
    }

    if (_subscriptionStatus!.isActive) {
      // Utilisateur abonné et actif
      return Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green),
            ),
            child: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Vous êtes abonné',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.green[800],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton(
              onPressed: _isSubscriptionAction ? null : _handleSubscriptionAction,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.red),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: _isSubscriptionAction
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.red),
                      ),
                    )
                  : const Text('Se désabonner'),
            ),
          ),
        ],
      );
    } else {
      // Utilisateur non abonné ou abonnement inactif
      return Column(
        children: [
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _isSubscriptionAction ? null : _handleSubscriptionAction,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: _isSubscriptionAction
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text('S\'abonner'),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton(
              onPressed: _isSubscriptionAction ? null : _handlePaymentSubscription,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.black,
                side: const BorderSide(color: Colors.black),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: _isSubscriptionAction
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                      ),
                    )
                  : const Text('S\'abonner avec paiement'),
            ),
          ),
        ],
      );
    }
  }

  Widget _buildBioSection() {
    if (_profile!.bio == null || _profile!.bio!.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline, color: Colors.grey[400], size: 20),
            const SizedBox(width: 8),
            Text(
              'Aucune bio disponible',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: Colors.grey[600],
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'À propos',
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _profile!.bio!,
          style: GoogleFonts.inter(
            fontSize: 14,
            color: Colors.grey[700],
            height: 1.5,
          ),
        ),
      ],
    );
  }
}