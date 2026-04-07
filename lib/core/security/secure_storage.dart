import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Wrapper around FlutterSecureStorage with platform-specific security options.
///
/// Android: encryptedSharedPreferences.
/// iOS: first_unlock_this_device accessibility.
class SecureStorage {
  static final SecureStorage _instance = SecureStorage._();
  factory SecureStorage() => _instance;
  SecureStorage._();

  final _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  Future<String?> read(String key) => _storage.read(key: key);

  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  Future<void> delete(String key) => _storage.delete(key: key);

  /// On logout: delete tokens only, keep user preferences.
  Future<void> clearTokens() async {
    const tokenKeys = [
      'access_token',
      'refresh_token',
      'fcm_token',
      'supabase_session',
    ];
    for (final key in tokenKeys) {
      await _storage.delete(key: key);
    }
  }

  /// On delete account: wipe everything.
  Future<void> wipeAll() => _storage.deleteAll();
}
