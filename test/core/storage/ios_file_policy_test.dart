import 'dart:io';

import 'package:dict_ai/core/error/app_exception.dart';
import 'package:dict_ai/core/storage/ios_file_policy.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('dictai.test.ios_file_policy');
  const policy = IosFilePolicy(channel: channel, enabled: true);
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final calls = <MethodCall>[];

  setUp(() => calls.clear());
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test(
    'protects directory and final file through verified native response',
    () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        return {
          'excludedFromBackup': true,
          'protection': 'completeUntilFirstUserAuthentication',
          'protectionVerified': true,
          'environment': 'device',
        };
      });
      await policy.prepare(Directory('/synthetic/dictai-original-owned'));
      await policy.protect(File('/synthetic/dictai-original-owned/source.wav'));
      expect(calls.map((call) => call.method), ['protect', 'protect']);
      expect(calls.first.arguments, {
        'path': '/synthetic/dictai-original-owned',
      });
      expect(calls.last.arguments, {
        'path': '/synthetic/dictai-original-owned/source.wav',
      });
    },
  );

  test('rejects missing or unverified native attributes', () async {
    for (final response in <Object?>[
      null,
      true,
      {},
      {
        'excludedFromBackup': false,
        'protection': 'completeUntilFirstUserAuthentication',
      },
      {'excludedFromBackup': true, 'protection': 'none'},
      {'excludedFromBackup': true},
      {
        'excludedFromBackup': true,
        'protection': 'completeUntilFirstUserAuthentication',
        'protectionVerified': false,
        'environment': 'device',
      },
      {
        'excludedFromBackup': true,
        'protection': 'unsupportedInSimulator',
        'protectionVerified': false,
        'environment': 'device',
      },
      {
        'excludedFromBackup': true,
        'protection': 'unsupportedInSimulator',
        'protectionVerified': true,
        'environment': 'simulator',
      },
      {
        'excludedFromBackup': true,
        'protection': 'completeUntilFirstUserAuthentication',
        'protectionVerified': true,
        'environment': 'unknown',
      },
    ]) {
      messenger.setMockMethodCallHandler(channel, (_) async => response);
      await expectLater(
        policy.protect(File('/synthetic/source.wav')),
        throwsA(isA<ValidationException>()),
      );
    }
  });

  test(
    'accepts explicit Simulator capability with verified backup exclusion',
    () async {
      messenger.setMockMethodCallHandler(
        channel,
        (_) async => {
          'excludedFromBackup': true,
          'protection': 'unsupportedInSimulator',
          'protectionVerified': false,
          'environment': 'simulator',
        },
      );
      await policy.prepare(Directory('/synthetic/dictai-original-simulator'));
      messenger.setMockMethodCallHandler(
        channel,
        (_) async => {
          'excludedFromBackup': false,
          'protection': 'unsupportedInSimulator',
          'protectionVerified': false,
          'environment': 'simulator',
        },
      );
      await expectLater(
        policy.prepare(Directory('/synthetic/dictai-original-simulator')),
        throwsA(isA<ValidationException>()),
      );
    },
  );

  test(
    'native failure and missing bridge fail closed without private details',
    () async {
      messenger.setMockMethodCallHandler(channel, (_) async {
        throw PlatformException(
          code: 'denied',
          message: 'SYNTHETIC_PRIVATE_PATH',
        );
      });
      try {
        await policy.prepare(Directory('/synthetic/private'));
        fail('Native failure must not be ignored.');
      } on ValidationException catch (error) {
        expect(error.toString(), isNot(contains('SYNTHETIC_PRIVATE_PATH')));
        expect(error.toString(), isNot(contains('/synthetic/private')));
      }
      messenger.setMockMethodCallHandler(channel, null);
      await expectLater(
        policy.prepare(Directory('/synthetic/private')),
        throwsA(isA<ValidationException>()),
      );
    },
  );

  test('disabled policy is inert and does not access platform or disk', () async {
    messenger.setMockMethodCallHandler(channel, (_) async {
      fail('Disabled policy must not invoke native methods.');
    });
    const disabled = IosFilePolicy(channel: channel, enabled: false);
    await disabled.prepare(Directory('/does-not-exist'));
    await disabled.protect(File('/does-not-exist/source.wav'));
    if (!Platform.isIOS) {
      // Host widget target overrides must not accidentally open the real bridge.
      await const IosFilePolicy(
        channel: channel,
      ).prepare(Directory('/missing'));
    }
  });
}
