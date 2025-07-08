import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/providers/post_creation_provider.dart';
import '../../../../core/models/post_models.dart';
import '../../../auth/auth_provider.dart';

class CreatePostPage extends StatefulWidget {
  const CreatePostPage({super.key});

  @override
  State<CreatePostPage> createState() => _CreatePostPageState();
}

class _CreatePostPageState extends State<CreatePostPage> {
  PostCreationProvider? _creationProvider;

  @override
  void dispose() {
    _creationProvider?.removeListener(_onCreationStateChanged);
    super.dispose();
  }

  void _initializeProvider(PostCreationProvider provider) {
    // Éviter d'initialiser plusieurs fois
    if (_creationProvider == provider) return;
    
    // Nettoyer l'ancien provider si nécessaire
    _creationProvider?.removeListener(_onCreationStateChanged);
    
    // Configurer le nouveau provider
    _creationProvider = provider;
    provider.addListener(_onCreationStateChanged);
    
    // Différer le reset après la fin du build pour éviter setState() pendant build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _creationProvider == provider) {
        provider.reset();
      }
    });
  }

  void _onCreationStateChanged() {
    if (_creationProvider == null) return;
    
    final state = _creationProvider!.state;
    
    switch (state) {
      case PostCreationState.success:
        _showSuccessSnackBar('Post créé avec succès !');
        Navigator.of(context).pop(true); // Retourner true pour indiquer le succès
        break;
      case PostCreationState.error:
        _showErrorSnackBar(_creationProvider!.error ?? 'Erreur inconnue');
        break;
      default:
        break;
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _handleCreatePost(PostCreationProvider provider) async {
    await provider.createPost();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => PostCreationProvider(),
      child: Consumer2<PostCreationProvider, AuthProvider>(
        builder: (context, creationProvider, authProvider, _) {
          // Initialiser le provider la première fois
          _initializeProvider(creationProvider);
          
          return Scaffold(
            backgroundColor: Colors.white,
            appBar: _buildAppBar(creationProvider),
            body: SafeArea(
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildUserHeader(authProvider),
                          const SizedBox(height: 20),
                          _buildImageSection(creationProvider),
                          const SizedBox(height: 20),
                          _buildTitleInput(creationProvider),
                          const SizedBox(height: 16),
                          _buildDescriptionInput(creationProvider),
                          const SizedBox(height: 20),
                          _buildTagsSelector(creationProvider), // ✅ Nouvelle section tags
                          const SizedBox(height: 20),
                          _buildVisibilitySelector(creationProvider, authProvider),
                        ],
                      ),
                    ),
                  ),
                  _buildBottomActions(creationProvider),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(PostCreationProvider provider) {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.close, color: Colors.black),
        onPressed: provider.isLoading 
            ? null 
            : () => Navigator.of(context).pop(),
      ),
      title: Text(
        'Nouveau post',
        style: GoogleFonts.inter(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: Colors.black,
        ),
      ),
      centerTitle: true,
      actions: [
        TextButton(
          onPressed: provider.canSubmit && !provider.isLoading
              ? () => _handleCreatePost(provider)
              : null,
          child: provider.isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                  ),
                )
              : Text(
                  'Publier',
                  style: TextStyle(
                    color: provider.canSubmit ? Colors.black : Colors.grey,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildUserHeader(AuthProvider authProvider) {
    final user = authProvider.user;
    
    return Row(
      children: [
        CircleAvatar(
          radius: 20,
          backgroundColor: Colors.grey[300],
          backgroundImage: user != null 
              ? NetworkImage('https://i.pravatar.cc/150?img=${user.id % 20}')
              : null,
          child: user == null 
              ? const Icon(Icons.person, color: Colors.grey)
              : null,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                user?.fullName ?? 'Utilisateur',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              if (user?.isCreator == true)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.purple.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.purple, width: 0.5),
                  ),
                  child: const Text(
                    'Créateur',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.purple,
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

  Widget _buildImageSection(PostCreationProvider provider) {
    return Container(
      width: double.infinity,
      height: 300,
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[300]!, width: 1),
      ),
      child: provider.hasImage
          ? _buildSelectedImage(provider)
          : _buildImageSelector(provider),
    );
  }

  Widget _buildSelectedImage(PostCreationProvider provider) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Image.file(
            provider.selectedImage!,
            width: double.infinity,
            height: double.infinity,
            fit: BoxFit.cover,
          ),
        ),
        Positioned(
          top: 12,
          right: 12,
          child: GestureDetector(
            onTap: provider.removeSelectedImage,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: Colors.black54,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.close,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ),
        Positioned(
          bottom: 12,
          right: 12,
          child: GestureDetector(
            onTap: () => provider.showImageSourceSelection(context),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: Colors.black54,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.edit,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildImageSelector(PostCreationProvider provider) {
    return GestureDetector(
      onTap: provider.state == PostCreationState.imageSelecting 
          ? null 
          : () => provider.showImageSourceSelection(context),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (provider.state == PostCreationState.imageSelecting)
            const CircularProgressIndicator(color: Colors.black)
          else ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Colors.black,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.add_a_photo,
                color: Colors.white,
                size: 32,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Ajouter une photo',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Touchez pour sélectionner depuis\nla galerie ou prendre une photo',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTitleInput(PostCreationProvider provider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Titre *',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: provider.titleController,
          enabled: !provider.isLoading,
          maxLength: 100,
          decoration: InputDecoration(
            hintText: 'Donnez un titre à votre post...',
            hintStyle: TextStyle(color: Colors.grey[500]),
            filled: true,
            fillColor: Colors.grey[50],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.black),
            ),
            counterText: '',
          ),
          style: const TextStyle(fontSize: 16),
          onChanged: (_) => provider.notifyListeners(),
        ),
      ],
    );
  }

  Widget _buildDescriptionInput(PostCreationProvider provider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Description',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: provider.descriptionController,
          enabled: !provider.isLoading,
          maxLines: 4,
          maxLength: 500,
          decoration: InputDecoration(
            hintText: 'Décrivez votre post...',
            hintStyle: TextStyle(color: Colors.grey[500]),
            filled: true,
            fillColor: Colors.grey[50],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.black),
            ),
            counterText: '',
            alignLabelWithHint: true,
          ),
          style: const TextStyle(fontSize: 16),
          onChanged: (_) => provider.notifyListeners(),
        ),
      ],
    );
  }

  // ===== NOUVELLE SECTION : SÉLECTEUR DE TAGS =====
  Widget _buildTagsSelector(PostCreationProvider provider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Tags *',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black,
              ),
            ),
            const SizedBox(width: 8),
            if (provider.selectedTagsCount > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${provider.selectedTagsCount}/5',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Choisissez des tags qui décrivent votre contenu (max 5)',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 12),
        
        // Tags sélectionnés (si il y en a)
        if (provider.selectedTags.isNotEmpty) ...[
          _buildSelectedTagsRow(provider),
          const SizedBox(height: 12),
        ],
        
        // Grille des tags disponibles
        _buildAvailableTagsGrid(provider),
      ],
    );
  }

  Widget _buildSelectedTagsRow(PostCreationProvider provider) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green[600], size: 16),
              const SizedBox(width: 6),
              Text(
                'Tags sélectionnés',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Colors.green[700],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: provider.selectedTags.map((tag) {
              return _buildSelectedTagChip(tag, provider);
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedTagChip(String tag, PostCreationProvider provider) {
    final displayName = PostCreationProvider.getTagDisplayName(tag);
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            displayName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: () => provider.removeTag(tag),
            child: const Icon(
              Icons.close,
              color: Colors.white,
              size: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvailableTagsGrid(PostCreationProvider provider) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: provider.availableTags.map((tag) {
        final isSelected = provider.isTagSelected(tag);
        final isDisabled = !isSelected && provider.isMaxTagsReached;
        
        return _buildTagChip(
          tag: tag,
          isSelected: isSelected,
          isDisabled: isDisabled,
          onTap: isDisabled ? null : () => provider.toggleTag(tag),
        );
      }).toList(),
    );
  }

  Widget _buildTagChip({
    required String tag,
    required bool isSelected,
    required bool isDisabled,
    required VoidCallback? onTap,
  }) {
    final displayName = PostCreationProvider.getTagDisplayName(tag);
    
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.black
              : isDisabled
                  ? Colors.grey[100]
                  : Colors.grey[50],
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? Colors.black
                : isDisabled
                    ? Colors.grey[300]!
                    : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSelected)
              const Padding(
                padding: EdgeInsets.only(right: 6),
                child: Icon(
                  Icons.check,
                  color: Colors.white,
                  size: 14,
                ),
              ),
            Text(
              displayName,
              style: TextStyle(
                color: isSelected
                    ? Colors.white
                    : isDisabled
                        ? Colors.grey[400]
                        : Colors.black,
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVisibilitySelector(PostCreationProvider provider, AuthProvider authProvider) {
    // Seuls les créateurs peuvent créer du contenu privé
    final canCreatePrivate = authProvider.user?.isCreator == true;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Visibilité',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 12),
        Column(
          children: PostVisibility.values.map((visibility) {
            final isEnabled = visibility == PostVisibility.public || canCreatePrivate;
            final isSelected = provider.selectedVisibility == visibility;
            
            return GestureDetector(
              onTap: isEnabled && !provider.isLoading 
                  ? () => provider.setVisibility(visibility)
                  : null,
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.black.withOpacity(0.05) : Colors.grey[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? Colors.black : Colors.grey[300]!,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      visibility.icon,
                      color: isEnabled 
                          ? (isSelected ? Colors.black : Colors.grey[600])
                          : Colors.grey[400],
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            visibility.displayName,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: isEnabled ? Colors.black : Colors.grey[400],
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            visibility.description,
                            style: TextStyle(
                              fontSize: 12,
                              color: isEnabled ? Colors.grey[600] : Colors.grey[400],
                            ),
                          ),
                          if (!isEnabled) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Réservé aux créateurs',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.orange[600],
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (isSelected)
                      const Icon(
                        Icons.check_circle,
                        color: Colors.black,
                        size: 20,
                      ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildBottomActions(PostCreationProvider provider) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Colors.black12, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: provider.isLoading 
                  ? null 
                  : () => Navigator.of(context).pop(),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.grey),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text(
                'Annuler',
                style: TextStyle(
                  color: Colors.grey,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: provider.canSubmit && !provider.isLoading
                  ? () => _handleCreatePost(provider)
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: provider.isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text(
                      'Publier',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}