import 'dart:convert';
import 'dart:io';

import 'package:dict_ai/core/theme/app_theme.dart';
import 'package:dict_ai/features/results/data/dto/canonical_transcript_dto.dart';
import 'package:dict_ai/features/results/presentation/transcript_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _fixture({bool noSpeech = false}) =>
    (jsonDecode(File('test/fixtures/canonical_v1.json').readAsStringSync())
            as Map)[noSpeech ? 'no_speech' : 'speech']
        as Map<String, dynamic>;

Map<String, dynamic> _segment(
  String text, {
  int start = 0,
  int end = 1000000,
}) => {
  'start_us': start,
  'end_us': end,
  'speaker_id': 'UNKNOWN',
  'text': text,
  'confidence': null,
  'language': null,
  'word_timing': 'unavailable',
  'words': <Object>[],
};
Map<String, dynamic> _single(String text, {int start = 0, int end = 1000000}) =>
    _fixture()
      ..['duration_us'] = end
      ..['speakers'] = <Object>[]
      ..['segments'] = [_segment(text, start: start, end: end)];

Widget _app(
  CanonicalTranscriptDto transcript, {
  ScrollController? controller,
  double scale = 1,
}) => MaterialApp(
  theme: AppTheme.dark.copyWith(platform: TargetPlatform.iOS),
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
    child: child!,
  ),
  home: Scaffold(
    body: CustomScrollView(
      controller: controller,
      slivers: [TranscriptView(transcript: transcript)],
    ),
  ),
);

