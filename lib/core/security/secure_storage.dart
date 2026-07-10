import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Wrapper around FlutterSecureStorage with platform-specific security options.
///
/// Android: encryptedSharedPreferences.
/// iOS: first_unlock_this_device accessibility.
class SecureStorage {
  factory SecureStorage() => _instance;
  SecureStorage._();
  static final SecureStorage _instance = SecureStorage._();

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

/// Supabase session persistence backed by [SecureStorage] instead of the
/// default plaintext SharedPreferences. Stored under 'supabase_session' so
/// [SecureStorage.clearTokens] covers it on logout.
class SecureSessionStorage extends LocalStorage {
  const SecureSessionStorage();

  static const _key = 'supabase_session';

  @override
  Future<void> initialize() async {}

  @override
  Future<String?> accessToken() => SecureStorage().read(_key);

  @override
  Future<bool> hasAccessToken() async =>
      await SecureStorage().read(_key) != null;

  @override
  Future<void> persistSession(String persistSessionString) =>
      SecureStorage().write(_key, persistSessionString);

  @override
  Future<void> removePersistedSession() => SecureStorage().delete(_key);
}
