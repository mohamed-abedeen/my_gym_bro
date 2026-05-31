/// A public, world-readable view of a user — only safe fields plus social
/// counts. Backed by the Supabase `public_profiles` view (see migration 006).
/// Sensitive fields (subscription status, fcm token, trial dates, …) are never
/// part of this model.
class PublicProfile {
  const PublicProfile({
    required this.userId,
    required this.followerCount,
    required this.followingCount,
    required this.friendCount,
    this.displayName,
    this.avatarUrl,
    this.experience,
  });

  factory PublicProfile.fromMap(Map<String, dynamic> m) => PublicProfile(
        userId: m['user_id'] as String,
        displayName: m['display_name'] as String?,
        avatarUrl: m['avatar_url'] as String?,
        experience: m['experience'] as String?,
        followerCount: (m['follower_count'] as num?)?.toInt() ?? 0,
        followingCount: (m['following_count'] as num?)?.toInt() ?? 0,
        friendCount: (m['friend_count'] as num?)?.toInt() ?? 0,
      );

  final String userId;
  final String? displayName;
  final String? avatarUrl;
  final String? experience;
  final int followerCount;
  final int followingCount;
  final int friendCount;
}

/// The viewer's relationship to a profile.
enum Relationship {
  /// The profile is the viewer's own.
  self,

  /// Not following.
  none,

  /// Viewer follows them, but not mutual.
  following,

  /// Mutual follow — they are friends.
  friends,
}
