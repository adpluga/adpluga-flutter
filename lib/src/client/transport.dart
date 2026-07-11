import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:http/http.dart' as http;
import 'package:meta/meta.dart';

import '../constants.dart';
import '../errors.dart';
import '../logger.dart';
import '../models/features.dart';
import '../models/serve_response.dart';

typedef HttpClientFactory = http.Client Function();

@visibleForTesting
HttpClientFactory? transportClientOverride;

class Transport {
  Transport({
    required this.endpoint,
    required this.publisherKey,
    HttpClientFactory? clientFactory,
    math.Random? random,
  })  : _clientFactory = clientFactory ?? (transportClientOverride ?? http.Client.new),
        _random = random ?? math.Random();

  final String endpoint;
  final String publisherKey;
  final HttpClientFactory _clientFactory;
  final math.Random _random;

  http.Client? _client;

  http.Client get _http => _client ??= _clientFactory();

  Map<String, String> _baseHeaders() {
    return <String, String>{
      kHeaderSdkKey: publisherKey,
      kHeaderSdkPlatform: kSdkPlatform,
      kHeaderSdkVersion: kSdkVersion,
    };
  }

  Future<ServeResponse> serve({
    required String slotId,
    String? format,
    String? userHash,
    bool nonPersonalized = false,
    List<String>? consentSignals,
  }) async {
    final params = <String, String>{'slot': slotId};
    if (format != null && format.isNotEmpty) params['fmt'] = format;
    if (userHash != null && userHash.isNotEmpty) params['u'] = userHash;
    if (nonPersonalized) params['non_personalized'] = 'true';
    if (consentSignals != null && consentSignals.isNotEmpty) {
      params['consent'] = consentSignals.join(',');
    }
    final uri = Uri.parse('$endpoint/v1/serve').replace(queryParameters: params);

    Object? lastError;
    for (var attempt = 0; attempt < kRetryMaxAttempts + 1; attempt++) {
      try {
        final resp = await _http
            .get(uri, headers: _baseHeaders())
            .timeout(kServeTimeout);
        if (resp.statusCode == 426) {
          final minSdk = resp.headers[kHeaderMinSdk.toLowerCase()] ?? '';
          throw UpgradeRequiredError(minSdk);
        }
        if (resp.statusCode >= 200 && resp.statusCode < 300) {
          final decoded = _decodeJson(resp.body);
          return ServeResponse.fromJson(decoded);
        }
        if (_shouldRetry(resp.statusCode) && attempt < kRetryMaxAttempts) {
          await _backoff(attempt);
          continue;
        }
        throw NetworkError('serve failed', statusCode: resp.statusCode);
      } on UpgradeRequiredError {
        rethrow;
      } on TimeoutException catch (e) {
        lastError = e;
        if (attempt >= kRetryMaxAttempts) {
          throw const NetworkError('serve timeout');
        }
        await _backoff(attempt);
      } on NetworkError {
        rethrow;
      } catch (e) {
        lastError = e;
        if (attempt >= kRetryMaxAttempts) {
          throw NetworkError('serve error: $e');
        }
        await _backoff(attempt);
      }
    }
    throw NetworkError('serve exhausted: $lastError');
  }

  Future<({FeaturesView? view, String? etag, bool notModified})> features({
    String? etag,
  }) async {
    final uri = Uri.parse('$endpoint/v1/features');
    final headers = <String, String>{};
    if (etag != null && etag.isNotEmpty) headers[kHeaderIfNoneMatch] = etag;
    try {
      final resp = await _http.get(uri, headers: headers).timeout(kServeTimeout);
      if (resp.statusCode == 304) {
        return (view: null, etag: etag, notModified: true);
      }
      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        final decoded = _decodeJson(resp.body);
        return (
          view: FeaturesView.fromJson(decoded),
          etag: resp.headers['etag'],
          notModified: false,
        );
      }
      throw NetworkError('features failed', statusCode: resp.statusCode);
    } on TimeoutException {
      throw const NetworkError('features timeout');
    }
  }

  Future<void> track({
    required String kind,
    required String token,
    Map<String, Object?>? extra,
  }) async {
    final uri = Uri.parse('$endpoint/v1/track');
    final body = <String, Object?>{'kind': kind, 'token': token};
    if (extra != null) body.addAll(extra);
    try {
      await _http
          .post(
            uri,
            headers: {
              ..._baseHeaders(),
              'Content-Type': 'application/json',
            },
            body: jsonEncode(body),
          )
          .timeout(kTrackTimeout);
    } catch (e) {
      logger.warn('track failed', e);
    }
  }

  Future<void> beacon(String url) async {
    if (url.isEmpty) return;
    try {
      await _http.get(Uri.parse(url)).timeout(kTrackTimeout);
    } catch (e) {
      logger.warn('beacon failed', e);
    }
  }

  Future<void> postTelemetry(Map<String, Object?> body) async {
    final uri = Uri.parse('$endpoint/v1/sdk/telemetry');
    try {
      await _http
          .post(
            uri,
            headers: {
              ..._baseHeaders(),
              'Content-Type': 'application/json',
            },
            body: jsonEncode(body),
          )
          .timeout(kTrackTimeout);
    } catch (e) {
      logger.warn('telemetry post failed', e);
    }
  }

  void close() {
    _client?.close();
    _client = null;
  }

  bool _shouldRetry(int status) {
    return status == 408 || status == 429 || (status >= 500 && status < 600);
  }

  Future<void> _backoff(int attempt) async {
    final base = kRetryBaseBackoff.inMilliseconds * math.pow(2, attempt).toInt();
    final jitter = _random.nextInt(base);
    await Future<void>.delayed(Duration(milliseconds: base + jitter));
  }

  Map<String, Object?> _decodeJson(String body) {
    final decoded = jsonDecode(body);
    if (decoded is Map) return decoded.cast<String, Object?>();
    throw const NetworkError('invalid JSON payload');
  }
}
