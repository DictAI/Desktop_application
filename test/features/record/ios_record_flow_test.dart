import 'package:dict_ai/core/theme/app_theme.dart';
import 'package:dict_ai/features/record/presentation/finish_recording_dialog.dart';
import 'package:dict_ai/features/record/presentation/record_notifier.dart';
import 'package:dict_ai/features/record/presentation/record_screen.dart';
import 'package:dict_ai/shared/providers/providers.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fakes.dart';

class _Record extends RecordNotifier {
  _Record()
    : super(
        captureFactory: (_) =>
            throw StateError('No native capture in UI tests'),
        session: () async => throw StateError('No uploads in layout tests'),
      );

  var refreshes = 0;

  void snapshot(RecordStatus status, {String? error}) =>
      state = RecordState(status: status, anonymous: true, errorMessage: error);

  @override
  bool get supportsPause => true;

  @override
  Future<void> refreshDevices() async {
    refreshes++;
  }

  @override
  Future<void> togglePause() async => snapshot(
    state.status == RecordStatus.paused
        ? RecordStatus.recording
        : RecordStatus.paused,
  );
}

void main() {
  setUp(resetStorageFakes);

  Future<_Record> mount(
    WidgetTester tester, {
    Size size = const Size(375, 812),
    double textScale = 1,
    TargetPlatform platform = TargetPlatform.iOS,
  }) async {
    await tester.binding.setSurfaceSize(size);
    final record = _Record();
    final adapter = ScriptedAdapter()
      ..enqueue(200, {
        'data': [],
        'pagination': {'page': 1, 'limit': 20, 'total': 0, 'total_pages': 0},
      });
    final dio = Dio(BaseOptions(baseUrl: 'https://fixture.invalid'))
      ..httpClientAdapter = adapter;
    final container = ProviderContainer(
      overrides: [
        dioProvider.overrideWithValue(dio),
        recordNotifierProvider.overrideWith((_) => record),
      ],
    );
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      container.dispose();
      dio.close(force: true);
      await tester.binding.setSurfaceSize(null);
    });
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.dark.copyWith(platform: platform),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(textScale),
              padding: const EdgeInsets.only(top: 47, bottom: 34),
              viewPadding: const EdgeInsets.only(top: 47, bottom: 34),
            ),
            child: child!,
          ),
          home: const Scaffold(body: SafeArea(child: RecordScreen())),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return record;
  }

  for (final width in [320.0, 375.0, 430.0]) {
    for (final textScale in [1.0, 2.0]) {
      testWidgets('iOS Record fits width $width at text scale $textScale', (
        tester,
      ) async {
        final record = await mount(
          tester,
          size: Size(width, 812),
          textScale: textScale,
        );
        expect(record.refreshes, 0);
        expect(find.text('INPUT DEVICE'), findsNothing);
        expect(find.text('Also capture system audio'), findsNothing);
        expect(
          find.text('BlackHole detected — system audio will be captured'),
          findsNothing,
        );
        expect(find.text('Без рабочего пространства'), findsOneWidget);
        await tester.tap(find.byType(SwitchListTile));
        await tester.pumpAndSettle();
        expect(record.state.anonymous, isTrue);
        await tester.ensureVisible(find.text('Upload Audio'));
        await tester.pumpAndSettle();
        expect(find.text('Смешанная речь'), findsOneWidget);
        expect(
          tester
              .getSize(find.widgetWithText(OutlinedButton, 'Upload Audio'))
              .height,
          greaterThanOrEqualTo(48),
        );
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('landscape keeps file import reachable with large text', (
    tester,
  ) async {
    final record = await mount(
      tester,
      size: const Size(812, 375),
      textScale: 2,
    );
    record.setAnonymous(true);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Upload Audio'));
    await tester.pumpAndSettle();
    final rect = tester.getRect(find.text('Upload Audio'));
    expect(rect.bottom, lessThanOrEqualTo(375 - 34));
    expect(tester.takeException(), isNull);
  });

  testWidgets('record action has an accessible name and large tap target', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    final record = await mount(tester);
    record.setAnonymous(true);
    await tester.pumpAndSettle();
    final action = find.bySemanticsLabel('Начать запись');
    expect(action, findsOneWidget);
    expect(
      tester
          .getSemantics(action)
          .getSemanticsData()
          .hasAction(SemanticsAction.tap),
      isTrue,
    );
    expect(tester.getSize(action).shortestSide, greaterThanOrEqualTo(48));
    handle.dispose();
  });

  testWidgets(
    'elapsed active time pauses for interrupted capture and resumes',
    (tester) async {
      final record = await mount(tester);
      record.snapshot(RecordStatus.starting);
      await tester.pump();
      record.snapshot(RecordStatus.recording);
      await tester.pump();
      expect(find.byKey(const Key('record-elapsed')), findsOneWidget);
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 1100)),
      );
      await tester.pump(const Duration(seconds: 1));
      final elapsed = tester
          .widget<Text>(find.byKey(const Key('record-elapsed')))
          .data;
      expect(elapsed, isNot('00:00'));
      record.snapshot(
        RecordStatus.paused,
        error: 'Запись прервана. Продолжите вручную.',
      );
      await tester.pump();
      expect(find.text('Paused'), findsOneWidget);
      expect(find.text('Resume'), findsOneWidget);
      final pausedElapsed = tester
          .widget<Text>(find.byKey(const Key('record-elapsed')))
          .data;
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 1100)),
      );
      await tester.pump(const Duration(seconds: 2));
      expect(
        tester.widget<Text>(find.byKey(const Key('record-elapsed'))).data,
        pausedElapsed,
      );
      await tester.tap(find.text('Resume'));
      await tester.pump();
      expect(record.state.status, RecordStatus.recording);
      record.snapshot(RecordStatus.error, error: 'Микрофон недоступен');
      await tester.pump();
      expect(find.byKey(const Key('record-elapsed')), findsNothing);
      await tester.ensureVisible(find.text('Микрофон недоступен'));
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('desktop preserves device and system capture controls', (
    tester,
  ) async {
    final record = await mount(
      tester,
      size: const Size(1280, 1000),
      platform: TargetPlatform.macOS,
    );
    expect(record.refreshes, 1);
    expect(find.text('INPUT DEVICE'), findsOneWidget);
    expect(find.text('Also capture system audio'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'finish confirmation actions fit narrow landscape and large text',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 375));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark.copyWith(platform: TargetPlatform.iOS),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showDialog<bool>(
                  context: context,
                  builder: (_) => const FinishRecordingDialog(),
                ),
                child: const Text('Stop'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Stop'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Продолжить запись'));
      await tester.tap(find.text('Продолжить запись'));
      await tester.pumpAndSettle();
      expect(find.byType(FinishRecordingDialog), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
