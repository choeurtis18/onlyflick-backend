// lib/core/models/search_models.dart

// ===== ENUMS =====

/// Catégories de tags disponibles
enum TagCategory {
  art('art', 'Art', '🎨'),
  music('music', 'Musique', '🎵'),
  sport('sport', 'Sport', '⚽'),
  cinema('cinema', 'Cinéma', '🎬'),
  tech('tech', 'Tech', '💻'),
  fashion('fashion', 'Mode', '👗'),
  food('food', 'Cuisine', '🍳'),
  travel('travel', 'Voyage', '✈️'),
  gaming('gaming', 'Gaming', '🎮'),
  lifestyle('lifestyle', 'Lifestyle', '🏗️');

  const TagCategory(this.value, this.displayName, this.emoji);

  final String value;
  final String displayName;
  final String emoji;

  /// Retourne la catégorie depuis sa valeur string
  static TagCategory? fromString(String value) {
    try {
      return TagCategory.values.firstWhere((tag) => tag.value == value);
    } catch (e) {
      return null;
    }
  }

  /// Retourne toutes les catégories avec leurs détails
  static List<Map<String, dynamic>> get allWithDetails {
    return TagCategory.values
        .map((tag) => {
              'category': tag.value,
              'display_name': tag.displayName,
              'emoji': tag.emoji,
            })
        .toList();
  }
}

/// Types de tri pour les posts
enum SortType {
  relevance('relevance', 'Pertinence'),
  popular24h('popular_24h', 'Populaire 24h'),
  popularWeek('popular_week', 'Populaire semaine'),
  popularMonth('popular_month', 'Populaire mois'),
  recent('recent', 'Nouveautés');

  const SortType(this.value, this.displayName);

  final String value;
  final String displayName;

  static SortType? fromString(String value) {
    try {
      return SortType.values.firstWhere((sort) => sort.value == value);
    } catch (e) {
      return null;
    }
  }
}

/// Types d'interactions utilisateur
enum InteractionType {
  view('view'),
  like('like'),
  comment('comment'),
  share('share'),
  profileView('profile_view'),
  search('search'),
  tagClick('tag_click');

  const InteractionType(this.value);

  final String value;

  static InteractionType? fromString(String value) {
    try {
      return InteractionType.values.firstWhere((type) => type.value == value);
    } catch (e) {
      return null;
    }
  }
}

// ===== MODÈLES DE REQUÊTE =====

/// Requête de recherche
class SearchRequest {
  final String? query;
  final List<TagCategory> tags;
  final SortType sortBy;
  final int limit;
  final int offset;
  final String searchType; 

  const SearchRequest({
    this.query,
    this.tags = const [],
    this.sortBy = SortType.recent,
    this.limit = 20,
    this.offset = 0,
    this.searchType = 'posts',
  });

  Map<String, dynamic> toJson() => {
        if (query != null) 'query': query,
        if (tags.isNotEmpty) 'tags': tags.map((tag) => tag.value).toList(),
        'sort_by': sortBy.value,
        'limit': limit,
        'offset': offset,
        'search_type': searchType,
      };

  SearchRequest copyWith({
    String? query,
    List<TagCategory>? tags,
    SortType? sortBy,
    int? limit,
    int? offset,
    String? searchType,
  }) {
    return SearchRequest(
      query: query ?? this.query,
      tags: tags ?? this.tags,
      sortBy: sortBy ?? this.sortBy,
      limit: limit ?? this.limit,
      offset: offset ?? this.offset,
      searchType: searchType ?? this.searchType,
    );
  }

  @override
  String toString() => 'SearchRequest(query: $query, tags: ${tags.length}, sortBy: $sortBy)';
}

/// Requête pour le feed de découverte
class DiscoveryRequest {
  final List<TagCategory> tags;
  final SortType sortBy;
  final int limit;
  final int offset;

  const DiscoveryRequest({
    this.tags = const [],
    this.sortBy = SortType.relevance,
    this.limit = 20,
    this.offset = 0,
  });

