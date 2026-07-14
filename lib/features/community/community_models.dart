/// Models for the community feed.
library;

/// A community post. Carries real backend fields (id, counts, like state,
/// author avatar, image, timestamp); the [likes]/[bookmarks] string getters
/// keep the existing card UI unchanged.
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
  });

  final String id;
  final String authorName;
  final String? authorAvatarUrl;
  final String? imageUrl;
  final String description;
  final int likeCount;

  /// Backed by the real `post_comments` table but not shown anywhere yet —
  /// the comment UI returns when comment read/write ships.
  final int commentCount;
  final bool likedByMe;
  final DateTime? createdAt;

  /// Compact display string used by the post card.
  String get likes => _compact(likeCount);

  /// Bookmarks aren't backed yet — kept so the card layout is unchanged.
  String get bookmarks => '0';
}

String _compact(int n) {
  if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
  if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
  return '$n';
}
