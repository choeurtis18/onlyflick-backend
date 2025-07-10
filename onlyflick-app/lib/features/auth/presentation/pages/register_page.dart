import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../auth_provider.dart';
import '../../models/auth_models.dart';
import 'dart:async';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;

  // ===== ÉTAT VALIDATION USERNAME =====
  Timer? _usernameDebounceTimer;
  String? _usernameValidationMessage;
  bool _isCheckingUsername = false;
  bool _isUsernameValid = false;

  @override
  void dispose() {
    // Retirer le listener avant disposal
    try {
      final authProvider = context.read<AuthProvider>();
      authProvider.removeListener(_onAuthStateChanged);
    } catch (e) {
      // Ignorer l'erreur si le provider n'est plus disponible
    }
    
    // ===== ANNULER TIMER AVANT DISPOSE =====
    _usernameDebounceTimer?.cancel();
    
    _firstNameController.dispose();
    _lastNameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    
    // Écouter les changements d'état d'authentification
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<AuthProvider>().addListener(_onAuthStateChanged);
      }
    });

    // ===== ÉCOUTER CHANGEMENTS USERNAME =====
    _usernameController.addListener(_onUsernameChanged);
  }

  void _onAuthStateChanged() {
    // Vérifier si le widget est toujours monté
    if (!mounted) return;
    
    final authProvider = context.read<AuthProvider>();
    
    if (authProvider.isAuthenticated) {
      // Navigation vers la page principale si connecté
      context.goNamed('main');
    } else if (authProvider.hasError) {
      // Afficher l'erreur
      _showErrorSnackBar(authProvider.error!.message);
    }
    
    // Mettre à jour l'état de chargement
    setState(() {
      _isLoading = authProvider.isLoading;
    });
  }

  // ===== VALIDATION USERNAME EN TEMPS RÉEL =====
  void _onUsernameChanged() {
    final username = _usernameController.text.trim();
    
    // Annuler le timer précédent
    _usernameDebounceTimer?.cancel();
    
    // Validation côté client d'abord
    final clientValidation = _validateUsernameFormat(username);
    if (clientValidation != null) {
      // ===== VÉRIFICATION MOUNTED =====
      if (mounted) {
        setState(() {
          _usernameValidationMessage = clientValidation;
          _isCheckingUsername = false;
          _isUsernameValid = false;
        });
      }
      return;
    }

    // Si validation client OK, vérifier disponibilité avec délai
    _usernameDebounceTimer = Timer(const Duration(milliseconds: 800), () {
      // ===== VÉRIFICATION MOUNTED DANS TIMER =====
      if (mounted) {
        _checkUsernameAvailability(username);
      }
    });
  }

  Future<void> _checkUsernameAvailability(String username) async {
    if (username.isEmpty || username.length < 3) return;
    
    // ===== VÉRIFICATION MOUNTED AVANT setState =====
    if (!mounted) return;
    
    setState(() {
      _isCheckingUsername = true;
      _usernameValidationMessage = 'Vérification...';
    });

    try {
      final authProvider = context.read<AuthProvider>();
      final isAvailable = await authProvider.checkUsernameAvailability(username);
      
      // ===== VÉRIFICATION MOUNTED APRÈS ASYNC =====
      if (!mounted) return;
      
      setState(() {
        _isCheckingUsername = false;
        if (isAvailable) {
          _usernameValidationMessage = '✓ Username disponible';
          _isUsernameValid = true;
        } else {
          _usernameValidationMessage = '✗ Username déjà pris';
          _isUsernameValid = false;
        }
      });
    } catch (e) {
      // ===== VÉRIFICATION MOUNTED APRÈS CATCH =====
      if (!mounted) return;
      
      setState(() {
        _isCheckingUsername = false;
        _usernameValidationMessage = 'Erreur de vérification';
        _isUsernameValid = false;
      });
    }
  }

  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showSuccessSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _submitRegister() async {
    if (!_formKey.currentState!.validate()) return;
    
    // Vérifier que le username est valide
    if (!_isUsernameValid) {
      _showErrorSnackBar('Veuillez choisir un username valide et disponible');
      return;
    }
    
    FocusScope.of(context).unfocus();
    
    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();
    final username = _usernameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    try {
      final authProvider = context.read<AuthProvider>();
      final success = await authProvider.register(firstName, lastName, username, email, password);

      // Vérifier mounted après appel async
      if (!mounted) return;

      if (success) {
        _showSuccessSnackBar('Inscription réussie ! Bienvenue @$username sur OnlyFlick !');
        // La navigation se fait automatiquement via _onAuthStateChanged
      }
      // Les erreurs sont gérées automatiquement via _onAuthStateChanged
      
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Une erreur inattendue s\'est produite');
      }
    }
  }

  String? _validateFirstName(String? value) {
    if (value == null || value.isEmpty) {
      return 'Le prénom est requis';
    }
    if (value.length < 2) {
      return 'Le prénom doit contenir au moins 2 caractères';
    }
    return null;
  }

  String? _validateLastName(String? value) {
    if (value == null || value.isEmpty) {
      return 'Le nom est requis';
    }
    if (value.length < 2) {
      return 'Le nom doit contenir au moins 2 caractères';
    }
    return null;
  }

  // ===== VALIDATION USERNAME =====
  String? _validateUsernameFormat(String? value) {
    if (value == null || value.isEmpty) {
      return 'Le username est requis';
    }
    
    // Utiliser la validation des modèles
    final request = RegisterRequest(
      firstName: 'temp',
      lastName: 'temp',
      username: value,
      email: 'temp@temp.com',
      password: 'temp123',
    );
    
    return request.validateUsername();
  }

  String? _validateUsername(String? value) {
    final formatError = _validateUsernameFormat(value);
    if (formatError != null) return formatError;
    
    // Vérifier que la vérification a été faite et est valide
    if (!_isUsernameValid && _usernameValidationMessage != 'Vérification...' && _usernameValidationMessage != null) {
      return 'Username non disponible ou invalide';
    }
    
    return null;
  }

  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'L\'email est requis';
    }
    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
      return 'Format d\'email invalide';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Le mot de passe est requis';
    }
    if (value.length < 6) {
      return 'Le mot de passe doit contenir au moins 6 caractères';
    }
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Veuillez confirmer votre mot de passe';
    }
    if (value != _passwordController.text) {
      return 'Les mots de passe ne correspondent pas';
    }
    return null;
  }

  // ===== WIDGET HELPER POUR CHAMP USERNAME =====
  Widget _buildUsernameField() {
    Color? helperTextColor;
    IconData? helperIcon;
    
    if (_isCheckingUsername) {
      helperTextColor = Colors.orange;
      helperIcon = null; // Pas d'icône pendant le chargement
    } else if (_isUsernameValid) {
      helperTextColor = Colors.green;
      helperIcon = Icons.check_circle;
    } else if (_usernameValidationMessage != null && _usernameValidationMessage != 'Vérification...') {
      helperTextColor = Colors.red;
      helperIcon = Icons.error;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: _usernameController,
          textInputAction: TextInputAction.next,
          enabled: !_isLoading,
          style: const TextStyle(color: Colors.black),
          decoration: _inputDecoration.copyWith(
            hintText: 'Username (ex: johndoe)',
            prefixIcon: const Icon(Icons.alternate_email, color: Colors.black54),
            suffixIcon: _isCheckingUsername 
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: Padding(
                      padding: EdgeInsets.all(12.0),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : helperIcon != null 
                    ? Icon(helperIcon, color: helperTextColor, size: 20)
                    : null,
          ),
          validator: _validateUsername,
        ),
        if (_usernameValidationMessage != null) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              if (_isCheckingUsername) ...[
                const SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(strokeWidth: 1.5),
                ),
                const SizedBox(width: 6),
              ] else if (helperIcon != null) ...[
                Icon(helperIcon, size: 14, color: helperTextColor),
                const SizedBox(width: 4),
              ],
              Expanded(
                child: Text(
                  _usernameValidationMessage!,
                  style: TextStyle(
                    fontSize: 12,
                    color: helperTextColor,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Consumer<AuthProvider>(
          builder: (context, authProvider, _) {
            return LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight),
                    child: IntrinsicHeight(
                      child: Form(
                        key: _formKey,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(height: 24),
                            
                            // Titre
                            Center(
                              child: Text(
                                'Créer un compte',
                                style: GoogleFonts.pacifico(
                                  fontSize: 32,
                                  color: Colors.black,
                                ),
                              ),
                            ),
                            const SizedBox(height: 48),

                            // Champ prénom
                            TextFormField(
                              controller: _firstNameController,
                              textInputAction: TextInputAction.next,
                              enabled: !_isLoading,
                              style: const TextStyle(color: Colors.black),
                              decoration: _inputDecoration.copyWith(
                                hintText: 'Prénom',
                                prefixIcon: const Icon(Icons.person_outline, color: Colors.black54),
                              ),
                              validator: _validateFirstName,
                            ),
                            const SizedBox(height: 16),

                            // Champ nom
                            TextFormField(
                              controller: _lastNameController,
                              textInputAction: TextInputAction.next,
                              enabled: !_isLoading,
                              style: const TextStyle(color: Colors.black),
                              decoration: _inputDecoration.copyWith(
                                hintText: 'Nom',
                                prefixIcon: const Icon(Icons.person_outline, color: Colors.black54),
                              ),
                              validator: _validateLastName,
                            ),
                            const SizedBox(height: 16),

                            // ===== CHAMP USERNAME AVEC VALIDATION TEMPS RÉEL =====
                            _buildUsernameField(),
                            const SizedBox(height: 16),

                            // Champ email
                            TextFormField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              enabled: !_isLoading,
                              style: const TextStyle(color: Colors.black),
                              decoration: _inputDecoration.copyWith(
                                hintText: 'Email',
                                prefixIcon: const Icon(Icons.email_outlined, color: Colors.black54),
                              ),
                              validator: _validateEmail,
                            ),
                            const SizedBox(height: 16),

                            // Champ mot de passe
                            TextFormField(
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              textInputAction: TextInputAction.next,
                              enabled: !_isLoading,
                              style: const TextStyle(color: Colors.black),
                              decoration: _inputDecoration.copyWith(
                                hintText: 'Mot de passe',
                                prefixIcon: const Icon(Icons.lock_outline, color: Colors.black54),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword ? Icons.visibility_off : Icons.visibility,
                                    color: Colors.black54,
                                  ),
                                  onPressed: () {
                                    if (mounted) {
                                      setState(() {
                                        _obscurePassword = !_obscurePassword;
                                      });
                                    }
                                  },
                                ),
                              ),
                              validator: _validatePassword,
                            ),
                            const SizedBox(height: 16),

                            // Champ confirmation mot de passe
                            TextFormField(
                              controller: _confirmPasswordController,
                              obscureText: _obscureConfirmPassword,
                              textInputAction: TextInputAction.done,
                              enabled: !_isLoading,
                              style: const TextStyle(color: Colors.black),
                              decoration: _inputDecoration.copyWith(
                                hintText: 'Confirmer le mot de passe',
                                prefixIcon: const Icon(Icons.lock_outline, color: Colors.black54),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscureConfirmPassword ? Icons.visibility_off : Icons.visibility,
                                    color: Colors.black54,
                                  ),
                                  onPressed: () {
                                    if (mounted) {
                                      setState(() {
                                        _obscureConfirmPassword = !_obscureConfirmPassword;
                                      });
                                    }
                                  },
                                ),
                              ),
                              validator: _validateConfirmPassword,
                              onFieldSubmitted: (_) => _submitRegister(),
                            ),
                            const SizedBox(height: 24),

                            // Bouton d'inscription
                            SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.black,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                onPressed: _isLoading ? null : _submitRegister,
                                child: _isLoading
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                        ),
                                      )
                                    : Text(
                                        'S\'inscrire',
                                        style: GoogleFonts.inter(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
                                        ),
                                      ),
                              ),
                            ),

                            const SizedBox(height: 20),

                            // Lien vers la connexion
                            GestureDetector(
                              onTap: _isLoading ? null : () {
                                if (mounted) {
                                  context.goNamed('login');
                                }
                              },
                              child: RichText(
                                text: TextSpan(
                                  text: 'Déjà un compte ? ',
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    color: Colors.black87,
                                  ),
                                  children: [
                                    TextSpan(
                                      text: 'Se connecter.',
                                      style: GoogleFonts.inter(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: _isLoading ? Colors.grey : Colors.black,
                                        decoration: TextDecoration.underline,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  InputDecoration get _inputDecoration => InputDecoration(
        hintStyle: const TextStyle(color: Colors.grey),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.black12),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.black12),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.black),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.grey),
        ),
      );
}