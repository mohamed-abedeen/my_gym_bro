import 'package:my_gym_bro/core/database/app_database.dart' show Friendship;

/// A public, world-readable view of a user — only safe fields plus the friend
/// count. Backed by the Supabase `public_profiles` view (see migration 012).
/// Sensitive fields (subscription status, fcm token, trial dates, …) are never
/// part of this model.
class PublicProfile {
  const PublicProfile({
    required this.userId,
    required this.friendCount,
    this.username,
    this.displayName,
    this.avatarUrl,
    this.experience,
  });

  factory PublicProfile.fromMap(Map<String, dynamic> m) => PublicProfile(
        userId: m['user_id'] as String,
        username: m['username'] as String?,
        displayName: m['display_name'] as String?,
        avatarUrl: m['avatar_url'] as String?,
        experience: m['experience'] as String?,
        friendCount: (m['friend_count'] as num?)?.toInt() ?? 0,
      );

  final String userId;

  /// Unique lowercase @handle — null until the user claims one.
  final String? username;
  final String? displayName;
  final String? avatarUrl;
  final String? experience;
  final int friendCount;
}

/// The viewer's relationship to a profile.
///
/// When the *other* side blocked the viewer, this reports [none] on purpose —
/// blocking is discreet (PRD §5.6): the blocked party sees a plain stranger
/// profile, and a new request attempt fails quietly.
enum Relationship {
  /// The profile is the viewer's own.
  self,

  /// No edge (or the viewer is blocked and must not know).
  none,

  /// The viewer sent a request that is still pending.
  pendingOut,

  /// This user sent the viewer a request — accept / decline available.
  pendingIn,

  /// Accepted — they are bros.
  friends,

  /// The viewer blocked this user (only the blocker sees this state).
  blocked,
}

/// Derive the viewer's [Relationship] from the cached friendship edge.
Relationship relationshipFromRow(Friendship? row, String currentUserId) {
  if (row == null) return Relationship.none;
  switch (row.status) {
    case 'accepted':
      return Relationship.friends;
    case 'pending':
      return row.requesterId == currentUserId
          ? Relationship.pendingOut
          : Relationship.pendingIn;
    case 'blocked':
      return row.blockedBy == currentUserId
          ? Relationship.blocked
          : Relationship.none;
  }
  return Relationship.none;
}
