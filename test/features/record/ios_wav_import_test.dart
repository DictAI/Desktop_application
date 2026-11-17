import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:dict_ai/core/config/app_config.dart';
import 'package:dict_ai/core/error/app_exception.dart';
import 'package:dict_ai/core/storage/ios_file_policy.dart';
import 'package:dict_ai/core/theme/app_theme.dart';
import 'package:dict_ai/features/record/data/dto/upload_options.dart';
import 'package:dict_ai/features/record/data/ios_wav_import.dart';
import 'package:dict_ai/features/record/data/wav_validator.dart';
import 'package:dict_ai/features/record/presentation/record_notifier.dart';
import 'package:dict_ai/features/record/presentation/upload_modal.dart';
import 'package:dict_ai/shared/providers/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:file_picker/file_picker.dart';

import '../../support/fakes.dart';

Uint8List _wav({int samples = 2}) {
  final bytes = ByteData(44 + samples * 2);
  void tag(int offset, String value) {
    for (var i = 0; i < value.length; i++) {
      bytes.setUint8(offset + i, value.codeUnitAt(i));
    }
  }

  tag(0, 'RIFF');
  bytes.setUint32(4, bytes.lengthInBytes - 8, Endian.little);
  tag(8, 'WAVE');
  tag(12, 'fmt ');
  bytes.setUint32(16, 16, Endian.little);
  bytes.setUint16(20, 1, Endian.little);
  bytes.setUint16(22, 1, Endian.little);
  bytes.setUint32(24, 16000, Endian.little);
  bytes.setUint32(28, 32000, Endian.little);
  bytes.setUint16(32, 2, Endian.little);
  bytes.setUint16(34, 16, Endian.little);
  tag(36, 'data');
  bytes.setUint32(40, samples * 2, Endian.little);
  return bytes.buffer.asUint8List();
}

class _Record extends RecordNotifier {
  _Record()
    : super(
        captureFactory: (_) => throw StateError('No capture in picker tests'),
        session: () => throw StateError('No backend in picker tests'),
      );

  final entered = Completer<void>();
  final complete = Completer<void>();
  final files = <File>[];
  UploadLanguage? language;
  bool? mixed;

  @override
  Future<void> uploadFile(
    File file, {
    UploadLanguage? language,
    bool? mixed,
  }) async {
    files.add(file);
    this.language = language;
    this.mixed = mixed;
    entered.complete();
    await complete.future;
  }
}

class _ReadFailureFile implements File {
  _ReadFailureFile(this.source);
  final File source;
  var opens = 0;

