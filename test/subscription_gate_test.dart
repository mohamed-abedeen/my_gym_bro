import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_gym_bro/core/database/app_database.dart';
import 'package:my_gym_bro/features/workout/workout_providers.dart';

/// Builds a [UserProfile] carrying only the subscription fields the gate
/// reads; the rest are the minimum required by the constructor.
UserProfile _profile({
  required String subscriptionStatus,
  DateTime? subscriptionExpiresAt,
}) {
  return UserProfile(
    localId: 1,
    syncStatus: 'synced',
    weightUnit: 'kg',
    preferredLanguage: 'en',
    subscriptionStatus: subscriptionStatus,
    subscriptionExpiresAt: subscriptionExpiresAt,
    defaultRestSeconds: 90,
    notificationTone: 'balanced',
  );
}

ProviderContainer _containerFor(UserProfile? profile) {
  final container = ProviderContainer(
    overrides: [
      userProfileProvider.overrideWith((ref) => Stream.value(profile)),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

/// Reads [subscriptionLockedProvider] after the overridden stream emits.
/// The provider watches [userProfileProvider] via `.valueOrNull`, which is
/// null on the very first synchronous frame, so let the stream deliver first.
Future<bool> _locked(ProviderContainer container) async {
  await container.read(userProfileProvider.future);
  return container.read(subscriptionLockedProvider);
}

void main() {
  group('subscriptionLockedProvider', () {
    test('null profile (pre-onboarding / loading) does not lock', () async {
      expect(await _locked(_containerFor(null)), isFalse);
    });

    test('active subscription is unlocked', () async {
      final c = _containerFor(_profile(subscriptionStatus: 'active'));
      expect(await _locked(c), isFalse);
    });

    test('expired subscription locks', () async {
      final c = _containerFor(_profile(subscriptionStatus: 'expired'));
      expect(await _locked(c), isTrue);
    });

    test('trial with a future expiry is unlocked', () async {
      final c = _containerFor(_profile(
        subscriptionStatus: 'trial',
        subscriptionExpiresAt: DateTime.now().add(const Duration(days: 3)),
      ));
      expect(await _locked(c), isFalse);
    });

    test('trial past its expiry locks', () async {
      final c = _containerFor(_profile(
        subscriptionStatus: 'trial',
        subscriptionExpiresAt: DateTime.now().subtract(const Duration(days: 1)),
      ));
      expect(await _locked(c), isTrue);
    });

    test('trial with no expiry set does not lock', () async {
      final c = _containerFor(_profile(subscriptionStatus: 'trial'));
      expect(await _locked(c), isFalse);
    });

    test('grace_period does not lock', () async {
      final c = _containerFor(_profile(subscriptionStatus: 'grace_period'));
      expect(await _locked(c), isFalse);
    });

    test('unknown / free status does not lock', () async {
      expect(
        await _locked(_containerFor(_profile(subscriptionStatus: 'free'))),
        isFalse,
      );
      expect(
        await _locked(_containerFor(_profile(subscriptionStatus: 'whatever'))),
        isFalse,
      );
    });
  });
}
