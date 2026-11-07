import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'production Dart cannot reintroduce retired voice-profile requests',
    () async {
      final retired = RegExp(
        r'/voice-profiles(?:/|[\x22\x27])|VoiceProfile(?:Api|Dto)|voiceProfileApiProvider|voice_profile/data/',
      );
      final callers = <String>[];
      await for (final file in Directory('lib').list(recursive: true)) {
        if (file is File && file.path.endsWith('.dart')) {
          if (retired.hasMatch(await file.readAsString())) {
            callers.add(file.path);
          }
        }
      }
      expect(
        callers,
        isEmpty,
        reason: 'Retired APIs must have no runtime wiring.',
      );
    },
  );
}
