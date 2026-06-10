import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class Storage {
  static const _storage = FlutterSecureStorage();

  static const _keyAccess  = 'access_token';
  static const _keyRefresh = 'refresh_token';
  static const _keyUser    = 'user_json';

  static Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await _storage.write(key: _keyAccess,  value: accessToken);
    await _storage.write(key: _keyRefresh, value: refreshToken);
  }

  static Future<String?> getAccessToken()  => _storage.read(key: _keyAccess);
  static Future<String?> getRefreshToken() => _storage.read(key: _keyRefresh);

  static Future<bool> hasSession() async {
    final token = await _storage.read(key: _keyAccess);
    return token != null && token.isNotEmpty;
  }

  static Future<void> saveUserJson(String json) =>
      _storage.write(key: _keyUser, value: json);

  static Future<String?> getUserJson() => _storage.read(key: _keyUser);

  static Future<void> clear() => _storage.deleteAll();
}