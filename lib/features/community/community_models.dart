/// Models for the community feed.

/// A single comment preview shown below a post.
class CommunityComment {
  const CommunityComment(this.name, this.text);

  final String name;
  final String text;
}

/// A community post. Carries real backend fields (id, counts, like state,
/// author avatar, image, timestamp); the [likes]/[comments]/[bookmarks]
/// string getters keep the existing card UI unchanged.
class CommunityPost {
  const CommunityPost({
    required this.authorName,
    required this.description,
    this.id = '',
    this.authorAvatarUrl,
    this.imageUrl,
    this.likeCount = 0,
    this.commentCount = 0,
    this.likedByMe = false,
    this.createdAt,
    this.topComments = const [],
  });

  final String id;
  final String authorName;
  final String? authorAvatarUrl;
  final String? imageUrl;
  final String description;
  final int likeCount;
  final int commentCount;
  final bool likedByMe;
  final DateTime? createdAt;
  final List<CommunityComment> topComments;

  /// Compact display strings used by the post card.
  String get likes => _compact(likeCount);
  String get comments => _compact(commentCount);

  /// Bookmarks aren't backed yet — kept so the card layout is unchanged.
  String get bookmarks => '0';
}

String _compact(int n) {
  if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
  if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
  return '$n';
}