void main() {
  Future<void> mount(
    WidgetTester tester,
    CanonicalTranscriptDto transcript, {
    ScrollController? controller,
    double scale = 1,
    Size size = const Size(375, 812),
  }) async {
    await tester.binding.setSurfaceSize(size);
    await tester.pumpWidget(
      _app(transcript, controller: controller, scale: scale),
    );
    await tester.pumpAndSettle();
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.binding.setSurfaceSize(null);
    });
  }

  testWidgets(
    'backend labels/IDs, UNKNOWN and overlapping source order are retained',
    (tester) async {
      final json = _fixture();
      json['duration_us'] = 10000000;
      (json['segments'] as List)[0]['end_us'] = 10000000;
      (json['segments'] as List)[1]['end_us'] = 2000000;
      final transcript = CanonicalTranscriptDto.fromJson(json);
      final semantics = tester.ensureSemantics();
      await mount(tester, transcript, size: const Size(800, 1200));
      expect(find.text('Speaker 1'), findsOneWidget);
      expect(find.text('speaker_1'), findsOneWidget);
      expect(find.text('Speaker 2'), findsOneWidget);
      expect(find.text('speaker_2'), findsOneWidget);
      expect(find.text('UNKNOWN'), findsOneWidget);
      expect(find.text('Перекрытие реплик'), findsNWidgets(2));
      expect(find.text('00:00:00.000000 — 00:00:10.000000'), findsOneWidget);
      expect(find.text('00:00:01.000000 — 00:00:02.000000'), findsOneWidget);
      expect(find.text('00:00:03.000000 — 00:00:04.000000'), findsOneWidget);
      expect(
        tester
            .widgetList<SelectableText>(find.byType(SelectableText))
            .map((w) => w.data),
        ['Первая реплика.', 'Hello!', 'Неизвестный голос.'],
      );
      expect(
        find.bySemanticsLabel(
          RegExp(r'Speaker 1 \(speaker_1\).*00:00:10', dotAll: true),
        ),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(
          RegExp(r'UNKNOWN.*Перекрытие реплик', dotAll: true),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      semantics.dispose();
    },
  );

  testWidgets(
    'microsecond offsets remain exact at the maximum schema integer',
    (tester) async {
      final transcript = CanonicalTranscriptDto.fromJson(
        _single(
          'Точное время.',
          start: 9007199253506424,
          end: 9007199254740991,
        ),
      );
      await mount(tester, transcript, size: const Size(320, 568), scale: 2);
      expect(
        find.text('2501999:47:33.506424 — 2501999:47:34.740991'),
        findsOneWidget,
      );
      expect(find.text('Точное время.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'no_speech is successful empty content with no fabricated speaker/time',
    (tester) async {
      await mount(
        tester,
        CanonicalTranscriptDto.fromJson(_fixture(noSpeech: true)),
      );
      expect(find.text('Речь не обнаружена.'), findsOneWidget);
      expect(find.byType(SelectableText), findsNothing);
      expect(find.text('UNKNOWN'), findsNothing);
      expect(find.textContaining('00:00:'), findsNothing);
    },
  );

  test(
    'missing/invalid timing is rejected before rendering rather than filled with zero',
    () {
      for (final mutate in <void Function(Map<String, dynamic>)>[
        (segment) => segment.remove('start_us'),
        (segment) => segment['start_us'] = null,
        (segment) => segment['start_us'] = -1,
        (segment) => segment['end_us'] = 0,
        (segment) => segment['end_us'] = 1.5,
      ]) {
        final json = _single('Некорректное время.');
        mutate((json['segments'] as List).single as Map<String, dynamic>);
        expect(
          () => CanonicalTranscriptDto.fromJson(json),
          throwsFormatException,
        );
      }
    },
  );

  testWidgets(
    'ten thousand segments build visible rows lazily and scroll to the end',
    (tester) async {
      final json = _fixture()
        ..['duration_us'] = 10000000000
        ..['speakers'] = <Object>[]
        ..['segments'] = List.generate(
          10000,
          (i) => _segment(
            'Реплика $i.',
            start: i * 1000000,
            end: (i + 1) * 1000000,
          ),
        );
      final transcript = CanonicalTranscriptDto.fromJson(json);
      final controller = ScrollController();
      addTearDown(controller.dispose);
      await mount(tester, transcript, controller: controller);
      expect(find.text('Реплика 0.'), findsOneWidget);
      expect(find.text('Реплика 9999.'), findsNothing);
      expect(find.byType(SelectableText).evaluate().length, lessThan(20));
      controller.jumpTo(controller.position.maxScrollExtent);
      await tester.pumpAndSettle();
      controller.jumpTo(controller.position.maxScrollExtent);
      await tester.pumpAndSettle();
      expect(find.text('Реплика 9999.'), findsOneWidget);
      expect(find.byType(SelectableText).evaluate().length, lessThan(20));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'UTF-16 continuation boundaries preserve complete code points and original text',
    (tester) async {
      final text = '${'a' * (TranscriptView.textChunkLength - 1)}😀b';
      await mount(
        tester,
        CanonicalTranscriptDto.fromJson(_single(text)),
        size: const Size(1500, 1600),
      );
      final parts = tester
          .widgetList<SelectableText>(find.byType(SelectableText))
          .map((w) => w.data!)
          .toList();
      expect(parts, hasLength(2));
      expect(parts.join(), text);
      expect(parts.first, 'a' * (TranscriptView.textChunkLength - 1));
      expect(parts.last, '😀b');
      expect(
        parts.every((part) => utf8.decode(utf8.encode(part)) == part),
        isTrue,
      );
      expect(find.text('Продолжение реплики'), findsOneWidget);
      expect(find.text('00:00:00.000000 — 00:00:01.000000'), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'exact 50 MiB canonical single segment has bounded visible text layout',
    (tester) async {
      const artifactLimit = 50 * 1024 * 1024;
      final json = _single('');
      final overhead = utf8.encode(jsonEncode(json)).length;
      (json['segments'] as List).single['text'] =
          'a' * (artifactLimit - overhead);
      final artifact = jsonEncode(json);
      expect(utf8.encode(artifact).length, artifactLimit);
      final transcript = CanonicalTranscriptDto.fromJson(
        jsonDecode(artifact) as Map<String, dynamic>,
      );
      expect(transcript.segments, hasLength(1));
      await mount(tester, transcript, size: const Size(320, 568), scale: 2);
      final visible = tester
          .widgetList<SelectableText>(find.byType(SelectableText))
          .toList();
      expect(visible, isNotEmpty);
      expect(visible.length, lessThan(10));
      expect(
        visible.every(
          (w) => w.data!.length <= TranscriptView.textChunkLength + 1,
        ),
        isTrue,
      );
      expect(
        visible.fold<int>(0, (count, w) => count + w.data!.length),
        lessThan(40960),
      );
      expect(tester.takeException(), isNull);
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  for (final size in [const Size(320, 568), const Size(430, 320)]) {
    testWidgets(
      'speaker/time metadata and selection fit $size at text scale 2',
      (tester) async {
        await mount(
          tester,
          CanonicalTranscriptDto.fromJson(_fixture()),
          size: size,
          scale: 2,
        );
        await tester.scrollUntilVisible(
          find.text('Неизвестный голос.'),
          100,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.text('Неизвестный голос.'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'selection copies original segment text without speaker/time decoration',
    (tester) async {
      await mount(tester, CanonicalTranscriptDto.fromJson(_fixture()));
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      final editable = tester.state<EditableTextState>(
        find.byType(EditableText).first,
      );
      final text = editable.widget.controller.text;
      editable.widget.controller.selection = TextSelection(
        baseOffset: 0,
        extentOffset: text.length,
      );
      editable.copySelection(SelectionChangedCause.toolbar);
      await tester.pump();
      expect(copied, 'Первая реплика.');
      expect(editable.widget.readOnly, isTrue);
    },
  );

  testWidgets(
    'new transcript replaces cached labels/row index and clears previous content',
    (tester) async {
      await mount(tester, CanonicalTranscriptDto.fromJson(_fixture()));
      expect(find.text('Первая реплика.'), findsOneWidget);
      await tester.pumpWidget(
        _app(CanonicalTranscriptDto.fromJson(_single('Другой результат.'))),
      );
      await tester.pumpAndSettle();
      expect(find.text('Другой результат.'), findsOneWidget);
      expect(find.text('Первая реплика.'), findsNothing);
      expect(find.text('Speaker 1'), findsNothing);
      expect(find.text('UNKNOWN'), findsOneWidget);
    },
  );
}
