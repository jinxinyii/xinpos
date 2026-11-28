import 'dart:convert';
import 'dart:io';

import '../../../../core/database/app_database.dart';

class SyncApiException implements Exception {
  const SyncApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

class SyncApiClient {
  SyncApiClient({HttpClient? httpClient})
    : _httpClient = httpClient ?? HttpClient();

  final HttpClient _httpClient;

  Future<Set<String>> submitBatch({
    required Uri apiBaseUrl,
    required String accessToken,
    required List<SyncOutboxData> changes,
  }) async {
    final endpoint = apiBaseUrl.replace(
      path: '${apiBaseUrl.path.replaceFirst(RegExp(r'/+$'), '')}/sync/batch',
    );
    final request = await _httpClient.postUrl(endpoint);
    request.headers
      ..set(HttpHeaders.authorizationHeader, 'Bearer $accessToken')
      ..set(HttpHeaders.acceptHeader, 'application/json')
      ..contentType = ContentType.json;
    request.write(
      jsonEncode({
        'changes': changes
            .map(
              (change) => {
                'id': change.id,
                'entityType': change.entityType,
                'entityId': change.entityId,
                'operation': change.operation,
                'payload': jsonDecode(change.payloadJson),
                'createdAt': change.createdAt,
              },
            )
            .toList(),
      }),
    );

    final response = await request.close();
    final body = await utf8.decoder.bind(response).join();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw SyncApiException(
        'Sync request failed (${response.statusCode}): $body',
      );
    }

    final decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic> || decoded['acceptedIds'] is! List) {
      throw const SyncApiException(
        'Sync response did not include acceptedIds.',
      );
    }

    return decoded['acceptedIds'].whereType<String>().toSet();
  }
}
