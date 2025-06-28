// Mise à jour du PostCreationProvider pour gérer les simulateurs

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/services.dart';
import '../services/post_creation_service.dart';
import '../models/post_models.dart';

/// États possibles pour la création de post
enum PostCreationState {
  initial,
  imageSelecting,
  imageSelected,
  uploading,
  success,
  error,
}

/// Provider pour la gestion de la création de posts
class PostCreationProvider extends ChangeNotifier {
  final PostCreationService _postCreationService = PostCreationService();
  final ImagePicker _imagePicker = ImagePicker();

  // État de la création
  PostCreationState _state = PostCreationState.initial;
  File? _selectedImage;
  String? _error;
  Post? _createdPost;

  // Contrôleurs de formulaire
  final TextEditingController titleController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();
  PostVisibility _selectedVisibility = PostVisibility.public;

  // Getters
  PostCreationState get state => _state;
  File? get selectedImage => _selectedImage;
  String? get error => _error;
  Post? get createdPost => _createdPost;
  PostVisibility get selectedVisibility => _selectedVisibility;
  bool get isLoading => _state == PostCreationState.uploading;
  bool get hasImage => _selectedImage != null;
  bool get canSubmit => hasImage && 
                       titleController.text.trim().isNotEmpty && 
                       descriptionController.text.trim().isNotEmpty &&
                       !isLoading;

  /// Détecte si on est sur un simulateur
  bool get _isSimulator {
    if (kIsWeb) return false;
    
    if (Platform.isIOS) {
      // Sur iOS, on peut détecter le simulateur via l'architecture
      return Platform.environment['SIMULATOR_DEVICE_NAME'] != null;
    }
    
    if (Platform.isAndroid) {
      // Sur Android, vérifier si c'est un émulateur
      return Platform.environment.containsKey('ANDROID_EMULATOR');
    }
    
    return false;
  }

  /// Met à jour l'état et notifie les listeners
  void _setState(PostCreationState newState) {
    _state = newState;
    notifyListeners();
  }

  /// Définit une erreur
  void _setError(String error) {
    _error = error;
    _setState(PostCreationState.error);
  }

  /// Sélectionne une image depuis la galerie
  Future<void> selectImageFromGallery() async {
    try {
      _setState(PostCreationState.imageSelecting);
      
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (image != null) {
        _selectedImage = File(image.path);
        _setState(PostCreationState.imageSelected);
      } else {
        _setState(PostCreationState.initial);
      }
    } on PlatformException catch (e) {
      debugPrint('❌ Platform error: ${e.code} - ${e.message}');
      _handleImagePickerError(e);
    } catch (e) {
      debugPrint('❌ Unexpected error: $e');
      _setError('Erreur inattendue lors de la sélection de l\'image');
    }
  }

  /// Sélectionne une image depuis la caméra
  Future<void> selectImageFromCamera() async {
    // Vérifier si on est sur simulateur
    if (_isSimulator) {
      _setError('La caméra n\'est pas disponible sur le simulateur.\nUtilisez la galerie ou testez sur un appareil physique.');
      return;
    }

    try {
      _setState(PostCreationState.imageSelecting);
      
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (image != null) {
        _selectedImage = File(image.path);
        _setState(PostCreationState.imageSelected);
      } else {
        _setState(PostCreationState.initial);
      }
    } on PlatformException catch (e) {
      debugPrint('❌ Platform error: ${e.code} - ${e.message}');
      _handleImagePickerError(e);
    } catch (e) {
      debugPrint('❌ Unexpected error: $e');
      _setError('Erreur inattendue lors de la prise de photo');
    }
  }

  /// Gère les erreurs de l'image picker
  void _handleImagePickerError(PlatformException e) {
    String errorMessage;
    switch (e.code) {
      case 'channel-error':
        errorMessage = 'Problème de configuration. Veuillez redémarrer l\'app.';
        break;
      case 'photo_access_denied':
        errorMessage = 'Accès aux photos refusé. Veuillez autoriser l\'accès dans les paramètres.';
        break;
      case 'camera_access_denied':
        errorMessage = 'Accès à la caméra refusé. Veuillez autoriser l\'accès dans les paramètres.';
        break;
      case 'no_available_camera':
        errorMessage = _isSimulator 
            ? 'Caméra non disponible sur simulateur.\nUtilisez la galerie ou un appareil physique.'
            : 'Aucune caméra disponible sur cet appareil.';
        break;
      default:
        errorMessage = 'Erreur: ${e.message ?? e.code}';
    }
    
    _setError(errorMessage);
  }

  /// Supprime l'image sélectionnée
  void removeSelectedImage() {
    _selectedImage = null;
    _setState(PostCreationState.initial);
  }

  /// Définit la visibilité du post
  void setVisibility(PostVisibility visibility) {
    _selectedVisibility = visibility;
    notifyListeners();
  }

  /// Crée le post
  Future<void> createPost() async {
    if (!canSubmit) return;

    try {
      _setState(PostCreationState.uploading);

      final result = await _postCreationService.createPost(
        title: titleController.text.trim(),
        description: descriptionController.text.trim(),
        imageFile: _selectedImage!,
        visibility: _selectedVisibility,
      );

      if (result.isSuccess && result.data != null) {
        _createdPost = result.data;
        _setState(PostCreationState.success);
      } else {
        _setError(result.error ?? 'Erreur lors de la création du post');
      }
    } catch (e) {
      _setError('Erreur inattendue: $e');
    }
  }

  /// Affiche un sélecteur d'image adapté à l'environnement
  Future<void> showImageSourceSelection(BuildContext context) async {
    return showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Sélectionner une image',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              
              // Options d'image
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Galerie (toujours disponible)
                  _buildImageSourceOption(
                    context: context,
                    icon: Icons.photo_library,
                    label: 'Galerie',
                    onTap: () {
                      Navigator.pop(context);
                      selectImageFromGallery();
                    },
                  ),
                  
                  // Caméra (avec indication si simulateur)
                  _buildImageSourceOption(
                    context: context,
                    icon: Icons.camera_alt,
                    label: _isSimulator ? 'Caméra\n(Indisponible)' : 'Caméra',
                    isEnabled: !_isSimulator,
                    onTap: _isSimulator ? null : () {
                      Navigator.pop(context);
                      selectImageFromCamera();
                    },
                  ),
                ],
              ),
              
              if (_isSimulator) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.orange[700], size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Simulateur détecté : la caméra n\'est pas disponible.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.orange[700],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  Widget _buildImageSourceOption({
    required BuildContext context,
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
    bool isEnabled = true,
  }) {
    return GestureDetector(
      onTap: isEnabled ? onTap : null,
      child: Container(
        width: 120,
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: isEnabled ? Colors.grey[100] : Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
          border: isEnabled ? null : Border.all(color: Colors.grey[300]!),
        ),
        child: Column(
          children: [
            Icon(
              icon, 
              size: 40, 
              color: isEnabled ? Colors.black : Colors.grey[400],
            ),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: isEnabled ? Colors.black : Colors.grey[400],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Remet à zéro le provider
  void reset() {
    _state = PostCreationState.initial;
    _selectedImage = null;
    _error = null;
    _createdPost = null;
    _selectedVisibility = PostVisibility.public;
    titleController.clear();
    descriptionController.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    titleController.dispose();
    descriptionController.dispose();
    super.dispose();
  }
}