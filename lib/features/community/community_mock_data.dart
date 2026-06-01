// Offline / no-backend fallback sample posts. Re-exports the shared models so
// existing importers (profile, community screen) keep their single import.
export 'package:my_gym_bro/features/community/community_models.dart';

import 'package:my_gym_bro/features/community/community_models.dart';

/// Sample posts shown when Supabase is unavailable (offline / not configured).
abstract final class CommunityMockData {
  static const List<CommunityPost> posts = [
    CommunityPost(
      authorName: 'Aziz Rhuma',
      likeCount: 10000,
      commentCount: 324,
      description:
          'A fundamental compound movement that builds massive lower-body '
          'power and functional strength. By mimicking a natural sitting '
          'motion, it engages multiple muscle groups simultaneously.',
      topComments: [
        CommunityComment('Omar', 'This is insane bro, keep pushing!'),
        CommunityComment('Ali', 'What weight are you squatting here?'),
        CommunityComment('Nasser', 'Form looks clean 💪'),
      ],
    ),
    CommunityPost(
      authorName: 'Omar',
      likeCount: 5200,
      commentCount: 142,
      description:
          'Building strength one rep at a time. Consistency is key to '
          'unlocking your full potential.',
      topComments: [
        CommunityComment('Aziz', "Let's go champ!"),
        CommunityComment('Khaled', 'Consistency is everything 🔥'),
      ],
    ),
  ];
}
