//lib/features/messaging/pages/chat_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../../core/providers/messaging_provider.dart';
import '../../../../core/models/message_models.dart';
import '../widgets/message_bubble.dart';
import '../widgets/typing_indicator.dart';
import '../../../../core/services/api_service.dart';

/// Page de chat premium pour OnlyFlick avec design moderne
class ChatPage extends StatefulWidget {
  final Conversation conversation;

  const ChatPage({
    super.key,
    required this.conversation,
  });

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> with TickerProviderStateMixin {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _messageFocusNode = FocusNode();
  
  // Animation controllers
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  
  // Gestion des indicateurs de frappe
  Timer? _typingTimer;
  bool _isTypingIndicatorSent = false;
  
  // ✅ NOUVEAU: Variables pour l'auto-scroll
  int _previousMessageCount = 0;
  StreamSubscription<MessagingProvider>? _messagingProviderSubscription;

  @override
  void initState() {
    super.initState();
    
    // Initialiser les animations
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic));
    
    // Démarrer les animations
    _fadeController.forward();
    _slideController.forward();
    
    // Charger les messages et connecter le WebSocket
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final messagingProvider = context.read<MessagingProvider>();
      
      try {
        // 1. D'abord charger les messages
        debugPrint('📋 ChatPage: Loading messages for conversation ${widget.conversation.id}...');
        await messagingProvider.loadMessages(widget.conversation.id);
        
        // 2. Puis connecter le WebSocket pour les messages temps réel
        debugPrint('🔌 ChatPage: Connecting WebSocket...');
        await _connectToWebSocket();
        
        // ✅ 3. Scroll vers le bas après le chargement initial
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollToBottom(animated: false); // Pas d'animation pour le chargement initial
        });
        
        // ✅ 4. Configurer le listener pour l'auto-scroll
        _setupMessageListener();
        
      } catch (e) {
        debugPrint('❌ ChatPage: Error in initialization: $e');
      }
    });
    
    // Écouter les changements de texte pour les indicateurs de frappe
    _messageController.addListener(_onTextChanged);
  }

  /// ✅ NOUVELLE MÉTHODE: Configure l'écoute des nouveaux messages pour auto-scroll
  void _setupMessageListener() {
    final messagingProvider = context.read<MessagingProvider>();
    _previousMessageCount = messagingProvider.activeMessages.length;
    
    debugPrint('📜 ChatPage: Setting up message listener (initial count: $_previousMessageCount)');
  }

  /// ✅ NOUVELLE MÉTHODE: Scroll automatique vers le bas
  void _scrollToBottom({bool animated = true}) {
    if (!_scrollController.hasClients) {
      debugPrint('📜 ChatPage: ScrollController has no clients, skipping scroll');
      return;
    }
    
    try {
      if (animated) {
        _scrollController.animateTo(
          0.0, // Position 0 car la liste est en reverse
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      } else {
        _scrollController.jumpTo(0.0);
      }
      debugPrint('📜 ChatPage: Scrolled to bottom (animated: $animated)');
    } catch (e) {
      debugPrint('❌ ChatPage: Error scrolling to bottom: $e');
    }
  }

  /// ✅ MÉTHODE MISE À JOUR: Détecte les nouveaux messages et scroll automatiquement
  void _checkForNewMessages(MessagingProvider messagingProvider) {
    final currentMessageCount = messagingProvider.activeMessages.length;
    
    if (currentMessageCount > _previousMessageCount) {
      debugPrint('📜 ChatPage: New message detected (${_previousMessageCount} -> $currentMessageCount)');
      
      // Scroll vers le bas après un petit délai pour laisser l'UI se mettre à jour
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted) {
            _scrollToBottom();
          }
        });
      });
    }
    
    _previousMessageCount = currentMessageCount;
  }

  /// Connecte le WebSocket à la conversation actuelle
  Future<void> _connectToWebSocket() async {
    try {
      debugPrint('🚀 ChatPage: Tentative de connexion WebSocket...');
      debugPrint('📋 ChatPage: ID de conversation: ${widget.conversation.id}');
      debugPrint('👤 ChatPage: Autre utilisateur: ${widget.conversation.otherUserDisplayName}');
      
      final messagingProvider = context.read<MessagingProvider>();
      
      // Vérifier si on a un ID de conversation valide
      if (widget.conversation.id <= 0) {
        debugPrint('❌ ChatPage: ID de conversation invalide: ${widget.conversation.id}');
        return;
      }
      
      // Se connecter au WebSocket pour cette conversation spécifique
      await messagingProvider.connectToConversation(widget.conversation.id);
      
      debugPrint('✅ ChatPage: WebSocket connecté à la conversation ${widget.conversation.id}');
      
      // Petite pause puis vérifier l'état
      await Future.delayed(const Duration(milliseconds: 500));
      debugPrint('🔍 ChatPage: État WebSocket après connexion: ${messagingProvider.isWebSocketConnected}');
      
    } catch (e) {
      debugPrint('❌ ChatPage: Erreur connexion WebSocket: $e');
      
      // Afficher un snackbar en cas d'erreur
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Connexion temps réel indisponible: $e'),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    debugPrint('🧹 ChatPage: Disposing...');
    
    _messageController.removeListener(_onTextChanged);
    _messageController.dispose();
    _scrollController.dispose();
    _messageFocusNode.dispose();
    _typingTimer?.cancel();
    _fadeController.dispose();
    _slideController.dispose();
    
    // ✅ NOUVEAU: Nettoyer le subscription
    _messagingProviderSubscription?.cancel();
    
    // Nettoyer l'état de frappe
    _isTypingIndicatorSent = false;
    
    // Nettoyer la connexion WebSocket si on quitte la page
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        final messagingProvider = context.read<MessagingProvider>();
        messagingProvider.clearActiveConversation();
      } catch (e) {
        debugPrint('⚠️ ChatPage: Could not clear active conversation: $e');
      }
    });
    
    debugPrint('✅ ChatPage: Disposed');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      // AppBar avec design premium
      appBar: _buildPremiumAppBar(theme),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: Column(
            children: [
              // Zone des messages
              Expanded(
                child: Consumer<MessagingProvider>(
                  builder: (context, messagingProvider, child) {
                    // ✅ NOUVEAU: Vérifier les nouveaux messages pour auto-scroll
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      _checkForNewMessages(messagingProvider);
                    });
                    
                    return _buildMessagesSection(messagingProvider, theme);
                  },
                ),
              ),
              
              // Zone de saisie des messages avec design premium
              _buildMessageInputSection(theme),
              
              // Erreur d'envoi
              _buildErrorSection(),
            ],
          ),
        ),
      ),
    );
  }

  /// AppBar avec design premium OnlyFlick
  PreferredSizeWidget _buildPremiumAppBar(ThemeData theme) {
    return AppBar(
      elevation: 0,
      backgroundColor: Colors.white,
      systemOverlayStyle: SystemUiOverlayStyle.dark,
      leading: IconButton(
        onPressed: () => Navigator.of(context).pop(),
        icon: Container(
          decoration: BoxDecoration(
            color: theme.primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.all(8),
          child: Icon(
            Icons.arrow_back_ios_new,
            color: theme.primaryColor,
            size: 18,
          ),
        ),
      ),
      title: Row(
        children: [
          // Avatar de l'autre utilisateur avec effet de glow
          Hero(
            tag: 'avatar_${widget.conversation.id}',
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: theme.primaryColor.withOpacity(0.3),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: CircleAvatar(
                radius: 20,
                backgroundColor: theme.primaryColor,
                backgroundImage: widget.conversation.otherUserAvatar != null
                    ? NetworkImage(widget.conversation.otherUserAvatar!)
                    : null,
                child: widget.conversation.otherUserAvatar == null
                    ? Text(
                        _getInitials(widget.conversation.otherUserDisplayName),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : null,
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Informations utilisateur
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.conversation.otherUserDisplayName,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A1A1A),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                if (widget.conversation.otherUserUsername != null)
                  Text(
                    '@${widget.conversation.otherUserUsername}',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w400,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        // Indicateur de connexion WebSocket
        Consumer<MessagingProvider>(
          builder: (context, messagingProvider, child) {
            return Container(
              margin: const EdgeInsets.only(right: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: messagingProvider.isWebSocketConnected 
                          ? Colors.green 
                          : Colors.red,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    messagingProvider.isWebSocketConnected ? 'En ligne' : 'Hors ligne',
                    style: const TextStyle(
                      fontSize: 10,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        
        // Bouton debug WebSocket (temporaire)
        Container(
          margin: const EdgeInsets.only(right: 8),
          child: IconButton(
            onPressed: () async {
              debugPrint('🔧 ChatPage: Manual WebSocket reconnection...');
              final messagingProvider = context.read<MessagingProvider>();
              
              // Déconnecter puis reconnecter
              await messagingProvider.disconnectFromConversation();
              await Future.delayed(const Duration(milliseconds: 500));
              await messagingProvider.connectToConversation(widget.conversation.id);
              
              debugPrint('🔧 ChatPage: Manual reconnection completed');
            },
            icon: Container(
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.all(8),
              child: const Icon(
                Icons.wifi_tethering,
                color: Colors.orange,
                size: 16,
              ),
            ),
          ),
        ),
        
        // Bouton rafraîchir avec style moderne
        Container(
          margin: const EdgeInsets.only(right: 16),
          child: IconButton(
            onPressed: () {
              HapticFeedback.lightImpact();
              debugPrint('🔄 ChatPage: Manual refresh triggered');
              context.read<MessagingProvider>().loadMessages(widget.conversation.id);
            },
            icon: Container(
              decoration: BoxDecoration(
                color: theme.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.all(8),
              child: Icon(
                Icons.refresh_rounded,
                color: theme.primaryColor,
                size: 20,
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Section des messages avec gestion des états
  Widget _buildMessagesSection(MessagingProvider messagingProvider, ThemeData theme) {
    // Chargement initial
    if (messagingProvider.isLoadingMessages && 
        messagingProvider.activeMessages.isEmpty) {
      return _buildLoadingState();
    }

    // Erreur de chargement
    if (messagingProvider.messagesError != null && 
        messagingProvider.activeMessages.isEmpty) {
      return _buildErrorState(messagingProvider);
    }

    // Aucun message
    if (messagingProvider.activeMessages.isEmpty) {
      return _buildEmptyState();
    }

    // Liste des messages
    return _buildMessagesList(messagingProvider);
  }

  /// État de chargement avec animation
  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 20,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: const CircularProgressIndicator(
              strokeWidth: 3,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Chargement des messages...',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  /// État d'erreur avec design moderne
  Widget _buildErrorState(MessagingProvider messagingProvider) {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(32),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 20,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.error_outline_rounded,
                size: 48,
                color: Colors.red[400],
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Oups !',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              messagingProvider.messagesError!.message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                HapticFeedback.lightImpact();
                messagingProvider.loadMessages(widget.conversation.id);
              },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25),
                ),
              ),
              child: const Text(
                'Réessayer',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// État vide avec illustration
  Widget _buildEmptyState() {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Theme.of(context).primaryColor.withOpacity(0.1),
                    Theme.of(context).primaryColor.withOpacity(0.05),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.chat_bubble_outline_rounded,
                size: 64,
                color: Theme.of(context).primaryColor,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Commencez la conversation',
              style: TextStyle(
                color: Colors.grey[800],
                fontSize: 22,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Envoyez votre premier message pour\nentamer cette conversation premium',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 16,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Liste des messages avec indicateur de frappe
  Widget _buildMessagesList(MessagingProvider messagingProvider) {
    return RefreshIndicator(
      onRefresh: () => messagingProvider.loadMessages(widget.conversation.id),
      child: Column(
        children: [
          // Indicateur de chargement si refresh en cours
          if (messagingProvider.isLoadingMessages)
            Container(
              height: 3,
              child: const LinearProgressIndicator(),
            ),
          
          // Liste des messages avec indicateur de frappe
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              reverse: true, // Affichage en bas vers le haut
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: messagingProvider.activeMessages.length + _getTypingIndicatorCount(),
              itemBuilder: (context, index) {
                // Afficher d'abord l'indicateur de frappe si nécessaire
                if (index < _getTypingIndicatorCount()) {
                  return _buildTypingIndicator(messagingProvider);
                }
                
                // Index ajusté pour les messages
                final messageIndex = index - _getTypingIndicatorCount();
                final reversedIndex = messagingProvider.activeMessages.length - 1 - messageIndex;
                final message = messagingProvider.activeMessages[reversedIndex];
                
                // ✅ AMÉLIORATION: Filtrage plus strict des messages vides
                if (message.content.trim().isEmpty || message.content == "null" || message.content == "") {
                  debugPrint('⚠️ ChatPage: Empty message detected in UI! ID: ${message.id}, Content: "${message.content}"');
                  return const SizedBox.shrink(); // Ne pas afficher les messages vides
                }
                
                // Enrichir le message avec les données de la conversation si nécessaire
                final enrichedMessage = _enrichMessageWithConversationData(message);
                
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.only(bottom: 12),
                  child: MessageBubble(
                    message: enrichedMessage,
                    isCurrentUser: _isCurrentUserMessage(message),
                    showAvatar: _shouldShowAvatar(messagingProvider.activeMessages, reversedIndex),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Zone de saisie des messages avec design premium
  Widget _buildMessageInputSection(ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(
            color: Colors.grey[200]!,
            width: 0.5,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Consumer<MessagingProvider>(
            builder: (context, messagingProvider, child) {
              return Row(
                children: [
                  // Champ de saisie avec design moderne
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F6FA),
                        borderRadius: BorderRadius.circular(25),
                        border: Border.all(
                          color: _messageFocusNode.hasFocus 
                              ? theme.primaryColor.withOpacity(0.3)
                              : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: TextField(
                        controller: _messageController,
                        focusNode: _messageFocusNode,
                        decoration: InputDecoration(
                          hintText: 'Écrivez votre message...',
                          hintStyle: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 16,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 14,
                          ),
                          suffixIcon: messagingProvider.sendMessageError != null
                              ? Padding(
                                  padding: const EdgeInsets.only(right: 12),
                                  child: Icon(
                                    Icons.error_rounded,
                                    color: Colors.red[400],
                                    size: 20,
                                  ),
                                )
                              : null,
                        ),
                        maxLines: null,
                        textCapitalization: TextCapitalization.sentences,
                        style: const TextStyle(
                          fontSize: 16,
                          height: 1.4,
                          color: Color(0xFF1A1A1A), // Couleur de texte visible
                        ),
                        onSubmitted: (value) => _sendMessage(),
                        onChanged: (value) {
                          // Déclencher setState pour mettre à jour l'état du bouton
                          setState(() {});
                        },
                      ),
                    ),
                  ),
                  
                  const SizedBox(width: 12),
                  
                  // Bouton d'envoi avec animation
                  GestureDetector(
                    onTap: _messageController.text.trim().isNotEmpty && !messagingProvider.isSendingMessage
                        ? () {
                            HapticFeedback.lightImpact();
                            _sendMessage();
                          }
                        : null,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        gradient: _messageController.text.trim().isNotEmpty && !messagingProvider.isSendingMessage
                            ? LinearGradient(
                                colors: [theme.primaryColor, theme.primaryColor.withOpacity(0.8)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              )
                            : LinearGradient(
                                colors: [Colors.grey[300]!, Colors.grey[400]!],
                              ),
                        shape: BoxShape.circle,
                        boxShadow: _messageController.text.trim().isNotEmpty && !messagingProvider.isSendingMessage
                            ? [
                                BoxShadow(
                                  color: theme.primaryColor.withOpacity(0.3),
                                  blurRadius: 8,
                                  spreadRadius: 1,
                                ),
                              ]
                            : [],
                      ),
                      child: messagingProvider.isSendingMessage
                          ? const Center(
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              ),
                            )
                          : const Icon(
                              Icons.send_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  /// Section d'erreur d'envoi
  Widget _buildErrorSection() {
    return Consumer<MessagingProvider>(
      builder: (context, messagingProvider, child) {
        if (messagingProvider.sendMessageError != null) {
          return AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.red[50],
              border: Border(
                top: BorderSide(color: Colors.red[200]!, width: 1),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.error_outline_rounded, color: Colors.red[600], size: 18),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    messagingProvider.sendMessageError!.message,
                    style: TextStyle(
                      color: Colors.red[700],
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    _sendMessage();
                  },
                  child: Text(
                    'Réessayer',
                    style: TextStyle(
                      color: Colors.red[600],
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          );
        }
        return const SizedBox.shrink();
      },
    );
  }

  /// ✅ MÉTHODE MISE À JOUR: Envoie un message avec auto-scroll et meilleure gestion d'erreurs
  Future<void> _sendMessage() async {
    final content = _messageController.text.trim();
    
    // ✅ PROTECTION RENFORCÉE: Ne pas envoyer de messages vides
    if (content.isEmpty || content == "" || content == "null") {
      debugPrint('📤 ChatPage: Cannot send empty message');
      return;
    }
    
    debugPrint('📤 ChatPage: Sending message: "$content" (length: ${content.length})');
    
    final messagingProvider = context.read<MessagingProvider>();
    
    try {
      // Effacer le champ de texte immédiatement pour un feedback instantané
      final messageCopy = content;
      _messageController.clear();
      
      // ✅ Arrêter l'indicateur de frappe immédiatement
      _stopTypingIndicator();
      
      // Envoyer le message
      debugPrint('📤 MessagingProvider: Sending message to conversation ${widget.conversation.id}...');
      final success = await messagingProvider.sendMessage(messageCopy);
      
      if (success) {
        debugPrint('✅ ChatPage: Message sent successfully');
        
        // ✅ Scroll vers le bas après l'envoi réussi
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollToBottom();
        });
        
        // Vibration légère pour confirmer l'envoi
        HapticFeedback.lightImpact();
        
      } else {
        debugPrint('❌ ChatPage: Failed to send message');
        
        // ✅ Restaurer le texte en cas d'erreur
        _messageController.text = messageCopy;
        
        // Afficher une erreur à l'utilisateur
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.error_outline, color: Colors.white, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Erreur lors de l\'envoi du message',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 3),
              action: SnackBarAction(
                label: 'Réessayer',
                textColor: Colors.white,
                onPressed: () {
                  _sendMessage(); // Réessayer l'envoi
                },
              ),
            ),
          );
        }
      }
      
    } catch (e) {
      debugPrint('❌ ChatPage: Error sending message: $e');
      
      // Restaurer le texte en cas d'erreur
      _messageController.text = content;
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur de connexion'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// ✅ NOUVELLE MÉTHODE: Arrête l'indicateur de frappe
  void _stopTypingIndicator() {
    if (_isTypingIndicatorSent) {
      _isTypingIndicatorSent = false;
      _typingTimer?.cancel();
      final messagingProvider = context.read<MessagingProvider>();
      messagingProvider.sendTypingIndicator(false);
      debugPrint('⌨️ ChatPage: Stopped typing indicator');
    }
  }

  /// Vérifie si le message est envoyé par l'utilisateur actuel
  bool _isCurrentUserMessage(Message message) {
    final currentUserId = ApiService().currentUserId;
    if (currentUserId == null) return false;
    return message.senderId == currentUserId;
  }

  /// Détermine si l'avatar doit être affiché pour ce message
  bool _shouldShowAvatar(List<Message> messages, int index) {
    if (index == 0) return true; // Premier message
    
    final currentMessage = messages[index];
    final previousMessage = messages[index - 1];
    
    // Afficher l'avatar si l'expéditeur est différent du message précédent
    return currentMessage.senderId != previousMessage.senderId;
  }

  /// Génère les initiales à partir d'un nom
  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    } else if (parts.isNotEmpty) {
      return parts[0][0].toUpperCase();
    }
    return '?';
  }

  /// Gère les changements de texte pour les indicateurs de frappe
  void _onTextChanged() {
    final hasText = _messageController.text.trim().isNotEmpty;
    final messagingProvider = context.read<MessagingProvider>();
    
    // Protection contre les déclenchements trop fréquents
    if (hasText != _isTypingIndicatorSent) {
      debugPrint('⌨️ ChatPage: Text changed, hasText: $hasText, currentlySent: $_isTypingIndicatorSent');
      
      if (hasText && !_isTypingIndicatorSent) {
        // Commencer à taper
        _isTypingIndicatorSent = true;
        messagingProvider.sendTypingIndicator(true);
        debugPrint('⌨️ ChatPage: Started typing indicator');
      } else if (!hasText && _isTypingIndicatorSent) {
        // Arrêter de taper
        _isTypingIndicatorSent = false;
        messagingProvider.sendTypingIndicator(false);
        debugPrint('⌨️ ChatPage: Stopped typing indicator');
      }
      
      // Réinitialiser le timer pour arrêter l'indicateur automatiquement
      if (hasText) {
        _typingTimer?.cancel();
        _typingTimer = Timer(const Duration(seconds: 2), () {
          if (_isTypingIndicatorSent) {
            _isTypingIndicatorSent = false;
            messagingProvider.sendTypingIndicator(false);
            debugPrint('⌨️ ChatPage: Auto-stopped typing indicator');
          }
        });
      }
    }
  }

  /// Compte le nombre d'indicateurs de frappe à afficher
  int _getTypingIndicatorCount() {
    final messagingProvider = context.read<MessagingProvider>();
    final typingUsers = messagingProvider.getTypingUsers(widget.conversation.id);
    return typingUsers.isNotEmpty ? 1 : 0;
  }

  /// Enrichit un message avec les données de la conversation pour afficher les vrais noms/avatars
  Message _enrichMessageWithConversationData(Message originalMessage) {
    final currentUserId = ApiService().currentUserId;
    
    // Si c'est un message de l'utilisateur actuel, pas besoin d'enrichir
    if (currentUserId != null && originalMessage.senderId == currentUserId) {
      return originalMessage;
    }
    
    // Si les données utilisateur sont déjà présentes et valides, pas besoin d'enrichir
    if (originalMessage.senderFirstName != null && 
        originalMessage.senderFirstName!.isNotEmpty &&
        originalMessage.senderLastName != null && 
        originalMessage.senderLastName!.isNotEmpty) {
      return originalMessage;
    }
    
    // Enrichir avec les données de la conversation
    return Message(
      id: originalMessage.id,
      conversationId: originalMessage.conversationId,
      senderId: originalMessage.senderId,
      content: originalMessage.content,
      createdAt: originalMessage.createdAt,
      updatedAt: originalMessage.updatedAt,
      // Utiliser les données de la conversation
      senderUsername: widget.conversation.otherUserUsername,
      senderFirstName: widget.conversation.otherUserFirstName,
      senderLastName: widget.conversation.otherUserLastName,
      senderAvatar: widget.conversation.otherUserAvatar,
    );
  }

  /// Construit l'indicateur de frappe
  Widget _buildTypingIndicator(MessagingProvider messagingProvider) {
    final typingUsers = messagingProvider.getTypingUsers(widget.conversation.id);
    final currentUserId = ApiService().currentUserId;
    
    // Exclure l'utilisateur actuel des indicateurs de frappe
    final otherTypingUsers = typingUsers.where((userId) => userId != currentUserId).toSet();
    
    if (otherTypingUsers.isEmpty) {
      return const SizedBox.shrink();
    }

    // Utiliser le vrai nom de l'autre utilisateur depuis la conversation
    String displayName = widget.conversation.otherUserDisplayName;
    
    // Si on a les informations complètes, les utiliser
    if (widget.conversation.otherUserFirstName != null && 
        widget.conversation.otherUserFirstName!.isNotEmpty &&
        widget.conversation.otherUserLastName != null && 
        widget.conversation.otherUserLastName!.isNotEmpty) {
      displayName = '${widget.conversation.otherUserFirstName} ${widget.conversation.otherUserLastName}';
    } else if (widget.conversation.otherUserUsername != null && 
               widget.conversation.otherUserUsername!.isNotEmpty) {
      displayName = widget.conversation.otherUserUsername!;
    }

    return TypingIndicator(
      userDisplayName: displayName,
      avatarUrl: widget.conversation.otherUserAvatar,
      showAvatar: true,
    );
  }
}