// ⚠️  MOCK DATA — UI placeholder only.
// Replace [CommunityMockData.posts] with a real Supabase feed query
// when the community backend is ready (Phase 16 / social feature sprint).

/// A single comment preview shown below a post.
class CommunityComment {
  const CommunityComment(this.name, this.text);

  final String name;
  final String text;
}

/// Flat data model for a community post card.
class CommunityPost {
  const CommunityPost({
    required this.authorName,
    required this.likes,
    required this.comments,
    required this.bookmarks,
    required this.description,
    this.topComments = const [],
  });

  final String authorName;
  final String likes;
  final String comments;
  final String bookmarks;
  final String description;
  final List<CommunityComment> topComments;
}

/// Static placeholder posts.
/// TODO(backend): swap for `SupabaseCommunityRepository.fetchFeed()`.
abstract final class CommunityMockData {
  static const List<CommunityPost> posts = [
    CommunityPost(
      authorName: 'Aziz Rhuma',
      likes: '10k',
      comments: '324',
      bookmarks: '67',
      description:
          'A fundamental compound movement that builds massive lower-body '
          'power and functional strength. By mimicking a natural sitting '
          'motion, it engages multiple muscle groups simultaneously, boosting '
          'metabolism and improving overall athletic performance.',
      topComments: [
        CommunityComment('Omar', 'This is insane bro, keep pushing!'),
        CommunityComment('Ali', 'What weight are you squatting here?'),
        CommunityComment('Nasser', 'Form looks clean 💪'),
      ],
    ),
    CommunityPost(
      authorName: 'Omar',
      likes: '5.2k',
      comments: '142',
      bookmarks: '31',
      description:
          'Building strength one rep at a time. Consistency is key to '
          'unlocking your full potential.',
      topComments: [
        CommunityComment('Aziz', "Let's go champ!"),
        CommunityComment('Khaled', 'Consistency is everything 🔥'),
        CommunityComment('Yusuf', 'Need to train with you sometime'),
      ],
    ),
  ];
}
