import 'dart:async';
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
import '../../core/lifecycle/ios_lifecycle_observer.dart';
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
import '../../features/results/data/documents_api.dart';
import '../../features/results/data/original_audio_cache.dart';
import '../../features/results/data/ios_document_export.dart';
import '../../features/results/presentation/audio_player.dart';
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

final documentsApiProvider = Provider<DocumentsApi>(
  (ref) => DocumentsApi(ref.read(dioProvider)),
);

/// Owned downloads/previews only; tests override this without platform calls.
final resultTemporaryDirectoryProvider = Provider<Future<Directory> Function()>(
  (ref) => getTemporaryDirectory,
);

final iosPlaybackCoordinatorProvider = Provider<IosPlaybackCoordinator?>((ref) {
  return defaultTargetPlatform == TargetPlatform.iOS
      ? IosPlaybackCoordinator()
      : null;
});

final originalAudioCacheProvider = Provider.autoDispose
    .family<OriginalAudioCache, BatchSession>((ref, session) {
      final cache = OriginalAudioCache(
        ownerId: session.ownerId,
        api: ref.read(documentsApiProvider),
        temporaryDirectory: ref.read(resultTemporaryDirectoryProvider),
        isCurrentSession: () => session.isCurrent,
      );
      ref.onDispose(() => unawaited(cache.close().catchError((Object _) {})));
      unawaited(
        session.cancelToken.whenCancel
            .then((_) => cache.close())
            .catchError((Object _) {}),
      );
      return cache;
    });

typedef ResultAudioKey = ({BatchSession session, String audioId, String jobId});
final iosShareSheetProvider = Provider<IosShareSheet>(
  (ref) => NativeIosShareSheet(),
);

final iosDocumentExporterProvider = ChangeNotifierProvider.autoDispose
    .family<IosDocumentExporter, ResultAudioKey>((ref, key) {
      final exporter = IosDocumentExporter(
        api: ref.read(documentsApiProvider),
        sheet: ref.read(iosShareSheetProvider),
        temporaryDirectory: ref.read(resultTemporaryDirectoryProvider),
        isCurrentSession: () =>
            key.session.isCurrent &&
            !key.session.jobs.isDeleted((
              audioId: key.audioId,
              jobId: key.jobId,
            )),
      );
      unawaited(
        key.session.cancelToken.whenCancel
            .then((_) => exporter.close())
            .catchError((Object _) {}),
      );
      return exporter;
    });

final resultAudioControllerProvider = ChangeNotifierProvider.autoDispose
    .family<ResultAudioController, ResultAudioKey>((ref, key) {
      final controller = ResultAudioController(
        cache: ref.watch(originalAudioCacheProvider(key.session)),
        audioId: key.audioId,
        jobId: key.jobId,
        isCurrentSession: () =>
            key.session.isCurrent &&
            !key.session.jobs.isDeleted((
              audioId: key.audioId,
              jobId: key.jobId,
            )),
        coordinator: ref.read(iosPlaybackCoordinatorProvider),
        lifecycle: ref.read(iosLifecycleObserverProvider),
      );
      unawaited(
        key.session.cancelToken.whenCancel
            .then((_) => controller.close())
            .catchError((Object _) {}),
      );
      return controller;
    });

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

/// iOS foreground work shares one observer, independently from recording.
/// A nullable provider keeps desktop polling behavior unchanged and permits
/// injecting a lifecycle source in host tests without opening platform plugins.
final iosLifecycleObserverProvider = Provider<IosLifecycleObserver?>((ref) {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) return null;
  final observer = IosLifecycleObserver();
  ref.onDispose(observer.dispose);
  return observer;
});

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
  IosLifecycleObserver? _lifecycle;
  Future<void>? _restoringJobs;
  bool get isCurrent => !cancelToken.isCancelled;

  void _bindLifecycle(IosLifecycleObserver? lifecycle) {
    if (lifecycle == null || !isCurrent) return;
    _lifecycle = lifecycle;
    lifecycle.addListener(_lifecycleChanged);
    _lifecycleChanged();
  }

  void _lifecycleChanged() {
    if (!isCurrent) return;
    if (_lifecycle?.isForeground != true) {
      _tracker?.suspendPolling();
      return;
    }
    _tracker?.resumePolling();
    unawaited(_restoreJobs());
  }

  Future<void> _restoreJobs() {
    if (!isCurrent) return Future.value();
    return _restoringJobs ??= () async {
      try {
        await _tracker!.restore();
      } on AppException {
        // File protection or unavailable storage must not revoke the session.
        // The library exposes journal errors; the next foreground transition
        // can retry this read. Unknown uploads remain explicit same-key replay.
      }
    }().whenComplete(() => _restoringJobs = null);
  }

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
    _lifecycle?.removeListener(_lifecycleChanged);
    _lifecycle = null;
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
    batch._bindLifecycle(ref.read(iosLifecycleObserverProvider));
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