  @override
  Uri get uri => source.uri;
  @override
  Future<FileStat> stat() => source.stat();
  @override
  Future<RandomAccessFile> open({FileMode mode = FileMode.read}) async {
    final handle = await source.open(mode: mode);
    return ++opens == 2 ? _ReadFailureHandle(handle) : handle;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ReadFailureHandle implements RandomAccessFile {
  _ReadFailureHandle(this.handle);
  final RandomAccessFile handle;
  var reads = 0;

  @override
  Future<Uint8List> read(int count) {
    if (++reads > 1) {
      throw const FileSystemException(
        'Provider lost access',
        '/private/provider',
      );
    }
    return handle.read(count);
  }

  @override
  Future<void> close() => handle.close();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late Directory staging;
  late File source;

  setUp(() async {
    resetStorageFakes();
    directory = await Directory.systemTemp.createTemp('dictai-import-test-');
    staging = await Directory('${directory.path}/staging').create();
    source = await File('${directory.path}/meeting.wav').writeAsBytes(_wav());
  });
  tearDown(() async => directory.delete(recursive: true));

  IosWavImporter importer({Future<File?> Function()? pick}) => IosWavImporter(
    pickFile: pick ?? () async => source,
    temporaryDirectory: () async => staging,
  );

  test(
    'copies validated WAV into a unique owned file and preserves source',
    () async {
      final first = (await importer().pick(isCurrent: () => true))!;
      final second = (await importer().pick(isCurrent: () => true))!;
      expect(first.file.path, isNot(source.path));
      expect(second.file.path, isNot(first.file.path));
      expect(await first.file.readAsBytes(), _wav());
      expect(first.name, 'meeting.wav');
      expect(first.metadata.sampleRate, 16000);
      await source.writeAsBytes(_wav(samples: 4));
      expect(await first.file.readAsBytes(), _wav());
      await first.discard();
      await first.discard();
      expect(await first.file.exists(), isFalse);
      expect(await source.exists(), isTrue);
      expect(await second.file.exists(), isTrue);
      await second.discard();
      expect(await staging.list().toList(), isEmpty);
    },
  );

  test(
    'native protection rejection removes only private import staging',
    () async {
      const channel = MethodChannel('test.dictai/import_policy');
      final calls = <String>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            final path = (call.arguments as Map)['path'] as String;
            calls.add(path);
            if (path.endsWith('source.wav')) {
              throw PlatformException(code: 'attributes_unavailable');
            }
            return {
              'excludedFromBackup': true,
              'protection': 'completeUntilFirstUserAuthentication',
              'protectionVerified': true,
              'environment': 'device',
            };
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );
      await expectLater(
        IosWavImporter(
          pickFile: () async => source,
          temporaryDirectory: () async => staging,
          filePolicy: const IosFilePolicy(channel: channel, enabled: true),
        ).pick(isCurrent: () => true),
        throwsA(isA<ValidationException>()),
      );
      expect(calls, hasLength(2));
      expect(await staging.list().toList(), isEmpty);
      expect(await source.readAsBytes(), _wav());
    },
  );

  test('cancel and stale picker return create no staging files', () async {
    expect(
      await importer(pick: () async => null).pick(isCurrent: () => true),
      isNull,
    );
    var current = true;
    final picker = Completer<File?>();
    final pending = importer(
      pick: () => picker.future,
    ).pick(isCurrent: () => current);
    current = false;
    picker.complete(source);
    expect(await pending, isNull);
    expect(await staging.list().toList(), isEmpty);
    expect(await source.exists(), isTrue);
  });

  test(
    'serializes native picker across importer owners until copy is finished',
    () async {
      final picker = Completer<File?>();
      final first = importer(
        pick: () => picker.future,
      ).pick(isCurrent: () => true);
      await expectLater(
        importer().pick(isCurrent: () => true),
        throwsA(isA<ValidationException>()),
      );
      picker.complete(null);
      expect(await first, isNull);
      final selected = (await importer().pick(isCurrent: () => true))!;
      await selected.discard();
    },
  );

  for (final extension in ['mp3', 'm4a']) {
    test('rejects $extension rather than renaming or transcoding it', () async {
      final file = await File(
        '${directory.path}/meeting.$extension',
      ).writeAsBytes(_wav());
      await expectLater(
        importer(pick: () async => file).pick(isCurrent: () => true),
        throwsA(isA<ValidationException>()),
      );
      expect(await file.exists(), isTrue);
      expect(await staging.list().toList(), isEmpty);
    });
  }

  test(
    'rejects fake WAV bytes and oversize input before allocating staging',
    () async {
      await source.writeAsString('not wav');
      await expectLater(
        importer().pick(isCurrent: () => true),
        throwsA(isA<ValidationException>()),
      );
      final handle = await source.open(mode: FileMode.write);
      await handle.truncate(WavValidator.maxFileBytes + 1);
      await handle.close();
      await expectLater(
        importer().pick(isCurrent: () => true),
        throwsA(isA<ValidationException>()),
      );
      expect(await staging.list().toList(), isEmpty);
    },
  );

  test('provider and destination errors expose no private path', () async {
    await expectLater(
      importer(
        pick: () async => throw PlatformException(
          code: 'provider',
          message: '/private/secret/meeting.wav',
        ),
      ).pick(isCurrent: () => true),
      throwsA(
        isA<ValidationException>().having(
          (error) => error.message,
          'safe message',
          isNot(contains('/private/secret')),
        ),
      ),
    );
    final blocked = await File(
      '${directory.path}/not-a-directory',
    ).writeAsString('x');
    final failing = IosWavImporter(
      pickFile: () async => source,
      temporaryDirectory: () async => Directory(blocked.path),
    );
    await expectLater(
      failing.pick(isCurrent: () => true),
      throwsA(isA<ValidationException>()),
    );
    expect(await source.readAsBytes(), _wav());
  });

  test(
    'cancellation during bounded streaming cleans partial owned copy',
    () async {
      await source.writeAsBytes(_wav(samples: 100000));
      var checks = 0;
      final result = await importer().pick(isCurrent: () => ++checks < 8);
      expect(result, isNull);
      expect(await staging.list().toList(), isEmpty);
      expect(await source.exists(), isTrue);
    },
  );

  test(
    'mid-copy provider read failure closes and removes the partial copy',
    () async {
      await source.writeAsBytes(_wav(samples: 100000));
      await expectLater(
        importer().importFile(_ReadFailureFile(source), isCurrent: () => true),
        throwsA(
          isA<ValidationException>().having(
            (error) => error.message,
            'safe message',
            isNot(contains('/private/provider')),
          ),
        ),
      );
      expect(await staging.list().toList(), isEmpty);
      expect(await source.exists(), isTrue);
    },
  );

  test(
    'native picker channel asks only for one WAV without loading full bytes',
    () async {
      FilePickerIO.registerWith();
      final channel = MethodChannel(
        'miguelruivo.flutter.plugins.filepicker',
        Platform.isMacOS || Platform.isLinux || Platform.isWindows
            ? const JSONMethodCodec()
            : const StandardMethodCodec(),
      );
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            return [
              {'path': source.path, 'name': 'meeting.wav', 'size': 48},
            ];
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );
      final selected = (await IosWavImporter(
        temporaryDirectory: () async => staging,
      ).pick(isCurrent: () => true))!;
      expect(calls.single.method, 'custom');
      expect(calls.single.arguments['allowedExtensions'], ['wav']);
      expect(calls.single.arguments['allowMultipleSelection'], isFalse);
      expect(calls.single.arguments['withData'], isFalse);
      expect(await selected.file.readAsBytes(), _wav());
      await selected.discard();
    },
  );

