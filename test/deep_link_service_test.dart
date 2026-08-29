import 'package:flutter_test/flutter_test.dart';
import 'package:my_gym_bro/core/services/deep_link_service.dart';

/// URI filtering + stash behavior. `globalRouter` is null in tests, so an
/// accepted share link must land in the pending stash (the scaffold replays
/// it in the real app).
void main() {
  final service = DeepLinkService.instance;

  setUp(service.consumePendingShareCode); // reset the singleton's stash

  test('accepts a mygymbro.app share link and stashes the code', () {
    service.handleUri(Uri.parse('https://mygymbro.app/s/abc23456'));
    expect(service.consumePendingShareCode(), 'abc23456');
  });

  test('uppercases in the path are normalised', () {
    service.handleUri(Uri.parse('https://mygymbro.app/s/ABC23456'));
    expect(service.consumePendingShareCode(), 'abc23456');
  });

  test('consume is one-shot', () {
    service.handleUri(Uri.parse('https://mygymbro.app/s/abc23456'));
    expect(service.consumePendingShareCode(), 'abc23456');
    expect(service.consumePendingShareCode(), isNull);
  });

  test('ignores the Supabase OAuth callback', () {
    service.handleUri(
      Uri.parse('io.supabase.mygymbro://login-callback/#access_token=x'),
    );
    expect(service.consumePendingShareCode(), isNull);
  });

  test('ignores foreign hosts and unknown paths', () {
    service
      ..handleUri(Uri.parse('https://evil.example.com/s/abc23456'))
      ..handleUri(Uri.parse('https://mygymbro.app/terms'))
      ..handleUri(Uri.parse('https://mygymbro.app/x/abc23456'))
      ..handleUri(Uri.parse('http://mygymbro.app/s/abc23456'));
    expect(service.consumePendingShareCode(), isNull);
  });

  test('ignores malformed codes', () {
    service
      ..handleUri(Uri.parse('https://mygymbro.app/s/ab'))
      ..handleUri(Uri.parse('https://mygymbro.app/s/has-dash-inside'));
    expect(service.consumePendingShareCode(), isNull);
  });

  test('stashCode feeds the same pending slot', () {
    DeepLinkService.stashCode('xyz23456');
    expect(service.consumePendingShareCode(), 'xyz23456');
  });
}
