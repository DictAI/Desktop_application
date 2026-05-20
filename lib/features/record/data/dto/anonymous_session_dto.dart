class SegmentDto {
  final double start;
  final double end;
  final String text;

  const SegmentDto({
    required this.start,
    required this.end,
    required this.text,
  });

  factory SegmentDto.fromJson(Map<String, dynamic> json) => SegmentDto(
        start: (json['start'] as num).toDouble(),
        end: (json['end'] as num).toDouble(),
        text: json['text'] as String? ?? '',
      );
}

class SpeakerDto {
  final String speakerId;
  final String label;
  final String fragmentUrl;
  final List<SegmentDto> segments;

  const SpeakerDto({
    required this.speakerId,
    required this.label,
    required this.fragmentUrl,
    required this.segments,
  });

  factory SpeakerDto.fromJson(Map<String, dynamic> json) => SpeakerDto(
        speakerId: json['speaker_id'] as String,
        label: json['label'] as String,
        fragmentUrl: json['fragment_url'] as String? ?? '',
        segments: (json['segments'] as List<dynamic>? ?? [])
            .map((e) => SegmentDto.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  String get previewText {
    if (segments.isEmpty) return '';
    final text = segments.first.text.trim();
    return text.length > 80 ? '${text.substring(0, 80)}…' : text;
  }
}

class AnonymousSessionDto {
  final String sessionId;
  final String audioId;
  final String status;
  final List<SpeakerDto> speakers;

  const AnonymousSessionDto({
    required this.sessionId,
    required this.audioId,
    required this.status,
    required this.speakers,
  });

  bool get isProcessing => status == 'processing';
  bool get isReady => status == 'ready';
  bool get isConfirmed => status == 'confirmed';
  bool get isExpired => status == 'expired';

  factory AnonymousSessionDto.fromJson(Map<String, dynamic> json) =>
      AnonymousSessionDto(
        sessionId: json['session_id'] as String,
        audioId: json['audio_id'] as String,
        status: json['status'] as String,
        speakers: (json['speakers'] as List<dynamic>? ?? [])
            .map((e) => SpeakerDto.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class SpeakerAssignment {
  final String label;
  final String name;
  final String email;

  const SpeakerAssignment({
    required this.label,
    required this.name,
    required this.email,
  });

  Map<String, dynamic> toJson() => {
        'label': label,
        'name': name,
        'email': email,
      };
}