  Future<(_Record, ProviderContainer)> mount(
    WidgetTester tester, {
    double width = 375,
    double height = 812,
    double textScale = 1,
    double keyboard = 0,
    IosWavImporter? selectedImporter,
  }) async {
    await tester.binding.setSurfaceSize(Size(width, height));
    final record = _Record();
    final container = ProviderContainer(
      overrides: [
        appConfigProvider.overrideWithValue(
          AppConfig.parse(apiBaseUrl: 'https://fixture.invalid'),
        ),
        recordNotifierProvider.overrideWith((_) => record),
      ],
    );
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      container.dispose();
      await tester.binding.setSurfaceSize(null);
    });
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.dark.copyWith(platform: TargetPlatform.iOS),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(textScale),
              viewInsets: EdgeInsets.only(bottom: keyboard),
              padding: const EdgeInsets.only(top: 47, bottom: 34),
            ),
            child: child!,
          ),
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (_) =>
                        UploadModal(importer: selectedImporter ?? importer()),
                  ),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    return (record, container);
  }

  Future<void> choose(WidgetTester tester) async {
    await tester.runAsync(() async {
      await tester.tap(find.text('Choose File'));
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();
  }

  Future<void> waitForIo(
    WidgetTester tester,
    Future<bool> Function() ready,
  ) async {
    for (var i = 0; i < 30; i++) {
      await tester.pump();
      if (await tester.runAsync(ready) == true) return;
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
    }
    fail('File operation did not settle');
  }

  for (final width in [320.0, 375.0, 430.0]) {
    testWidgets('Files dialog fits width $width, text2 and keyboard', (
      tester,
    ) async {
      final (record, _) = await mount(
        tester,
        width: width,
        textScale: 2,
        keyboard: 280,
      );
      expect(find.text('Выберите WAV из Files'), findsOneWidget);
      expect(find.text('Перетащите файл WAV'), findsNothing);
      expect(
        tester.getRect(find.byType(Dialog)).width,
        lessThanOrEqualTo(width),
      );
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -1200),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.byType(UploadModal), findsNothing);
      expect(record.files, isEmpty);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('landscape controls scroll without overflow', (tester) async {
    await mount(tester, width: 812, height: 375, textScale: 2);
    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -1000),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'selected file is owned until upload settles; double tap sends once',
    (tester) async {
      final (record, _) = await mount(tester);
      await choose(tester);
      expect(find.text('meeting.wav'), findsOneWidget);
      await tester.ensureVisible(find.text('Upload'));
      await tester.tap(find.text('Upload'));
      await tester.tap(find.text('Upload'), warnIfMissed: false);
      await tester.pumpAndSettle();
      await record.entered.future;
      expect(record.files, hasLength(1));
      expect(await tester.runAsync(record.files.single.exists), isTrue);
      expect(find.byType(UploadModal), findsNothing);
      record.complete.complete();
      await waitForIo(tester, () async => !await record.files.single.exists());
      expect(await tester.runAsync(record.files.single.exists), isFalse);
      expect(await tester.runAsync(source.exists), isTrue);
    },
  );

  testWidgets('session invalidation rejects late picker and never uploads', (
    tester,
  ) async {
    final pending = Completer<File?>();
    final (record, container) = await mount(
      tester,
      selectedImporter: importer(pick: () => pending.future),
    );
    await tester.tap(find.text('Choose File'));
    await tester.pump();
    container.read(sessionNotifierProvider).invalidate();
    await tester.pump();
    pending.complete(source);
    await tester.pumpAndSettle();
    expect(
      find.text('Сессия изменилась. Откройте окно отправки заново.'),
      findsOneWidget,
    );
    expect(record.files, isEmpty);
    expect(await tester.runAsync(() => staging.list().toList()), isEmpty);
    expect(await tester.runAsync(source.exists), isTrue);
  });

  testWidgets(
    'removing selection and dismissing modal clean only owned copies',
    (tester) async {
      await mount(tester);
      await choose(tester);
      expect(
        await tester.runAsync(() => staging.list().toList()),
        hasLength(1),
      );
      await tester.tap(find.byTooltip('Remove selected file'));
      await waitForIo(tester, () async => await staging.list().isEmpty);
      await tester.pumpAndSettle();
      expect(await tester.runAsync(() => staging.list().toList()), isEmpty);
      await choose(tester);
      await tester.tap(find.byTooltip('Close upload'));
      await tester.pumpAndSettle();
      await waitForIo(tester, () async => await staging.list().isEmpty);
      expect(await tester.runAsync(() => staging.list().toList()), isEmpty);
      expect(await tester.runAsync(source.exists), isTrue);
    },
  );
}
