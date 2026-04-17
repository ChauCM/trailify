import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:trailify/src/trailify.dart';
import 'package:trailify/src/trailify_dio_interceptor.dart';
import 'package:trailify/src/trailify_identity.dart';
import 'package:trailify/src/trailify_store.dart';

void main() {
  late TrailifyStore store;
  late TrailifyIdentity identity;
  late Dio dio;

  setUp(() async {
    store = TrailifyStore.withFactory(newDatabaseFactoryMemory(), 'test.db');
    identity = TrailifyIdentity();
    identity.initForTest(
      deviceId: 'test-device',
      sessionId: 'test-session',
    );
    Trailify.instance.resetForTest();
    await Trailify.instance.initForTest(
      store: store,
      identity: identity,
    );
    dio = Dio(BaseOptions(baseUrl: 'https://api.example.com'));
  });

  tearDown(() async {
    Trailify.instance.resetForTest();
    // Don't close store -- let fire-and-forget inserts finish
  });

  test('successful GET produces api_request event', () async {
    dio.interceptors.add(TrailifyDioInterceptor(Trailify.instance));
    dio.httpClientAdapter = _SuccessAdapter(200, {'result': 'ok'});

    await dio.get('/api/v1/users');
    await _waitForLog();

    final entries = Trailify.instance.entries.value;
    expect(entries, hasLength(1));

    final event = entries.first;
    expect(event['eventType'], 'api_request');
    expect(event['payload']['method'], 'GET');
    expect(event['payload']['url'], '/api/v1/users');
    expect(event['payload']['statusCode'], 200);
    expect(event['payload']['durationMs'], isNotNull);
  });

  test('failed POST produces api_error event', () async {
    dio.interceptors.add(TrailifyDioInterceptor(
      Trailify.instance,
      captureSuccessBodies: true,
    ));
    dio.httpClientAdapter = _ErrorAdapter(500, {'error': 'internal'});

    try {
      await dio.post('/api/v1/messages', data: {'text': 'hello'});
    } on DioException catch (_) {}

    await _waitForLog();
    final entries = Trailify.instance.entries.value;
    expect(entries, hasLength(1));

    final event = entries.first;
    expect(event['eventType'], 'api_error');
    expect(event['payload']['method'], 'POST');
    expect(event['payload']['statusCode'], 500);
  });

  test('sensitive headers are redacted', () async {
    dio.interceptors.add(TrailifyDioInterceptor(Trailify.instance));
    dio.options.headers['Authorization'] = 'Bearer secret-token';
    dio.options.headers['X-Api-Key'] = 'my-api-key';
    dio.httpClientAdapter = _SuccessAdapter(200, {});

    await dio.get('/api/v1/data');
    await _waitForLog();

    final payload = Trailify.instance.entries.value.first['payload'] as Map;
    final headers = payload['requestHeaders'] as Map;
    expect(headers['Authorization'], '[REDACTED]');
    expect(headers['X-Api-Key'], '[REDACTED]');
  });

  test('sensitive body fields are redacted', () async {
    dio.interceptors.add(TrailifyDioInterceptor(
      Trailify.instance,
      captureSuccessBodies: true,
    ));
    dio.httpClientAdapter = _SuccessAdapter(200, {});

    await dio.post('/api/v1/auth', data: {
      'email': 'user@test.com',
      'password': 'super-secret',
      'token': 'jwt-value',
    });
    await _waitForLog();

    final payload = Trailify.instance.entries.value.first['payload'] as Map;
    final body = payload['requestBody'] as Map;
    expect(body['email'], 'user@test.com');
    expect(body['password'], '[REDACTED]');
    expect(body['token'], '[REDACTED]');
  });

  test('accessToken field is redacted regardless of case', () async {
    dio.interceptors.add(TrailifyDioInterceptor(
      Trailify.instance,
      captureSuccessBodies: true,
    ));
    dio.httpClientAdapter = _SuccessAdapter(200, {});

    await dio.post('/api/v1/token', data: {
      'accessToken': 'eyJhbGciOi...',
      'refreshToken': 'dGhpcyBpcyBh...',
    });
    await _waitForLog();

    final payload = Trailify.instance.entries.value.first['payload'] as Map;
    final body = payload['requestBody'] as Map;
    expect(body['accessToken'], '[REDACTED]');
    expect(body['refreshToken'], '[REDACTED]');
  });

  test('excluded URL patterns produce no events', () async {
    dio.interceptors.add(TrailifyDioInterceptor(
      Trailify.instance,
      excludePatterns: [RegExp(r'/health')],
    ));
    dio.httpClientAdapter = _SuccessAdapter(200, {});

    await dio.get('/health');
    await _waitForLog();

    expect(Trailify.instance.entries.value, isEmpty);
  });

  test('body capture respects captureSuccessBodies flag', () async {
    dio.interceptors.add(TrailifyDioInterceptor(
      Trailify.instance,
      captureSuccessBodies: false,
    ));
    dio.httpClientAdapter = _SuccessAdapter(200, {'data': 'response-body'});

    await dio.post('/api/v1/items', data: {'name': 'item1'});
    await _waitForLog();

    final payload = Trailify.instance.entries.value.first['payload'] as Map;
    expect(payload.containsKey('requestBody'), isFalse);
    expect(payload.containsKey('responseBody'), isFalse);
  });

  test('alwaysCaptureBodyPatterns overrides default', () async {
    dio.interceptors.add(TrailifyDioInterceptor(
      Trailify.instance,
      captureSuccessBodies: false,
      alwaysCaptureBodyPatterns: [RegExp(r'/conversation/message')],
    ));
    dio.httpClientAdapter = _SuccessAdapter(200, {'id': 999});

    await dio.post(
      '/api/v1/conversation/message',
      data: {'text': 'hello'},
    );
    await _waitForLog();

    final payload = Trailify.instance.entries.value.first['payload'] as Map;
    expect(payload.containsKey('requestBody'), isTrue);
    expect(payload.containsKey('responseBody'), isTrue);
  });

  test('large bodies are truncated', () async {
    dio.interceptors.add(TrailifyDioInterceptor(
      Trailify.instance,
      captureSuccessBodies: true,
      maxBodySize: 50,
    ));
    final largeValue = 'x' * 200;
    final largeMap = {'data': largeValue};
    dio.httpClientAdapter = _SuccessAdapter(200, {'ok': true});

    await dio.post('/api/v1/data', data: largeMap);
    await _waitForLog();

    final payload = Trailify.instance.entries.value.first['payload'] as Map;
    final reqBody = payload['requestBody'] as String;
    expect(reqBody.length, lessThan(250));
    expect(reqBody, contains('[TRUNCATED]'));
  });
}

Future<void> _waitForLog() async {
  await Future<void>.delayed(const Duration(milliseconds: 100));
}

class _SuccessAdapter implements HttpClientAdapter {
  final int statusCode;
  final dynamic responseData;

  _SuccessAdapter(this.statusCode, this.responseData);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final body = responseData is String
        ? responseData as String
        : jsonEncode(responseData);
    return ResponseBody.fromString(body, statusCode, headers: {
      Headers.contentTypeHeader: ['application/json'],
    });
  }

  @override
  void close({bool force = false}) {}
}

class _ErrorAdapter implements HttpClientAdapter {
  final int statusCode;
  final dynamic responseData;

  _ErrorAdapter(this.statusCode, this.responseData);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final body = responseData is String
        ? responseData as String
        : jsonEncode(responseData);
    return ResponseBody.fromString(body, statusCode, headers: {
      Headers.contentTypeHeader: ['application/json'],
    });
  }

  @override
  void close({bool force = false}) {}
}
