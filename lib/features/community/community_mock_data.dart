// Offline / no-backend fallback sample posts. Re-exports the shared models so
// existing importers (profile, community screen) keep their single import.
import 'package:my_gym_bro/features/community/community_models.dart';

export 'package:my_gym_bro/features/community/community_models.dart';

/// Sample posts shown when Supabase is unavailable (offline / not configured),
/// and — in debug builds — when the real feed is empty. Images are bundled test
/// assets under `assets/images/` (replace for production).
abstract final class CommunityMockData {
  static const List<CommunityPost> posts = [
    CommunityPost(
      authorName: 'Aziz Rhuma',
      imageUrl: 'assets/images/sample_post_1.jpg',
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
      imageUrl: 'assets/images/sample_post_2.jpg',
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
    CommunityPost(
      authorName: 'Lina',
      imageUrl: 'assets/images/sample_post_3.jpg',
      likeCount: 2870,
      commentCount: 89,
      description:
          'Color and energy — good vibes carry the session. Show up, lift, '
          'repeat.',
      topComments: [
        CommunityComment('Sara', 'Love the energy 🌈'),
        CommunityComment('Yousef', 'Vibes on point!'),
      ],
    ),
  ];
}
