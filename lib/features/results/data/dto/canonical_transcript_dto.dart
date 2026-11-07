import 'dart:convert';

enum CanonicalSpeechState { speech, noSpeech }

enum CanonicalEngineRole { asr, diarization, combined }

enum CanonicalWordTiming { available, unavailable }

/// Immutable dictai-transcript/v1. Time values are original recording offsets
/// in microseconds; speakers are local labels, never participant identities.
final class CanonicalTranscriptDto {
  CanonicalTranscriptDto._({
    required this.schemaVersion,
    required this.recordingId,
    required this.jobId,
    required this.processingVersion,
    required this.access,
    required this.durationUs,
    required this.speechState,
    required this.language,
    required this.engines,
    required this.speakers,
    required this.segments,
  });

  static const supportedSchemaVersion = 'dictai-transcript/v1';
  static const maxTimeUs = 9007199254740991;
  static const unknownSpeaker = 'UNKNOWN';

  final String schemaVersion;
  final String recordingId;
  final String jobId;
  final String processingVersion;
  final CanonicalAccessDto access;
  final int durationUs;
  final CanonicalSpeechState speechState;
  final String? language;
  final List<CanonicalEngineDto> engines;
  final List<CanonicalSpeakerDto> speakers;
  final List<CanonicalSegmentDto> segments;

  factory CanonicalTranscriptDto.fromJson(Map<String, dynamic> json) {
    _keys(json, const {
      'schema_version',
      'recording_id',
      'job_id',
      'processing_version',
      'access',
      'duration_us',
      'speech_state',
      'language',
      'engines',
      'speakers',
      'segments',
    });
    // A new version is not interpreted using v1 assumptions or shown as empty.
    if (json['schema_version'] != supportedSchemaVersion) _invalid();
    final result = CanonicalTranscriptDto._(
      schemaVersion: supportedSchemaVersion,
      recordingId: _id(json['recording_id']),
      jobId: _id(json['job_id']),
      processingVersion: _id(json['processing_version']),
      access: CanonicalAccessDto.fromJson(_object(json['access'])),
      durationUs: _time(json['duration_us'], positive: true),
      speechState: switch (json['speech_state']) {
        'speech' => CanonicalSpeechState.speech,
        'no_speech' => CanonicalSpeechState.noSpeech,
        _ => _invalid(),
      },
      language: _language(json['language']),
      engines: _list(json['engines'], CanonicalEngineDto.fromJson),
      speakers: _list(json['speakers'], CanonicalSpeakerDto.fromJson),
      segments: _list(json['segments'], CanonicalSegmentDto.fromJson),
    );
    result._validate();
    return result;
  }

  void _validate() {
    final roles = engines.map((engine) => engine.role).toSet();
    if (roles.length != engines.length ||
        !(roles.length == 1 && roles.contains(CanonicalEngineRole.combined) ||
            roles.length == 2 &&
                roles.contains(CanonicalEngineRole.asr) &&
                roles.contains(CanonicalEngineRole.diarization))) {
      _invalid();
    }
    if (speechState == CanonicalSpeechState.noSpeech) {
      if (speakers.isNotEmpty || segments.isNotEmpty) _invalid();
      return;
    }
    if (segments.isEmpty) _invalid();
    final first = <String, int>{};
    final lastEnd = <String, int>{};
    for (var i = 0; i < speakers.length; i++) {
      final speaker = speakers[i];
      if (speaker.speakerId != 'speaker_${i + 1}' ||
          speaker.label != 'Speaker ${i + 1}') {
        _invalid();
      }
      first[speaker.speakerId] = -1;
    }
    for (var i = 0; i < segments.length; i++) {
      final segment = segments[i];
      _interval(segment.startUs, segment.endUs, 0, durationUs);
      if (i > 0 && _compareSegments(segments[i - 1], segment) >= 0) _invalid();
      if (segment.speakerId != unknownSpeaker) {
        if (!first.containsKey(segment.speakerId) ||
            segment.startUs < (lastEnd[segment.speakerId] ?? 0)) {
          _invalid();
        }
        if (first[segment.speakerId] == -1) {
          first[segment.speakerId] = segment.startUs;
        }
        lastEnd[segment.speakerId] = segment.endUs;
      }
      if ((segment.wordTiming == CanonicalWordTiming.unavailable) !=
          segment.words.isEmpty) {
        _invalid();
      }
      for (var j = 0; j < segment.words.length; j++) {
        final word = segment.words[j];
        _interval(word.startUs, word.endUs, segment.startUs, segment.endUs);
        if (j > 0 && word.startUs < segment.words[j - 1].endUs) _invalid();
      }
    }
    var previous = -1;
    for (final speaker in speakers) {
      final start = first[speaker.speakerId]!;
      if (start < 0 || start < previous) _invalid();
      previous = start;
    }
  }
}

