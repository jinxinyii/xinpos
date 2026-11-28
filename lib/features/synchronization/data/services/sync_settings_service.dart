import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class SyncSettings {
  const SyncSettings({required this.apiBaseUrl, required this.accessToken});

  final Uri apiBaseUrl;
  final String accessToken;
}

class SyncSettingsService {
  static const _apiBaseUrlKey = 'xinpos_sync_api_base_url';
  static const _accessTokenKey = 'xinpos_sync_access_token';
  static const _businessMappingsKey = 'xinpos_sync_business_mappings';

  Future<SyncSettings?> read() async {
    final preferences = SharedPreferencesAsync();
    final baseUrl = await preferences.getString(_apiBaseUrlKey);
    final token = await preferences.getString(_accessTokenKey);
    final uri = baseUrl == null ? null : Uri.tryParse(baseUrl);

    if (uri == null ||
        !uri.hasScheme ||
        uri.host.isEmpty ||
        token == null ||
        token.isEmpty) {
      return null;
    }

    return SyncSettings(apiBaseUrl: uri, accessToken: token);
  }

  Future<void> save({
    required Uri apiBaseUrl,
    required String accessToken,
  }) async {
    if (!apiBaseUrl.hasScheme || apiBaseUrl.host.isEmpty) {
      throw ArgumentError('Enter a valid API URL.');
    }
    if (accessToken.trim().isEmpty) {
      throw ArgumentError('An access token is required.');
    }

    final preferences = SharedPreferencesAsync();
    await preferences.setString(_apiBaseUrlKey, apiBaseUrl.toString());
    await preferences.setString(_accessTokenKey, accessToken.trim());
  }

  Future<void> clear() async {
    final preferences = SharedPreferencesAsync();
    await preferences.remove(_apiBaseUrlKey);
    await preferences.remove(_accessTokenKey);
  }

  Future<void> saveBusinessMapping({
    required String localBusinessId,
    required String remoteBusinessId,
  }) async {
    final preferences = SharedPreferencesAsync();
    final mappings = await businessMappings();
    mappings[localBusinessId] = remoteBusinessId;
    await preferences.setString(_businessMappingsKey, jsonEncode(mappings));
  }

  Future<Map<String, String>> businessMappings() async {
    final value = await SharedPreferencesAsync().getString(_businessMappingsKey);
    if (value == null) return {};

    try {
      final decoded = jsonDecode(value);
      if (decoded is! Map<String, dynamic>) return {};
      return decoded.map(
        (key, mappedValue) => MapEntry(key, mappedValue.toString()),
      );
    } on FormatException {
      return {};
    }
  }
}
