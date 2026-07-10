import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'package:my_gym_bro/core/services/api_exercise.dart';

/// Any exercise-API failure (offline, rate-limited, server error). Callers
/// catch this and fall back to the local cache.
class ExerciseApiException implements Exception {
  const ExerciseApiException(this.message);
  final String message;
  @override
  String toString() => 'ExerciseApiException: $message';
}

/// One page of the catalogue, cursor-paginated.
class ExerciseApiPage {
  const ExerciseApiPage({
    required this.total,
    required this.hasNextPage,
    required this.nextCursor,
    required this.items,
  });

  /// Total number of exercises in the catalogue.
  final int total;
  final bool hasNextPage;

  /// Pass as `after` to fetch the next page. Null on the last page.
  final String? nextCursor;
  final List<ApiExercise> items;
}

/// Thin HTTP client for the ExerciseDB open-source v1 API.
///
/// Contract (verified against the live API, July 2026):
///   • Base `https://oss.exercisedb.dev/api/v1` — free, no API key.
///   • `GET /exercises?after=<id>&limit=N` → `{success, meta:{total,
///     hasNextPage, nextCursor}, data:[…]}`. Cursor-paged (offset is
///     ignored); pages cap at 25 items.
///   • `GET /exercises/{exerciseId}` → `{success, data:{…}}`.
///   • Aggressively rate-limited (429 after ~a dozen rapid requests) —
///     callers must treat 429 as "stop and resume later", not retry-loop.
///
/// This service performs no caching or fallback — that is the repository's
/// job. TESTING ONLY: this dataset is licensed non-commercial; swap the data
/// source for the purchased ExerciseDB.io dataset before any paid release.
class ExerciseApiService {
  ExerciseApiService({http.Client? client}) : _client = client ?? http.Client();

  static const String baseUrl = 'https://oss.exercisedb.dev/api/v1';
  static const Duration _timeout = Duration(seconds: 15);

  /// The API caps page size at 25 regardless of the requested limit.
  static const int pageSize = 25;

  final http.Client _client;

  /// Fetch one catalogue page. [after] is the `nextCursor` of the previous
  /// page (null for the first page).
  Future<ExerciseApiPage> browsePage({String? after}) async {
    final json = await _getJson('/exercises', {
      'limit': '$pageSize',
      if (after != null) 'after': after,
    });
    if (json is! Map<String, dynamic>) {
      throw const ExerciseApiException('Unexpected response shape.');
    }
    final meta = (json['meta'] as Map<String, dynamic>?) ?? const {};
    final data = (json['data'] as List?) ?? const [];
    final items = data
        .whereType<Map<String, dynamic>>()
        .map(ApiExercise.fromJson)
        .toList();
    final hasNext = meta['hasNextPage'] == true;
    return ExerciseApiPage(
      total: (meta['total'] as num?)?.toInt() ?? items.length,
      hasNextPage: hasNext,
      nextCursor: hasNext ? meta['nextCursor'] as String? : null,
      items: items,
    );
  }

  /// Fetch a single exercise by its ExerciseDB id. Returns null on 404.
  Future<ApiExercise?> getById(String id) async {
    try {
      final json = await _getJson('/exercises/$id', const {});
      final data = (json is Map<String, dynamic>) ? json['data'] : null;
      if (data is Map<String, dynamic>) return ApiExercise.fromJson(data);
      return null;
    } on _NotFound {
      return null;
    }
  }

  // ── internals ────────────────────────────────────────────────────────

  Future<dynamic> _getJson(String path, Map<String, String> query) async {
    final uri = Uri.parse('$baseUrl$path')
        .replace(queryParameters: query.isEmpty ? null : query);

    http.Response res;
    try {
      res = await _client.get(uri).timeout(_timeout);
    } on SocketException {
      throw const ExerciseApiException('No internet connection.');
    } on TimeoutException {
      throw const ExerciseApiException('Request timed out.');
    } on http.ClientException catch (e) {
      throw ExerciseApiException(e.message);
    }

    switch (res.statusCode) {
      case 200:
        return jsonDecode(res.body);
      case 404:
        throw const _NotFound();
      case 429:
        throw const ExerciseApiException('Rate limited — resume later.');
      default:
        throw ExerciseApiException('Request failed (${res.statusCode}).');
    }
  }

  void dispose() => _client.close();
}

/// Internal signal for a 404 so [ExerciseApiService.getById] can return null
/// while list endpoints can treat it as an error.
class _NotFound implements Exception {
  const _NotFound();
}