final class CanonicalAccessDto {
  const CanonicalAccessDto._(this.ownerUserId, this.workspaceId);
  final String ownerUserId;
  final String? workspaceId;

  factory CanonicalAccessDto.fromJson(Map<String, dynamic> json) {
    _keys(json, const {'owner_user_id', 'workspace_id'});
    return CanonicalAccessDto._(
      _id(json['owner_user_id']),
      json['workspace_id'] == null ? null : _id(json['workspace_id']),
    );
  }
}

final class CanonicalEngineDto {
  const CanonicalEngineDto._(this.role, this.name, this.model, this.revision);
  final CanonicalEngineRole role;
  final String name;
  final String model;
  final String revision;

  factory CanonicalEngineDto.fromJson(Map<String, dynamic> json) {
    _keys(json, const {'role', 'name', 'model', 'revision'});
    return CanonicalEngineDto._(
      switch (json['role']) {
        'asr' => CanonicalEngineRole.asr,
        'diarization' => CanonicalEngineRole.diarization,
        'combined' => CanonicalEngineRole.combined,
        _ => _invalid(),
      },
      _id(json['name']),
      _id(json['model']),
      _id(json['revision']),
    );
  }
}

final class CanonicalSpeakerDto {
  const CanonicalSpeakerDto._(this.speakerId, this.label);
  final String speakerId;
  final String label;

  factory CanonicalSpeakerDto.fromJson(Map<String, dynamic> json) {
    _keys(json, const {'speaker_id', 'label'});
    return CanonicalSpeakerDto._(_id(json['speaker_id']), _id(json['label']));
  }
}

final class CanonicalSegmentDto {
  const CanonicalSegmentDto._({
    required this.startUs,
    required this.endUs,
    required this.speakerId,
    required this.text,
    required this.confidence,
    required this.language,
    required this.wordTiming,
    required this.words,
  });
  final int startUs;
  final int endUs;
  final String speakerId;
  final String text;
  final double? confidence;
  final String? language;
  final CanonicalWordTiming wordTiming;
  final List<CanonicalWordDto> words;

  factory CanonicalSegmentDto.fromJson(Map<String, dynamic> json) {
    _keys(json, const {
      'start_us',
      'end_us',
      'speaker_id',
      'text',
      'confidence',
      'language',
      'word_timing',
      'words',
    });
    return CanonicalSegmentDto._(
      startUs: _time(json['start_us']),
      endUs: _time(json['end_us']),
      speakerId: _id(json['speaker_id']),
      text: _text(json['text']),
      confidence: _confidence(json['confidence']),
      language: _language(json['language']),
      wordTiming: switch (json['word_timing']) {
        'available' => CanonicalWordTiming.available,
        'unavailable' => CanonicalWordTiming.unavailable,
        _ => _invalid(),
      },
      words: _list(json['words'], CanonicalWordDto.fromJson),
    );
  }
}

