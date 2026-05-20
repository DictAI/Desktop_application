class VoiceProfileDto {
  final String voiceProfileId;
  final String? participantId;
  final String displayName;
  final DateTime? createdAt;

  const VoiceProfileDto({
    required this.voiceProfileId,
    required this.displayName,
    this.participantId,
    this.createdAt,
  });

  factory VoiceProfileDto.fromJson(Map<String, dynamic> json) {
    final createdAtRaw = json['created_at'] as String?;
    return VoiceProfileDto(
      voiceProfileId: json['voice_profile_id'] as String,
      participantId: json['participant_id'] as String?,
      displayName: (json['display_name'] as String?)?.trim().isNotEmpty == true
          ? (json['display_name'] as String).trim()
          : 'Voice profile',
      createdAt: createdAtRaw == null ? null : DateTime.tryParse(createdAtRaw),
    );
  }
}
