import 'dart:convert';

import '../../../../core/error/app_exception.dart';

enum UploadLanguage {
  auto(''),
  ru('ru'),
  en('en');

  const UploadLanguage(this.wireValue);
  final String wireValue;
}

/// Local source choice; none of these fields become multipart metadata.
sealed class UploadSource {
  const UploadSource();
}

final class RecordingUploadSource extends UploadSource {
  factory RecordingUploadSource({
    String? microphoneDeviceId,
    bool captureSystemAudio = false,
  }) {
    if (microphoneDeviceId != null && microphoneDeviceId.isEmpty) {
      throw const ValidationException('Select an available microphone.');
    }
    return RecordingUploadSource._(microphoneDeviceId, captureSystemAudio);
  }

  const RecordingUploadSource._(
    this.microphoneDeviceId,
    this.captureSystemAudio,
  );

  /// Null means the default microphone. System audio is additional to mic.
  final String? microphoneDeviceId;
  final bool captureSystemAudio;
}

final class ImportedWavUploadSource extends UploadSource {
  const ImportedWavUploadSource();
}

/// Construct once before Start (or before sending an imported WAV). Retain the
/// same instance/key for finish and retries; changing form state creates a new
/// snapshot, never mutates an active one. File identity belongs to the journal.
final class UploadOptions {
  factory UploadOptions({
    required bool anonymous,
    String? workspaceId,
    required String idempotencyKey,
    required UploadSource source,
    UploadLanguage language = UploadLanguage.auto,
    bool mixed = false,
  }) {
    if (anonymous) {
      if (workspaceId != null && workspaceId.isNotEmpty) {
        throw const ValidationException(
          'Upload without a workspace cannot select one.',
        );
      }
    } else if (workspaceId == null ||
        _uuid.firstMatch(workspaceId)?.group(0) != workspaceId) {
      throw const ValidationException(
        'Select a valid workspace before starting.',
      );
    }
    if (mixed && language != UploadLanguage.auto) {
      throw const ValidationException(
        'Mixed speech requires automatic language.',
      );
    }
    if (!_validKey(idempotencyKey)) {
      throw const ValidationException(
        'Use an upload key of 1–128 UTF-8 bytes without surrounding whitespace, NUL or line breaks.',
      );
    }
    return UploadOptions._(
      anonymous: anonymous,
      workspaceId: anonymous ? null : workspaceId!.toLowerCase(),
      idempotencyKey: idempotencyKey,
      source: source,
      language: language,
      mixed: mixed,
    );
  }

  const UploadOptions._({
    required this.anonymous,
    required this.workspaceId,
    required this.idempotencyKey,
    required this.source,
    required this.language,
    required this.mixed,
  });

  final bool anonymous;
  final String? workspaceId;
  final String idempotencyKey;
  final UploadSource source;
  final UploadLanguage language;
  final bool mixed;

  /// Only U01/U02 fields. The key is sent as Idempotency-Key, not a form field.
  Map<String, String> toMultipartFields() => Map.unmodifiable({
    if (workspaceId != null) 'workspace_id': workspaceId!,
    'language': language.wireValue,
    'mixed': mixed.toString(),
  });

  static final _uuid = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  static bool _validKey(String key) {
    if (key.isEmpty ||
        key.length > 128 ||
        key.contains(RegExp(r'[\x00\r\n]'))) {
      return false;
    }
    // Reject malformed UTF-16 rather than silently replacing it in UTF-8.
    final units = key.codeUnits;
    for (var i = 0; i < units.length; i++) {
      final unit = units[i];
      if (unit >= 0xd800 && unit <= 0xdbff) {
        if (++i >= units.length || units[i] < 0xdc00 || units[i] > 0xdfff) {
          return false;
        }
      } else if (unit >= 0xdc00 && unit <= 0xdfff) {
        return false;
      }
    }
    return utf8.encode(key).length <= 128 &&
        !_goSpace(key.runes.first) &&
        !_goSpace(key.runes.last);
  }

  // Go strings.TrimSpace uses Unicode White_Space, which differs from Dart trim
  // for BOM. Preserve input exactly; never trim/rewrite an idempotency key.
  static bool _goSpace(int rune) =>
      rune >= 0x09 && rune <= 0x0d ||
      rune == 0x20 ||
      rune == 0x85 ||
      rune == 0xa0 ||
      rune == 0x1680 ||
      rune >= 0x2000 && rune <= 0x200a ||
      rune == 0x2028 ||
      rune == 0x2029 ||
      rune == 0x202f ||
      rune == 0x205f ||
      rune == 0x3000;
}