final class CanonicalWordDto {
  const CanonicalWordDto._({
    required this.startUs,
    required this.endUs,
    required this.text,
    required this.confidence,
    required this.language,
  });
  final int startUs;
  final int endUs;
  final String text;
  final double? confidence;
  final String? language;

  factory CanonicalWordDto.fromJson(Map<String, dynamic> json) {
    _keys(json, const {'start_us', 'end_us', 'text', 'confidence', 'language'});
    return CanonicalWordDto._(
      startUs: _time(json['start_us']),
      endUs: _time(json['end_us']),
      text: _text(json['text']),
      confidence: _confidence(json['confidence']),
      language: _language(json['language']),
    );
  }
}

// Private helpers apply the current speech schema/Go validator. They never
// include text or identifiers from a response in diagnostics or mutate input.
Never _invalid() => throw const FormatException('Invalid canonical transcript');

Map<String, dynamic> _object(Object? value) =>
    value is Map<String, dynamic> ? value : _invalid();

void _keys(Map<String, dynamic> json, Set<String> keys) {
  if (json.length != keys.length || !keys.every(json.containsKey)) _invalid();
}

List<T> _list<T>(Object? value, T Function(Map<String, dynamic>) decode) {
  if (value is! List) _invalid();
  return List.unmodifiable(value.map((item) => decode(_object(item))));
}

int _time(Object? value, {bool positive = false}) {
  if (value is! int ||
      value < (positive ? 1 : 0) ||
      value > CanonicalTranscriptDto.maxTimeUs) {
    _invalid();
  }
  return value;
}

void _interval(int start, int end, int lower, int upper) {
  if (start < lower || end > upper || start >= end) _invalid();
}

// Go strings.TrimSpace uses this Unicode White_Space set (not Dart's BOM trim).
final _space = RegExp(
  r'[\u0009-\u000D\u0020\u0085\u00A0\u1680\u2000-\u200A\u2028\u2029\u202F\u205F\u3000]',
);
final _tag = RegExp(r'^[A-Za-z]{2,8}(-[A-Za-z0-9]{1,8})*$');

String _string(Object? value) {
  if (value is! String) _invalid();
  // Reject lone UTF-16 surrogates instead of replacing them during UTF-8 use.
  final units = value.codeUnits;
  for (var i = 0; i < units.length; i++) {
    final unit = units[i];
    if (unit >= 0xD800 && unit <= 0xDBFF) {
      if (++i >= units.length || units[i] < 0xDC00 || units[i] > 0xDFFF) {
        _invalid();
      }
    } else if (unit >= 0xDC00 && unit <= 0xDFFF) {
      _invalid();
    }
  }
  return value;
}

String _id(Object? value) {
  final text = _string(value);
  if (text.isEmpty ||
      _space.hasMatch(text[0]) ||
      _space.hasMatch(text[text.length - 1])) {
    _invalid();
  }
  return text;
}

String _text(Object? value) {
  final text = _string(value);
  if (text.replaceAll(_space, '').isEmpty) _invalid();
  return text;
}

String? _language(Object? value) {
  if (value == null) return null;
  final text = _string(value);
  final match = _tag.firstMatch(text);
  if (match == null || match.end != text.length) _invalid();
  return text;
}

double? _confidence(Object? value) {
  if (value == null) return null;
  if (value is! num || !value.isFinite || value < 0 || value > 1) _invalid();
  return value.toDouble();
}

int _compareSegments(CanonicalSegmentDto a, CanonicalSegmentDto b) {
  var order = a.startUs.compareTo(b.startUs);
  if (order != 0) return order;
  order = a.endUs.compareTo(b.endUs);
  if (order != 0) return order;
  order = a.speakerId.compareTo(b.speakerId);
  if (order != 0) return order;
  final left = utf8.encode(a.text);
  final right = utf8.encode(b.text);
  for (var i = 0; i < left.length && i < right.length; i++) {
    order = left[i].compareTo(right[i]);
    if (order != 0) return order;
  }
  return left.length.compareTo(right.length);
}
