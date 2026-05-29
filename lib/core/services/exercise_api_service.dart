import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'workoutx_exercise.dart';

/// Base type for all WorkoutX API failures.
class WorkoutXException implements Exception {
  final String message;
  const WorkoutXException(this.message);
  @override
  String toString() => 'WorkoutXException: $message';
}

/// Thrown when no API key is configured, or the key is rejected (401).
class WorkoutXAuthException extends WorkoutXException {
  const WorkoutXAuthException(super.message);
}

/// Thrown when an endpoint/feature requires a higher plan (HTTP 402).
/// On the free plan this is returned for search / multi-filter.
class WorkoutXPlanException extends WorkoutXException {
  final String? feature;
  const WorkoutXPlanException(super.message, {this.feature});
}

/// Thrown when the per-minute rate limit or daily quota is exhausted (429).
class WorkoutXRateLimitException extends WorkoutXException {
  const WorkoutXRateLimitException(super.message);
}

/// Thrown when the device is offline or the request times out / fails at the
/// transport layer. Distinct from API-level errors so callers can fall back to
/// the local cache silently.
class WorkoutXNetworkException extends WorkoutXException {
  const WorkoutXNetworkException(super.message);
}

/// A page of browse/search results.
class WorkoutXPage {
  /// Total number of exercises matching the query across all pages.
  final int total;
  final List<WorkoutXExercise> items;
  const WorkoutXPage({required this.total, required this.items});
}

/// Thin HTTP client for the WorkoutX exercise API.
///
/// Contract (verified against the free plan):
///   • Base `https://api.workoutxapp.com/v1`, auth header `X-WorkoutX-Key`.
///   • `GET /exercises?offset&limit` → `{total,count,data:[…]}` (free).
///   • `GET /exercises/{id}` → bare exercise object (free).
///   • `GET /exercises/search?q=` → 402 on the free plan (paid `multiFilter`).
///
/// This service performs no caching or fallback — that is the repository's job.
class ExerciseApiService {
  static const String baseUrl = 'https://api.workoutxapp.com/v1';
  static const Duration _timeout = Duration(seconds: 15);

  final http.Client _client;
  final String _apiKey;

  ExerciseApiService({required String apiKey, http.Client? client})
      : _apiKey = apiKey,
        _client = client ?? http.Client();

  /// Whether an API key is present. When false, every call throws
  /// [WorkoutXAuthException] without hitting the network.
  bool get hasKey => _apiKey.isNotEmpty;

  /// Browse the full exercise list, paginated.
  Future<WorkoutXPage> browse({int offset = 0, int limit = 50}) async {
    final json = await _getJson('/exercises', {
      'offset': '$offset',
      'limit': '$limit',
    });
    return _parsePage(json);
  }

  /// Search exercises by name/keyword.
  ///
  /// Hits the dedicated search endpoint, which is the correct contract for
  /// paid plans. On the free plan this throws [WorkoutXPlanException]; callers
  /// (the repository) catch it and fall back to local-cache filtering.
  Future<WorkoutXPage> searchByName(String query, {int limit = 50}) async {
    final json = await _getJson('/exercises/search', {
      'q': query,
      'limit': '$limit',
    });
    return _parsePage(json);
  }

  /// Fetch a single exercise by its WorkoutX id. Returns null on 404.
  Future<WorkoutXExercise?> getById(String id) async {
    try {
      final json = await _getJson('/exercises/$id', const {});
      if (json is Map<String, dynamic>) {
        return WorkoutXExercise.fromJson(json);
      }
      return null;
    } on _NotFound {
      return null;
    }
  }

  // ── internals ────────────────────────────────────────────────────────

  WorkoutXPage _parsePage(dynamic json) {
    if (json is Map<String, dynamic>) {
      final data = (json['data'] as List?) ?? const [];
      final items = data
          .whereType<Map<String, dynamic>>()
          .map(WorkoutXExercise.fromJson)
          .toList();
      final total = (json['total'] as num?)?.toInt() ?? items.length;
      return WorkoutXPage(total: total, items: items);
    }
    return const WorkoutXPage(total: 0, items: []);
  }

  Future<dynamic> _getJson(String path, Map<String, String> query) async {
    if (!hasKey) {
      throw const WorkoutXAuthException('No WorkoutX API key configured.');
    }

    final uri =
        Uri.parse('$baseUrl$path').replace(queryParameters: query.isEmpty ? null : query);

    http.Response res;
    try {
      res = await _client
          .get(uri, headers: {'X-WorkoutX-Key': _apiKey})
          .timeout(_timeout);
    } on SocketException {
      throw const WorkoutXNetworkException('No internet connection.');
    } on TimeoutException {
      throw const WorkoutXNetworkException('Request timed out.');
    } on http.ClientException catch (e) {
      throw WorkoutXNetworkException(e.message);
    }

    switch (res.statusCode) {
      case 200:
        return jsonDecode(res.body);
      case 401:
        throw const WorkoutXAuthException('Invalid or missing API key.');
      case 402:
        final body = _tryDecodeMap(res.body);
        throw WorkoutXPlanException(
          (body?['message'] as String?) ?? 'A higher plan is required.',
          feature: body?['feature'] as String?,
        );
      case 404:
        throw const _NotFound();
      case 429:
        throw const WorkoutXRateLimitException(
            'Rate limit or daily quota exceeded. Try again later.');
      default:
        final body = _tryDecodeMap(res.body);
        throw WorkoutXException(
          (body?['message'] as String?) ?? 'Request failed (${res.statusCode}).',
        );
    }
  }

  Map<String, dynamic>? _tryDecodeMap(String body) {
    try {
      final decoded = jsonDecode(body);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }

  void dispose() => _client.close();
}

/// Internal signal for a 404 so [ExerciseApiService.getById] can return null
/// while list endpoints can treat it as an error.
class _NotFound implements Exception {
  const _NotFound();
}
