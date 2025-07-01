// onlyflick-app/lib/features/messaging/widgets/new_conversation_dialog.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/providers/messaging_provider.dart';
import '../../../../core/models/message_models.dart';
import '../pages/chat_page.dart';
import '../../../../core/providers/messaging_provider.dart';
import '../../../../core/models/message_models.dart';


/// Dialogue pour créer une nouvelle conversation
class NewConversationDialog extends StatefulWidget {
  const NewConversationDialog({super.key});

  @override
  State<NewConversationDialog> createState() => _NewConversationDialogState();
}

class _NewConversationDialogState extends State<NewConversationDialog> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  
  @override
  void initState() {
    super.initState();
    // Effacer les résultats de recherche précédents
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MessagingProvider>().clearSearchResults();
    });
    
    // Auto-focus sur le champ de recherche
    _searchFocusNode.requestFocus();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.7,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Titre
            Row(
              children: [
                const Icon(Icons.person_add, size: 24),
                const SizedBox(width: 8),
                const Text(
                  'Nouvelle conversation',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Champ de recherche
            TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              decoration: InputDecoration(
                hintText: 'Rechercher un utilisateur...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        onPressed: () {
                          _searchController.clear();
                          context.read<MessagingProvider>().clearSearchResults();
                          setState(() {});
                        },
                        icon: const Icon(Icons.clear),
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: (value) {
                setState(() {});
                if (value.trim().isNotEmpty) {
                  // Recherche avec debounce
                  Future.delayed(const Duration(milliseconds: 300), () {
                    if (_searchController.text == value && value.trim().isNotEmpty) {
                      context.read<MessagingProvider>().searchUsers(value);
                    }
                  });
                } else {
                  context.read<MessagingProvider>().clearSearchResults();
                }
              },
            ),
            
            const SizedBox(height: 16),
            
            // Résultats de recherche
            Expanded(
              child: Consumer<MessagingProvider>(
                builder: (context, messagingProvider, child) {
                  // État de chargement
                  if (messagingProvider.isSearchingUsers) {
                    return const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text('Recherche en cours...'),
                        ],
                      ),
                    );
                  }
                  
                  // Aucun terme de recherche
                  if (_searchController.text.trim().isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.search,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Saisissez un nom ou un email\npour rechercher des utilisateurs',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                  
                  // Aucun résultat trouvé
                  if (messagingProvider.searchResults.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.person_off,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Aucun utilisateur trouvé',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Essayez un autre terme de recherche',
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                  
                  // Liste des utilisateurs trouvés
                  return ListView.builder(
                    itemCount: messagingProvider.searchResults.length,
                    itemBuilder: (context, index) {
                      final user = messagingProvider.searchResults[index];
                      return _UserTile(
                        user: user,
                        onTap: () => _startConversation(context, user),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Démarre une conversation avec l'utilisateur sélectionné
  Future<void> _startConversation(BuildContext context, User user) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    
    // Afficher un indicateur de chargement
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );
    
    try {
      final messagingProvider = context.read<MessagingProvider>();
      final success = await messagingProvider.startConversation(user.id);
      
      // Fermer l'indicateur de chargement
      navigator.pop();
      
      if (success) {
        // Fermer le dialogue
        navigator.pop();
        
        // Créer une conversation temporaire pour navigation
        final tempConversation = Conversation(
          id: messagingProvider.activeConversationId!,
          user1Id: 0, // Sera mis à jour par le backend
          user2Id: user.id,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          otherUserUsername: user.username,
          otherUserFirstName: user.firstName,
          otherUserLastName: user.lastName,
          otherUserAvatar: user.avatar,
        );
        
        // Ouvrir la page de chat
        navigator.push(
          MaterialPageRoute(
            builder: (context) => ChatPage(conversation: tempConversation),
          ),
        );
      } else {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Impossible de créer la conversation'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      // Fermer l'indicateur de chargement en cas d'erreur
      navigator.pop();
      
      messenger.showSnackBar(
        SnackBar(
          content: Text('Erreur: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

/// Widget pour afficher un utilisateur dans les résultats de recherche
class _UserTile extends StatelessWidget {
  final User user;
  final VoidCallback onTap;

  const _UserTile({
    required this.user,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          radius: 20,
          backgroundColor: theme.primaryColor,
          backgroundImage: user.avatar != null
              ? NetworkImage(user.avatar!)
              : null,
          child: user.avatar == null
              ? Text(
                  user.initials,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                )
              : null,
        ),
        title: Text(
          user.displayName,
          style: const TextStyle(
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '@${user.username}',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 13,
              ),
            ),
            if (user.isCreator)
              Container(
                margin: const EdgeInsets.only(top: 4),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.amber[100],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber),
                ),
                child: const Text(
                  'Créateur',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: Colors.amber,
                  ),
                ),
              ),
          ],
        ),
        trailing: Icon(
          Icons.arrow_forward_ios,
          size: 16,
          color: Colors.grey[400],
        ),
      ),
    );
  }
}