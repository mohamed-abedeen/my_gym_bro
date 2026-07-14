import 'package:my_gym_bro/core/security/input_sanitiser.dart';
import 'package:my_gym_bro/features/community/community_models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Contract for the community feed.
abstract class CommunityRepository {
  Future<List<CommunityPost>> fetchFeed({int limit = 30, int offset = 0});

  /// Create a text (optionally image) post as the current user.
  Future<void> createPost({required String content, String? imageUrl});

  /// Toggle the current user's like on a post.
  Future<void> toggleLike(String postId, {required bool currentlyLiked});
}

/// Supabase-backed community feed.
///
/// Reads are gated server-side by `has_active_subscription` (RLS); author
/// names/avatars come from the `public_profiles` view; like/comment counts use
/// PostgREST aggregate embeds. All writes are scoped to the current user by RLS.
class SupabaseCommunityRepository implements CommunityRepository {
  SupabaseCommunityRepository(this._sb);

  final SupabaseClient _sb;

  String? get _uid => _sb.auth.currentUser?.id;

  @override
  Future<List<CommunityPost>> fetchFeed({int limit = 30, int offset = 0}) async {
    final rows = await _sb
        .from('posts')
        .select(
          'id, user_id, content, image_url, created_at, '
          'post_likes(count), post_comments(count)',
        )
        .isFilter('deleted_at', null)
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);

    final list = (rows as List).cast<Map<String, dynamic>>();
    if (list.isEmpty) return const [];

    // Author display info (one batched query against the safe profile view).
    final userIds = list.map((r) => r['user_id'] as String).toSet().toList();
    final profRows = await _sb
        .from('public_profiles')
        .select('user_id, display_name, avatar_url')
        .inFilter('user_id', userIds);
    final byUser = <String, Map<String, dynamic>>{
      for (final p in (profRows as List).cast<Map<String, dynamic>>())
        p['user_id'] as String: p,
    };

    // Which of these posts the current user has liked.
    final uid = _uid;
    var likedIds = <String>{};
    if (uid != null) {
      final postIds = list.map((r) => r['id'] as String).toList();
      final likeRows = await _sb
          .from('post_likes')
          .select('post_id')
          .eq('user_id', uid)
          .inFilter('post_id', postIds);
      likedIds = {
        for (final l in (likeRows as List).cast<Map<String, dynamic>>())
          l['post_id'] as String,
      };
    }

    return [
      for (final r in list)
        CommunityPost(
          id: r['id'] as String,
          authorName:
              (byUser[r['user_id']]?['display_name'] as String?) ?? 'Gym Bro',
          authorAvatarUrl: byUser[r['user_id']]?['avatar_url'] as String?,
          imageUrl: r['image_url'] as String?,
          description: (r['content'] as String?) ?? '',
          likeCount: _embedCount(r['post_likes']),
          commentCount: _embedCount(r['post_comments']),
          likedByMe: likedIds.contains(r['id']),
          createdAt: DateTime.tryParse(r['created_at'] as String? ?? ''),
        ),
    ];
  }

  @override
  Future<void> createPost({required String content, String? imageUrl}) async {
    final uid = _uid;
    if (uid == null) return;
    final clean = InputSanitiser.sanitise(content, maxLength: 2000);
    if (clean.isEmpty && imageUrl == null) return;
    await _sb.from('posts').insert({
      'user_id': uid,
      'content': clean,
      if (imageUrl != null) 'image_url': imageUrl,
    });
  }

  @override
  Future<void> toggleLike(String postId, {required bool currentlyLiked}) async {
    final uid = _uid;
    if (uid == null) return;
    if (currentlyLiked) {
      await _sb.from('post_likes').delete().eq('post_id', postId).eq('user_id', uid);
    } else {
      await _sb.from('post_likes').insert({'post_id': postId, 'user_id': uid});
    }
  }

  /// PostgREST returns `post_likes(count)` as `[{count: N}]`.
  int _embedCount(dynamic embed) {
    if (embed is List && embed.isNotEmpty) {
      return ((embed.first as Map)['count'] as num?)?.toInt() ?? 0;
    }
    return 0;
  }
}
