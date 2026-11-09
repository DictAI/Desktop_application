import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import '../../core/error/app_exception.dart';
import '../../core/network/api_client.dart';
import '../../core/storage/secure_storage.dart';
import '../../core/config/app_config.dart';
import '../../features/auth/data/auth_api.dart';
import '../../features/auth/presentation/auth_notifier.dart';
import '../../features/workspace/data/workspace_api.dart';
import '../../features/record/data/audio_ingest_api.dart';
import '../../features/record/data/anonymous_session_api.dart';
import '../../features/record/data/anthropic_service.dart';
import '../../features/record/data/dto/pending_upload.dart';
import '../../features/record/data/pending_upload_store.dart';
import '../../features/record/data/v2_upload_api.dart';
import '../../features/results/data/results_api.dart';
import '../../features/results/data/canonical_api.dart';
import '../../features/results/data/speech_status_api.dart';
import '../../features/results/data/pending_job_store.dart';
import '../../features/results/presentation/processing_notifier.dart';

// ── Storage ──────────────────────────────────────────────────────────────────

final secureStorageProvider = Provider<SecureStorage>((ref) {
  return const SecureStorage();
});

// ── Session notifier — fires when token is deleted externally (401) ───────────

final sessionNotifierProvider = ChangeNotifierProvider<_SessionNotifier>(
  (ref) => _SessionNotifier(),
);

class _SessionNotifier extends ChangeNotifier {
  void invalidate() => notifyListeners();
}

// ── Dio ──────────────────────────────────────────────────────────────────────

final appConfigProvider = Provider<AppConfig>(
  (ref) => AppConfig.fromEnvironment(),
);

final dioProvider = Provider<Dio>((ref) {
  final storage = ref.read(secureStorageProvider);
  final session = ref.read(sessionNotifierProvider);
  final config = ref.read(appConfigProvider);
  return createDio(
    baseUrl: config.baseUrl,
    appConfig: config,
    enableNetworkDiagnostics: config.networkDiagnostics,
    storage: storage,
    onUnauthorized: () async => session.invalidate(),
  );
});

// ── API clients ───────────────────────────────────────────────────────────────

final authApiProvider = Provider<AuthApi>(
  (ref) => AuthApi(ref.read(dioProvider)),
);

final workspaceApiProvider = Provider<WorkspaceApi>(
  (ref) => WorkspaceApi(ref.read(dioProvider)),
);

final audioIngestApiProvider = Provider<AudioIngestApi>(
  (ref) => AudioIngestApi(ref.read(dioProvider)),
);

final resultsApiProvider = Provider<ResultsApi>(
  (ref) => ResultsApi(ref.read(dioProvider)),
);

final speechStatusApiProvider = Provider<SpeechStatusApi>(
  (ref) => SpeechStatusApi(ref.read(dioProvider)),
);

final canonicalApiProvider = Provider<CanonicalApi>(
  (ref) => CanonicalApi(ref.read(dioProvider)),
);

final processingNotifierProvider = StateNotifierProvider.autoDispose
    .family<
      ProcessingNotifier,
      Map<ProcessingKey, JobProgress>,
      ProcessingSession
    >(
      (ref, session) => ProcessingNotifier(
        store: session.store,
        statusApi: ref.read(speechStatusApiProvider),
        canonicalApi: ref.read(canonicalApiProvider),
        isCurrentSession: session.isCurrentSession,
      ),
    );

final batchApplicationSupportDirectoryProvider =
    Provider<Future<Directory> Function()>(
      (ref) => getApplicationSupportDirectory,
    );

/// One owner, journal, and processing tracker for the logical login session.
/// The owner claim selects a local directory. Authorization remains at the gateway.
final class BatchSession {
  BatchSession._(
    this.ownerId,
    this._api,
    Future<Directory> Function() support,
  ) {
    uploads = PendingUploadStore(
      ownerId: ownerId,
      isCurrentSession: () => isCurrent,
      applicationSupportDirectory: support,
    );
    jobs = PendingJobStore(uploads: uploads, isCurrentSession: () => isCurrent);
    processingSession = ProcessingSession(
      store: jobs,
      isCurrentSession: () => isCurrent,
    );
  }

  final String ownerId;
  final V2UploadApi _api;
  final cancelToken = CancelToken();
  late final PendingUploadStore uploads;
  late final PendingJobStore jobs;
  late final ProcessingSession processingSession;
  ProcessingNotifier? _tracker;
  bool get isCurrent => !cancelToken.isCancelled;

  Future<PendingUpload> submit(
    String localId, {
    ProgressCallback? onSendProgress,
  }) async {
    if (!isCurrent) throw const UnauthorizedException();
    final receipt = await uploads.submit(
      localId,
      api: _api,
      cancelToken: cancelToken,
      onSendProgress: onSendProgress,
    );
    if (!isCurrent) throw const UnauthorizedException();
    _tracker!.track(jobs.fromAccepted(receipt));
    return receipt;
  }

  void _close() {
    if (!isCurrent) return;
    cancelToken.cancel();
    _tracker?.stopSession();
  }
}

final batchSessionProvider = FutureProvider.autoDispose<BatchSession>((
  ref,
) async {
  final lease = ref.keepAlive();
  final auth = ref.read(authNotifierProvider.notifier);
  final storage = ref.read(secureStorageProvider);
  final api = V2UploadApi(ref.read(dioProvider));
  final support = ref.read(batchApplicationSupportDirectoryProvider);
  BatchSession? session;
  var current = true;

  void close() {
    current = false;
    session?._close();
  }

  void replaceSession() {
    close();
    ref.invalidateSelf();
  }

  ref.onDispose(close);
  // Login/logout publish loading before the credential write. Cancel the old
  // request tokens synchronously, before AuthInterceptor can read another JWT.
  ref.listen(authNotifierProvider, (_, __) => replaceSession());
  ref.listen(sessionNotifierProvider, (_, __) => replaceSession());

  try {
    if (ref.read(authNotifierProvider).status == AuthStatus.loading ||
        !await auth.hasValidSession() ||
        !current) {
      throw const UnauthorizedException();
    }
    final credential = await storage.readCredential();
    final ownerId = _journalOwner(credential?.token);
    if (!current || ownerId == null) throw const UnauthorizedException();

    final batch = BatchSession._(ownerId, api, support);
    session = batch;
    final tracker = processingNotifierProvider(batch.processingSession);
    // Keep polling alive when switching screens. Revocation closes this lease
    // and cancels the tracker before any new owner instance can be opened.
    ref.listen(tracker, (_, __) {});
    batch._tracker = ref.read(tracker.notifier);
    return batch;
  } catch (_) {
    lease.close();
    rethrow;
  }
});

String? _journalOwner(String? token) {
  final parts = token?.split('.');
  if (parts == null || parts.length != 3) return null;
  try {
    final payload = jsonDecode(
      utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
    );
    final owner = payload is Map ? payload['user_id'] : null;
    return owner is String && PendingUpload.validOwnerId(owner) ? owner : null;
  } on FormatException {
    return null;
  }
}

final anthropicServiceProvider = Provider<AnthropicService>(
  (ref) => AnthropicService(ref.read(secureStorageProvider)),
);

final anonymousSessionApiProvider = Provider<AnonymousSessionApi>(
  (ref) => AnonymousSessionApi(ref.read(dioProvider)),
);
