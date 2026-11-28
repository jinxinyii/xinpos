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

  Future<SyncPullResponse> fetchChanges({
    required Uri apiBaseUrl,
    required String accessToken,
    required String businessId,
    required int cursor,
  }) async {
    final endpoint = apiBaseUrl.replace(
      path: '${apiBaseUrl.path.replaceFirst(RegExp(r'/+$'), '')}/sync/changes',
      queryParameters: {'business_id': businessId, 'cursor': '$cursor'},
    );
    final request = await _httpClient.getUrl(endpoint);
    request.headers
      ..set(HttpHeaders.authorizationHeader, 'Bearer $accessToken')
      ..set(HttpHeaders.acceptHeader, 'application/json');

    final response = await request.close();
    final body = await utf8.decoder.bind(response).join();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw SyncApiException(
        'Sync pull failed (${response.statusCode}): $body',
      );
    }
    final decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic> ||
        decoded['changes'] is! List ||
        decoded['nextCursor'] is! int) {
      throw const SyncApiException('Sync pull response was invalid.');
    }
    final changes = <RemoteSyncChange>[];
    for (final value in decoded['changes'] as List) {
      if (value is! Map<String, dynamic> ||
          value['cursor'] is! int ||
          value['id'] is! String ||
          value['entityType'] is! String ||
          value['entityId'] is! String ||
          value['operation'] is! String ||
          value['payload'] is! Map<String, dynamic>) {
        throw const SyncApiException('A server change was invalid.');
      }
      changes.add(
        RemoteSyncChange(
          cursor: value['cursor'] as int,
          id: value['id'] as String,
          entityType: value['entityType'] as String,
          entityId: value['entityId'] as String,
          operation: value['operation'] as String,
          payload: value['payload'] as Map<String, dynamic>,
        ),
      );
    }
    return SyncPullResponse(
      changes: changes,
      nextCursor: decoded['nextCursor'] as int,
    );
  }

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

class SyncPullResponse {
  const SyncPullResponse({required this.changes, required this.nextCursor});

  final List<RemoteSyncChange> changes;
  final int nextCursor;
}

class RemoteSyncChange {
  const RemoteSyncChange({
    required this.cursor,
    required this.id,
    required this.entityType,
    required this.entityId,
    required this.operation,
    required this.payload,
  });

  final int cursor;
  final String id;
  final String entityType;
  final String entityId;
  final String operation;
  final Map<String, dynamic> payload;
}
