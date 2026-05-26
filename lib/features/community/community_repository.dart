import 'package:my_gym_bro/features/community/community_mock_data.dart';

/// Contract for fetching the community feed.
///
/// The mock implementation ships in v1. Swap [MockCommunityRepository] for a
/// real Supabase implementation when the community backend is ready — every
/// call site stays unchanged.
abstract class CommunityRepository {
  Future<List<CommunityPost>> fetchFeed();
}

class MockCommunityRepository implements CommunityRepository {
  const MockCommunityRepository();

  @override
  Future<List<CommunityPost>> fetchFeed() async => CommunityMockData.posts;
}
