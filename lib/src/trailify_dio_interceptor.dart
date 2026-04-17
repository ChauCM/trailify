import 'package:dio/dio.dart';

import 'trailify.dart';

class TrailifyDioInterceptor extends Interceptor {
  final Trailify _trailify;

  final int _maxBodySize;

  final bool _captureSuccessBodies;

  final List<RegExp> _excludePatterns;

  final List<RegExp> _alwaysCaptureBodyPatterns;

  static const _sensitiveHeaders = {
    'authorization',
    'cookie',
    'set-cookie',
    'x-api-key',
  };

  static const _sensitiveBodyFields = {
    'password',
    'token',
    'refreshtoken',
    'accesstoken',
    'secret',
    'base64',
  };

  TrailifyDioInterceptor(
    this._trailify, {
    List<RegExp>? excludePatterns,
    List<RegExp>? alwaysCaptureBodyPatterns,
    int maxBodySize = 2000,
    bool captureSuccessBodies = false,
  })  : _excludePatterns = excludePatterns ?? [],
        _alwaysCaptureBodyPatterns = alwaysCaptureBodyPatterns ?? [],
        _maxBodySize = maxBodySize,
        _captureSuccessBodies = captureSuccessBodies;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.extra['_auditStartTime'] = DateTime.now().millisecondsSinceEpoch;
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    _logHttpEvent(
      options: response.requestOptions,
      statusCode: response.statusCode,
      responseBody: response.data,
      error: null,
      errorType: null,
    );
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    _logHttpEvent(
      options: err.requestOptions,
      statusCode: err.response?.statusCode,
      responseBody: err.response?.data,
      error: err.message ?? err.toString(),
      errorType: err.type.name,
    );
    handler.next(err);
  }

  void _logHttpEvent({
    required RequestOptions options,
    required int? statusCode,
    required dynamic responseBody,
    required String? error,
    required String? errorType,
  }) {
    final path = options.uri.path;
    if (_excludePatterns.any((re) => re.hasMatch(path))) return;

    final startTime = options.extra['_auditStartTime'] as int?;
    final durationMs = startTime != null
        ? DateTime.now().millisecondsSinceEpoch - startTime
        : null;

    final isError = error != null || (statusCode != null && statusCode >= 400);
    final eventType = isError ? 'api_error' : 'api_request';

    final shouldCaptureBodies = isError ||
        _captureSuccessBodies ||
        _alwaysCaptureBodyPatterns.any((re) => re.hasMatch(path));

    _trailify.log(
      eventType: eventType,
      payload: {
        'method': options.method,
        'url': options.path,
        'baseUrl': options.baseUrl,
        'requestHeaders': _scrubHeaders(options.headers),
        if (shouldCaptureBodies)
          'requestBody': _scrubBody(_truncate(options.data)),
        'statusCode': statusCode,
        if (shouldCaptureBodies) 'responseBody': _truncate(responseBody),
        'durationMs': durationMs,
        'error': error,
        'errorType': errorType,
      },
    );
  }

  Map<String, dynamic> _scrubHeaders(Map<String, dynamic> headers) {
    return headers.map((key, value) {
      if (_sensitiveHeaders.contains(key.toLowerCase())) {
        return MapEntry(key, '[REDACTED]');
      }
      return MapEntry(key, value?.toString());
    });
  }

  dynamic _scrubBody(dynamic body) {
    if (body is Map) {
      return body.map((key, value) {
        if (_sensitiveBodyFields.contains(key.toString().toLowerCase())) {
          return MapEntry(key, '[REDACTED]');
        }
        if (value is Map || value is List) {
          return MapEntry(key, _scrubBody(value));
        }
        return MapEntry(key, value);
      });
    }
    if (body is List) {
      return body.map(_scrubBody).toList();
    }
    return body;
  }

  dynamic _truncate(dynamic body) {
    if (body == null) return null;
    if (body is String && body.length > _maxBodySize) {
      return '${body.substring(0, _maxBodySize)}... [TRUNCATED]';
    }
    if (body is Map || body is List) {
      final jsonStr = body.toString();
      if (jsonStr.length > _maxBodySize) {
        return '${jsonStr.substring(0, _maxBodySize)}... [TRUNCATED]';
      }
    }
    return body;
  }
}
