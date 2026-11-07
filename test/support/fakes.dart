import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Plugin-provided in-memory implementations; never opens the OS keyring.
void resetStorageFakes() {
  FlutterSecureStorage.setMockInitialValues({});
  SharedPreferences.setMockInitialValues({});
}

/// Each request consumes one explicitly queued response. No socket fallback.
class ScriptedAdapter implements HttpClientAdapter {
  final _responses = Queue<Future<ResponseBody>>();
  final requests = <RequestOptions>[];
  final firstRequest = Completer<void>();
  bool isClosed = false;

  Completer<ResponseBody> defer() {
    final response = Completer<ResponseBody>();
    _responses.add(response.future);
    return response;
  }

  void enqueue(
    int status,
    Object? body, {
    String contentType = 'application/json',
  }) {
    _responses.add(Future.value(reply(status, body, contentType: contentType)));
  }

  static ResponseBody reply(
    int status,
    Object? body, {
    String contentType = 'application/json',
  }) {
    final headers = {
      Headers.contentTypeHeader: [contentType],
    };
    if (body is Uint8List) {
      return ResponseBody.fromBytes(body, status, headers: headers);
    }
    return ResponseBody.fromString(
      body is String ? body : jsonEncode(body),
      status,
      headers: headers,
    );
  }

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (isClosed) throw StateError('Fake adapter is closed');
    requests.add(options);
    if (!firstRequest.isCompleted) firstRequest.complete();
    if (_responses.isEmpty) throw StateError('No scripted response');
    return _responses.removeFirst();
  }

  @override
  void close({bool force = false}) => isClosed = true;
}

/// Test-only capture boundary, not an implementation of the future recorder API.
/// A caller controls when stop completes, including completion after disposal.
class FakeCapture {
  int starts = 0;
  int stops = 0;
  bool isDisposed = false;
  final stopped = Completer<Uint8List>();

  Future<void> start() async {
    if (isDisposed) throw StateError('Capture is disposed');
    starts++;
  }

  Future<Uint8List> stop() {
    if (isDisposed) throw StateError('Capture is disposed');
    stops++;
    return stopped.future;
  }

  void dispose() => isDisposed = true;
}
