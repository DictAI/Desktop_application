class ParticipantDto {
  final String participantId;
  final String workspaceId;
  final String name;
  final String email;
  final String? voiceProfileId;

  const ParticipantDto({
    required this.participantId,
    required this.workspaceId,
    required this.name,
    required this.email,
    this.voiceProfileId,
  });

  factory ParticipantDto.fromJson(Map<String, dynamic> json) => ParticipantDto(
        participantId: json['participant_id'] as String,
        workspaceId: json['workspace_id'] as String,
        name: json['name'] as String,
        email: json['email'] as String,
        voiceProfileId: json['voice_profile_id'] as String?,
      );

  ParticipantDto copyWith({
    String? participantId,
    String? workspaceId,
    String? name,
    String? email,
    String? voiceProfileId,
  }) =>
      ParticipantDto(
        participantId: participantId ?? this.participantId,
        workspaceId: workspaceId ?? this.workspaceId,
        name: name ?? this.name,
        email: email ?? this.email,
        voiceProfileId: voiceProfileId ?? this.voiceProfileId,
      );

  Map<String, dynamic> toJson() => {
        'participant_id': participantId,
        'workspace_id': workspaceId,
        'name': name,
        'email': email,
        if (voiceProfileId != null) 'voice_profile_id': voiceProfileId,
      };
}
