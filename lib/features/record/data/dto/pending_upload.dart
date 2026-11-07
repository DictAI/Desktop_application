import 'upload_accepted_dto.dart';
import 'upload_options.dart';

enum PendingUploadState { pending, conflict, accepted }

/// Local journal entry. A localId identifies the draft even after acceptance.
final class PendingUpload {
  const PendingUpload({
    required this.ownerId,
    required this.localId,
    required this.createdAt,
    required this.options,
    required this.byteCount,
    required this.sha256,
    this.state = PendingUploadState.pending,
    this.accepted,
  });

  static const schemaVersion = 1;
  static final _ownerPattern = RegExp(
    r'^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$',
  );
  static final _localPattern = RegExp(r'^[a-f0-9]{32}$');
  static final _digestPattern = RegExp(r'^[a-f0-9]{64}$');

  final String ownerId;
  final String localId;
  final DateTime createdAt;
  final UploadOptions options;
  final int byteCount;
  final String sha256;
  final PendingUploadState state;
  final UploadAcceptedDto? accepted;

  static bool validOwnerId(String value) =>
      _ownerPattern.firstMatch(value)?.group(0) == value;

  static bool validLocalId(String value) =>
      _localPattern.firstMatch(value)?.group(0) == value;

  factory PendingUpload.fromJson(Map<String, dynamic> json) {
    final owner = json['owner_id'] as String;
    final id = json['local_id'] as String;
    final created = json['created_at'] as String;
    final timestamp = DateTime.tryParse(created);
    final bytes = json['byte_count'] as int;
    final digest = json['sha256'] as String;
    if (json['version'] is! int ||
        json['version'] != schemaVersion ||
        !validOwnerId(owner) ||
        !validLocalId(id) ||
        timestamp == null ||
        !timestamp.isUtc ||
        timestamp.toIso8601String() != created ||
        bytes <= 0 ||
        _digestPattern.firstMatch(digest)?.group(0) != digest) {
      throw const FormatException('Invalid pending upload entry');
    }
    final state = PendingUploadState.values.byName(json['state'] as String);
    final rawOptions = json['options'] as Map<String, dynamic>;
    if (!rawOptions.containsKey('workspace_id') ||
        !json.containsKey('accepted')) {
      throw const FormatException('Missing pending upload fields');
    }
    final rawSource = rawOptions['source'] as Map<String, dynamic>;
    final source = switch (rawSource['kind']) {
      'imported_wav' => const ImportedWavUploadSource(),
      'recording' when rawSource.containsKey('microphone_device_id') =>
        RecordingUploadSource(
          microphoneDeviceId: rawSource['microphone_device_id'] as String?,
          captureSystemAudio: rawSource['capture_system_audio'] as bool,
        ),
      _ => throw const FormatException('Invalid pending upload source'),
    };
    final options = UploadOptions(
      anonymous: rawOptions['anonymous'] as bool,
      workspaceId: rawOptions['workspace_id'] as String?,
      idempotencyKey: rawOptions['idempotency_key'] as String,
      source: source,
      language: UploadLanguage.values.byName(rawOptions['language'] as String),
      mixed: rawOptions['mixed'] as bool,
    );
    final rawAccepted = json['accepted'];
    final accepted = rawAccepted == null
        ? null
        : UploadAcceptedDto.fromJson(rawAccepted as Map<String, dynamic>);
    if ((state == PendingUploadState.accepted) != (accepted != null) ||
        accepted != null && options.anonymous != (accepted.sessionId != null)) {
      throw const FormatException('Invalid pending upload outcome');
    }
    return PendingUpload(
      ownerId: owner,
      localId: id,
      createdAt: timestamp,
      options: options,
      byteCount: bytes,
      sha256: digest,
      state: state,
      accepted: accepted,
    );
  }

  PendingUpload withOutcome(
    PendingUploadState state, {
    UploadAcceptedDto? accepted,
  }) => PendingUpload(
    ownerId: ownerId,
    localId: localId,
    createdAt: createdAt,
    options: options,
    byteCount: byteCount,
    sha256: sha256,
    state: state,
    accepted: accepted,
  );

  Map<String, Object?> toJson() {
    final acceptance = accepted;
    return {
      'version': schemaVersion,
      'owner_id': ownerId,
      'local_id': localId,
      'created_at': createdAt.toIso8601String(),
      'byte_count': byteCount,
      'sha256': sha256,
      'state': state.name,
      'options': {
        'anonymous': options.anonymous,
        'workspace_id': options.workspaceId,
        'idempotency_key': options.idempotencyKey,
        'language': options.language.name,
        'mixed': options.mixed,
        'source': switch (options.source) {
          ImportedWavUploadSource() => {'kind': 'imported_wav'},
          RecordingUploadSource(
            :final microphoneDeviceId,
            :final captureSystemAudio,
          ) =>
            {
              'kind': 'recording',
              'microphone_device_id': microphoneDeviceId,
              'capture_system_audio': captureSystemAudio,
            },
        },
      },
      'accepted': acceptance == null
          ? null
          : {
              'audio_id': acceptance.audioId,
              'session_id': acceptance.sessionId,
              'job_id': acceptance.jobId,
              'processing_version': acceptance.processingVersion,
              'status_url': acceptance.statusUrl,
            },
    };
  }
}
