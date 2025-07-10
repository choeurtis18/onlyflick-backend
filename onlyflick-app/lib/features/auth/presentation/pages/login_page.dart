import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; 
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../auth_provider.dart';
import '../../models/auth_models.dart';
import '../../../../debug/ios_network_debug.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  
  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    try {
      final authProvider = context.read<AuthProvider>();
      authProvider.removeListener(_onAuthStateChanged);
    } catch (e) {
      // Ignorer l'erreur si le provider n'est plus disponible
    }
    
    _emailController.dispose();
    _passwordController.dispose();
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
  }

  void _onAuthStateChanged() {
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

  Future<void> _submitLogin() async {
    if (!_formKey.currentState!.validate()) return;
    
    FocusScope.of(context).unfocus();
    
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    try {
      final authProvider = context.read<AuthProvider>();
      final success = await authProvider.login(email, password);

      if (!mounted) return;

      if (success) {
        _showSuccessSnackBar('Connexion réussie !');
        // La navigation se fait automatiquement via _onAuthStateChanged
      }
      // Les erreurs sont gérées automatiquement via _onAuthStateChanged
      
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Une erreur inattendue s\'est produite');
      }
    }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: kDebugMode ? AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        
        actions: [
          IconButton(
            icon: Icon(Icons.network_check, color: Colors.red),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => IOSNetworkDebugPage()),
              );
            },
            tooltip: 'Debug Réseau iOS',
          ),
        ],
      ) : null,
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
                            
                        
                            
                            // Logo et titre
                            Center(
                              child: Text(
                                'OnlyFlick',
                                style: GoogleFonts.pacifico(
                                  fontSize: 36,
                                  color: Colors.black,
                                ),
                              ),
                            ),
                            const SizedBox(height: 48),

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
                              textInputAction: TextInputAction.done,
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
                                    setState(() {
                                      _obscurePassword = !_obscurePassword;
                                    });
                                  },
                                ),
                              ),
                              validator: _validatePassword,
                              onFieldSubmitted: (_) => _submitLogin(),
                            ),

                            const SizedBox(height: 12),
                            
                            // Mot de passe oublié
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: _isLoading ? null : () {
                                  // TODO: Implémenter le mot de passe oublié
                                  _showErrorSnackBar('Fonctionnalité à venir');
                                },
                                style: TextButton.styleFrom(padding: EdgeInsets.zero),
                                child: Text(
                                  'Mot de passe oublié ?',
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    color: _isLoading ? Colors.grey : Colors.black87,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(height: 16),
                            
                            // Bouton de connexion
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
                                onPressed: _isLoading ? null : _submitLogin,
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
                                        'Se connecter',
                                        style: GoogleFonts.inter(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
                                        ),
                                      ),
                              ),
                            ),

                            const SizedBox(height: 28),

                            // Divider
                            Row(
                              children: [
                                const Expanded(child: Divider(thickness: 1)),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  child: Text(
                                    'ou',
                                    style: GoogleFonts.inter(fontSize: 13),
                                  ),
                                ),
                                const Expanded(child: Divider(thickness: 1)),
                              ],
                            ),

                            const SizedBox(height: 20),

                            // Lien vers l'inscription
                            GestureDetector(
                              onTap: _isLoading ? null : () {
                                context.goNamed('register');
                              },
                              child: RichText(
                                text: TextSpan(
                                  text: 'Pas de compte ? ',
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    color: Colors.black87,
                                  ),
                                  children: [
                                    TextSpan(
                                      text: 'S\'inscrire.',
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
      // 🔥 AJOUTÉ: Bouton flottant de debug (alternative)
      floatingActionButton: kDebugMode ? FloatingActionButton.small(
        backgroundColor: Colors.red,
        heroTag: 'debug_network',
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => IOSNetworkDebugPage()),
          );
        },
        child: Icon(Icons.bug_report, color: Colors.white),
        tooltip: 'Debug Réseau iOS',
      ) : null,
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