  Map<String, dynamic> toJson() => {
        if (tags.isNotEmpty) 'tags': tags.map((tag) => tag.value).toList(),
        'sort': sortBy.value,
        'limit': limit,
        'offset': offset,
      };

  DiscoveryRequest copyWith({
    List<TagCategory>? tags,
    SortType? sortBy,
    int? limit,
    int? offset,
  }) {
    return DiscoveryRequest(
      tags: tags ?? this.tags,
      sortBy: sortBy ?? this.sortBy,
      limit: limit ?? this.limit,
      offset: offset ?? this.offset,
    );
  }
}

// ===== MODÈLES DE DONNÉES =====

/// Utilisateur dans les résultats de recherche
class UserSearchResult {
  final int id;
  final String username;
  final String firstName;
  final String lastName;
  final String? avatarUrl;
  final String? bio;
  final String role;
  final int followersCount;
  final int postsCount;
  final bool isFollowing;
  final int mutualFollowers;

  const UserSearchResult({
    required this.id,
    required this.username,
    required this.firstName,
    required this.lastName,
    this.avatarUrl,
    this.bio,
    required this.role,
    required this.followersCount,
    required this.postsCount,
    required this.isFollowing,
    required this.mutualFollowers,
  });

  factory UserSearchResult.fromJson(Map<String, dynamic> json) {
    return UserSearchResult(
      id: json['id'] ?? 0,
      username: json['username'] ?? '',
      firstName: json['first_name'] ?? '',
      lastName: json['last_name'] ?? '',
      avatarUrl: json['avatar_url'],
      bio: json['bio'],
      role: json['role'] ?? 'subscriber',
      followersCount: json['followers_count'] ?? 0,
      postsCount: json['posts_count'] ?? 0,
      isFollowing: json['is_following'] ?? false,
      mutualFollowers: json['mutual_followers'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'username': username,
        'first_name': firstName,
        'last_name': lastName,
        if (avatarUrl != null) 'avatar_url': avatarUrl,
        if (bio != null) 'bio': bio,
        'role': role,
        'followers_count': followersCount,
        'posts_count': postsCount,
        'is_following': isFollowing,
        'mutual_followers': mutualFollowers,
      };

  String get fullName => '$firstName $lastName';
  String get displayName => '@$username';
  bool get isCreator => role == 'creator';

  UserSearchResult copyWith({
    int? id,
    String? username,
    String? firstName,
    String? lastName,
    String? avatarUrl,
    String? bio,
    String? role,
    int? followersCount,
    int? postsCount,
    bool? isFollowing,
    int? mutualFollowers,
  }) {
    return UserSearchResult(
      id: id ?? this.id,
      username: username ?? this.username,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      bio: bio ?? this.bio,
      role: role ?? this.role,
      followersCount: followersCount ?? this.followersCount,
      postsCount: postsCount ?? this.postsCount,
      isFollowing: isFollowing ?? this.isFollowing,
      mutualFollowers: mutualFollowers ?? this.mutualFollowers,
    );
  }

  @override
  String toString() => 'UserSearchResult(id: $id, username: $username, role: $role)';
}

/// Post avec détails étendus pour la recherche
class PostWithDetails {
  final int id;
  final int userId;
  final String title;
  final String description;
  final String mediaUrl;
  final String? fileId;
  final String visibility;
  final DateTime createdAt;
  final DateTime updatedAt;
  final UserSearchResult author;
  final List<TagCategory> tags;
  final int likesCount;
  final int commentsCount;
  final int viewsCount;
  final bool isLiked;
  final double popularityScore;
  final double relevanceScore;

  const PostWithDetails({
    required this.id,
    required this.userId,
    required this.title,
    required this.description,
    required this.mediaUrl,
    this.fileId,
    required this.visibility,
    required this.createdAt,
    required this.updatedAt,
    required this.author,
    required this.tags,
    required this.likesCount,
    required this.commentsCount,
    required this.viewsCount,
    required this.isLiked,
    required this.popularityScore,
    required this.relevanceScore,
  });

  factory PostWithDetails.fromJson(Map<String, dynamic> json) {
    return PostWithDetails(
      id: json['id'] ?? 0,
      userId: json['user_id'] ?? 0,
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      mediaUrl: json['media_url'] ?? '',
      fileId: json['file_id'],
      visibility: json['visibility'] ?? 'public',
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updated_at'] ?? '') ?? DateTime.now(),
      author: UserSearchResult.fromJson(json['author'] ?? {}),
      tags: (json['tags'] as List? ?? [])
          .map((tag) => TagCategory.fromString(tag.toString()))
          .where((tag) => tag != null)
          .cast<TagCategory>()
          .toList(),
      likesCount: json['likes_count'] ?? 0,
      commentsCount: json['comments_count'] ?? 0,
      viewsCount: json['views_count'] ?? 0,
      isLiked: json['is_liked'] ?? false,
      popularityScore: (json['popularity_score'] ?? 0.0).toDouble(),
      relevanceScore: (json['relevance_score'] ?? 0.0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'title': title,
        'description': description,
        'media_url': mediaUrl,
        if (fileId != null) 'file_id': fileId,
        'visibility': visibility,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
        'author': author.toJson(),
        'tags': tags.map((tag) => tag.value).toList(),
        'likes_count': likesCount,
        'comments_count': commentsCount,
        'views_count': viewsCount,
        'is_liked': isLiked,
        'popularity_score': popularityScore,
        'relevance_score': relevanceScore,
      };

  bool get isPublic => visibility == 'public';
  bool get isSubscriberOnly => visibility == 'subscriber';
  String get timeAgo => _getTimeAgo(createdAt);

  PostWithDetails copyWith({
    int? id,
    int? userId,
    String? title,
    String? description,
    String? mediaUrl,
    String? fileId,
    String? visibility,
    DateTime? createdAt,
    DateTime? updatedAt,
    UserSearchResult? author,
    List<TagCategory>? tags,
    int? likesCount,
    int? commentsCount,
    int? viewsCount,
    bool? isLiked,
    double? popularityScore,
    double? relevanceScore,
  }) {
    return PostWithDetails(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      description: description ?? this.description,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      fileId: fileId ?? this.fileId,
      visibility: visibility ?? this.visibility,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      author: author ?? this.author,
      tags: tags ?? this.tags,
      likesCount: likesCount ?? this.likesCount,
      commentsCount: commentsCount ?? this.commentsCount,
      viewsCount: viewsCount ?? this.viewsCount,
      isLiked: isLiked ?? this.isLiked,
      popularityScore: popularityScore ?? this.popularityScore,
      relevanceScore: relevanceScore ?? this.relevanceScore,
    );
  }

  @override
  String toString() => 'PostWithDetails(id: $id, title: $title, author: ${author.username})';
}

/// Résultat de recherche
class SearchResult {
  final List<PostWithDetails> posts;
  final List<UserSearchResult> users;
  final int total;
  final bool hasMore;

  const SearchResult({
    required this.posts,
    required this.users,
    required this.total,
    required this.hasMore,
  });

  factory SearchResult.fromJson(Map<String, dynamic> json) {
    return SearchResult(
      posts: (json['posts'] as List? ?? [])
          .map((post) => PostWithDetails.fromJson(post))
          .toList(),
      users: (json['users'] as List? ?? [])
          .map((user) => UserSearchResult.fromJson(user))
          .toList(),
      total: json['total'] ?? 0,
      hasMore: json['has_more'] ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'posts': posts.map((post) => post.toJson()).toList(),
        'users': users.map((user) => user.toJson()).toList(),
        'total': total,
        'has_more': hasMore,
      };

  bool get isEmpty => posts.isEmpty && users.isEmpty;
  bool get isNotEmpty => !isEmpty;
  int get itemCount => posts.length + users.length;

  SearchResult copyWith({
    List<PostWithDetails>? posts,
    List<UserSearchResult>? users,
    int? total,
    bool? hasMore,
  }) {
    return SearchResult(
      posts: posts ?? this.posts,
      users: users ?? this.users,
      total: total ?? this.total,
      hasMore: hasMore ?? this.hasMore,
    );
  }

  @override
  String toString() => 'SearchResult(posts: ${posts.length}, users: ${users.length}, total: $total)';
}

/// Tag en tendance
class TrendingTag {
  final TagCategory category;
  final int postsCount;
  final double growthRate;
  final double trendingScore;
  final String period;

  const TrendingTag({
    required this.category,
    required this.postsCount,
    required this.growthRate,
    required this.trendingScore,
    required this.period,
  });

  factory TrendingTag.fromJson(Map<String, dynamic> json) {
    return TrendingTag(
      category: TagCategory.fromString(json['category'] ?? '') ?? TagCategory.art,
      postsCount: json['posts_count'] ?? 0,
      growthRate: (json['growth_rate'] ?? 0.0).toDouble(),
      trendingScore: (json['trending_score'] ?? 0.0).toDouble(),
      period: json['period'] ?? '24h',
    );
  }

  Map<String, dynamic> toJson() => {
        'category': category.value,
        'display_name': category.displayName,
        'emoji': category.emoji,
        'posts_count': postsCount,
        'growth_rate': growthRate,
        'trending_score': trendingScore,
        'period': period,
      };

  String get displayName => category.displayName;
  String get emoji => category.emoji;
  bool get isHot => growthRate > 1.5;

  @override
  String toString() => 'TrendingTag(${category.displayName}: $postsCount posts, ${growthRate.toStringAsFixed(1)}x growth)';
}

/// Interaction utilisateur
class UserInteraction {
  final int id;
  final int userId;
  final InteractionType interactionType;
  final String contentType;
  final int contentId;
  final String? contentMeta;
  final double score;
  final DateTime createdAt;

  const UserInteraction({
    required this.id,
    required this.userId,
    required this.interactionType,
    required this.contentType,
    required this.contentId,
    this.contentMeta,
    required this.score,
    required this.createdAt,
  });

  factory UserInteraction.fromJson(Map<String, dynamic> json) {
    return UserInteraction(
      id: json['id'] ?? 0,
      userId: json['user_id'] ?? 0,
      interactionType: InteractionType.fromString(json['interaction_type'] ?? '') ?? InteractionType.view,
      contentType: json['content_type'] ?? '',
      contentId: json['content_id'] ?? 0,
      contentMeta: json['content_meta'],
      score: (json['score'] ?? 0.0).toDouble(),
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'interaction_type': interactionType.value,
        'content_type': contentType,
        'content_id': contentId,
        if (contentMeta != null) 'content_meta': contentMeta,
      };

  @override
  String toString() => 'UserInteraction(${interactionType.value} on $contentType:$contentId)';
}

/// Préférences utilisateur calculées
class UserPreferences {
  final int userId;
  final Map<TagCategory, double> preferredTags;
  final List<int> preferredCreators;
  final DateTime lastUpdated;

  const UserPreferences({
    required this.userId,
    required this.preferredTags,
    required this.preferredCreators,
    required this.lastUpdated,
  });

  factory UserPreferences.fromJson(Map<String, dynamic> json) {
    final preferredTagsMap = <TagCategory, double>{};
    final preferredTagsJson = json['preferred_tags'] as Map<String, dynamic>? ?? {};
    
    for (final entry in preferredTagsJson.entries) {
      final tag = TagCategory.fromString(entry.key);
      if (tag != null) {
        final scoreData = entry.value as Map<String, dynamic>? ?? {};
        preferredTagsMap[tag] = (scoreData['score'] ?? 0.0).toDouble();
      }
    }

    return UserPreferences(
      userId: json['user_id'] ?? 0,
      preferredTags: preferredTagsMap,
      preferredCreators: (json['preferred_creators'] as List? ?? [])
          .map((id) => id is int ? id : int.tryParse(id.toString()) ?? 0)
          .toList(),
      lastUpdated: DateTime.tryParse(json['last_updated'] ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'user_id': userId,
        'preferred_tags': preferredTags.map(
          (tag, score) => MapEntry(tag.value, {'score': score, 'display_name': tag.displayName, 'emoji': tag.emoji}),
        ),
        'preferred_creators': preferredCreators,
        'last_updated': lastUpdated.toIso8601String(),
      };

  List<TagCategory> get topTags {
    final sortedEntries = preferredTags.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sortedEntries.take(5).map((e) => e.key).toList();
  }

  bool get hasPreferences => preferredTags.isNotEmpty || preferredCreators.isNotEmpty;

  @override
  String toString() => 'UserPreferences(userId: $userId, tags: ${preferredTags.length}, creators: ${preferredCreators.length})';
}

/// Suggestion de recherche
class SearchSuggestion {
  final String type; // 'user', 'tag'
  final String text;
  final String display;
  final String? avatarUrl;
  final int? userId;
  final TagCategory? category;

  const SearchSuggestion({
    required this.type,
    required this.text,
    required this.display,
    this.avatarUrl,
    this.userId,
    this.category,
  });

  factory SearchSuggestion.fromJson(Map<String, dynamic> json) {
    return SearchSuggestion(
      type: json['type'] ?? '',
      text: json['text'] ?? '',
      display: json['display'] ?? '',
      avatarUrl: json['avatar_url'],
      userId: json['user_id'],
      category: json['category'] != null ? TagCategory.fromString(json['category']) : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'type': type,
        'text': text,
        'display': display,
        if (avatarUrl != null) 'avatar_url': avatarUrl,
        if (userId != null) 'user_id': userId,
        if (category != null) 'category': category!.value,
      };

  bool get isUser => type == 'user';
  bool get isTag => type == 'tag';

  @override
  String toString() => 'SearchSuggestion($type: $display)';
}

//  FONCTIONS UTILITAIRES 

/// Calcule le temps écoulé depuis une date
String _getTimeAgo(DateTime dateTime) {
  final now = DateTime.now();
  final difference = now.difference(dateTime);

  if (difference.inDays > 7) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
  } else if (difference.inDays > 0) {
    return '${difference.inDays}j';
  } else if (difference.inHours > 0) {
    return '${difference.inHours}h';
  } else if (difference.inMinutes > 0) {
    return '${difference.inMinutes}min';
  } else {
    return 'maintenant';
  }
}

// CLASSES DE RÉSULTATS 

/// Résultat pour les opérations de recherche
class SearchOperationResult {
  final bool isSuccess;
  final SearchResult? data;
  final String? error;

  const SearchOperationResult._({
    required this.isSuccess,
    this.data,
    this.error,
  });

  factory SearchOperationResult.success(SearchResult data) {
    return SearchOperationResult._(isSuccess: true, data: data);
  }

  factory SearchOperationResult.failure(String error) {
    return SearchOperationResult._(isSuccess: false, error: error);
  }

  bool get isFailure => !isSuccess;

  @override
  String toString() => isSuccess 
      ? 'SearchOperationResult.success(${data?.itemCount} items)' 
      : 'SearchOperationResult.failure($error)';
}

/// Résultat pour les opérations de découverte
class DiscoveryResult {
  final bool isSuccess;
  final List<PostWithDetails>? posts;
  final String? error;

  const DiscoveryResult._({
    required this.isSuccess,
    this.posts,
    this.error,
  });

  factory DiscoveryResult.success(List<PostWithDetails> posts) {
    return DiscoveryResult._(isSuccess: true, posts: posts);
  }

  factory DiscoveryResult.failure(String error) {
    return DiscoveryResult._(isSuccess: false, error: error);
  }

  bool get isFailure => !isSuccess;

  @override
  String toString() => isSuccess 
      ? 'DiscoveryResult.success(${posts?.length} posts)' 
      : 'DiscoveryResult.failure($error)';
}