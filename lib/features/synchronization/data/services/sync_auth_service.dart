import 'dart:convert';
import 'dart:io';

import 'sync_api_client.dart';

class SyncAccount {
  const SyncAccount({
    required this.accessToken,
    required this.email,
    required this.businessId,
    required this.businessName,
  });

  final String accessToken;
  final String email;
  final String? businessId;
  final String? businessName;
}

class SyncAuthService {
  SyncAuthService({HttpClient? httpClient})
    : _httpClient = httpClient ?? HttpClient();

  final HttpClient _httpClient;

  Future<SyncAccount> login({
    required Uri apiBaseUrl,
    required String email,
    required String password,
    required String deviceName,
  }) {
    return _request(
      apiBaseUrl: apiBaseUrl,
      path: '/auth/login',
      body: {'email': email, 'password': password, 'device_name': deviceName},
    );
  }

  Future<SyncAccount> register({
    required Uri apiBaseUrl,
    required String name,
    required String email,
    required String password,
    required String businessName,
    required String deviceName,
  }) {
    return _request(
      apiBaseUrl: apiBaseUrl,
      path: '/auth/register',
      body: {
        'name': name,
        'email': email,
        'password': password,
        'business_name': businessName,
        'device_name': deviceName,
      },
    );
  }

  Future<SyncAccount> _request({
    required Uri apiBaseUrl,
    required String path,
    required Map<String, String> body,
  }) async {
    final endpoint = apiBaseUrl.replace(
      path: '${apiBaseUrl.path.replaceFirst(RegExp(r'/+$'), '')}$path',
    );
    final request = await _httpClient.postUrl(endpoint);
    request.headers
      ..set(HttpHeaders.acceptHeader, 'application/json')
      ..contentType = ContentType.json;
    request.write(jsonEncode(body));

    final response = await request.close();
    final responseBody = await utf8.decoder.bind(response).join();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw SyncApiException(
        'Account request failed (${response.statusCode}): $responseBody',
      );
    }

    final decoded = jsonDecode(responseBody);
    if (decoded is! Map<String, dynamic> || decoded['token'] is! String) {
      throw const SyncApiException(
        'Account response did not include an access token.',
      );
    }
    final user = decoded['user'];
    final business = decoded['business'];
    return SyncAccount(
      accessToken: decoded['token'] as String,
      email: user is Map<String, dynamic> && user['email'] is String
          ? user['email'] as String
          : '',
      businessId: business is Map<String, dynamic> && business['id'] is String
          ? business['id'] as String
          : null,
      businessName:
          business is Map<String, dynamic> && business['name'] is String
          ? business['name'] as String
          : null,
    );
  }
}
