import 'dart:io';
import 'dart:typed_data';

import 'package:dict_ai/core/theme/app_theme.dart';
import 'package:dict_ai/features/record/presentation/record_notifier.dart';
import 'package:dict_ai/features/record/presentation/record_screen.dart';
import 'package:dict_ai/features/workspace/presentation/workspace_detail_screen.dart';
import 'package:dict_ai/features/workspace/presentation/workspace_notifier.dart';
import 'package:dict_ai/shared/providers/providers.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fakes.dart';

const _workspaceId = '11111111-1111-4111-8111-111111111111';
const _ownerId = '22222222-2222-4222-8222-222222222222';
const _contactId = '33333333-3333-4333-8333-333333333333';
const _workspacePath = '/workspaces/$_workspaceId';
const _contactsPath = '$_workspacePath/participants';
const _name = 'Empty workspace';

Map<String, Object> _workspace({bool details = true}) => {
  'workspace_id': _workspaceId,
  details ? 'owner_id' : 'owner_user_id': _ownerId,
  'name': _name,
  'created_at': '2026-10-24T09:00:00Z',
};

Map<String, Object> _contact(String name, String email) => {
  'participant_id': _contactId,
  'workspace_id': _workspaceId,
  'name': name,
  'email': email,
};

class _WorkspaceAdapter extends ScriptedAdapter {
  final retiredRequests = <String>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    if (options.uri.pathSegments.contains('voice-profiles')) {
      retiredRequests.add(options.uri.path);
      throw StateError('Retired voice endpoint called');
    }
    return super.fetch(options, requestStream, cancelFuture);
  }
}

ProviderContainer _container(WidgetTester tester, _WorkspaceAdapter adapter) {
  final dio = Dio(BaseOptions(baseUrl: 'https://fixture.invalid'))
    ..httpClientAdapter = adapter;
  final container = ProviderContainer(
    overrides: [dioProvider.overrideWithValue(dio)],
  );
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    container.dispose();
    dio.close(force: true);
    await tester.pump();
    await tester.binding.setSurfaceSize(null);
    expect(adapter.retiredRequests, isEmpty);
  });
  return container;
}

Future<void> _mount(
  WidgetTester tester,
  ProviderContainer container,
  Widget screen,
) async {
  await tester.binding.setSurfaceSize(const Size(1280, 900));
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        key: ValueKey(screen.runtimeType),
        theme: AppTheme.dark.copyWith(
          platform: TargetPlatform.macOS,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
        ),
        home: Scaffold(body: screen),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('workspace detail keeps name/email contact operations', (
    tester,
  ) async {
    final adapter = _WorkspaceAdapter()
      ..enqueue(200, _workspace())
      ..enqueue(200, [])
      ..enqueue(200, _contact('Test Contact', 'contact@example.invalid'))
      ..enqueue(200, _contact('Changed Contact', 'changed@example.invalid'))
      ..enqueue(200, {'message': 'participant removed successfully'});
    final container = _container(tester, adapter);
    await _mount(
      tester,
      container,
      const WorkspaceDetailScreen(workspaceId: _workspaceId),
    );
    expect(find.text(_name), findsOneWidget);
    expect(find.text('No participants yet'), findsOneWidget);

    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();
    expect(find.byType(TextFormField), findsNWidgets(2));
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Full name'),
      'Test Contact',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Email address'),
      'contact@example.invalid',
    );
    await tester.tap(find.widgetWithText(ElevatedButton, 'Add'));
    await tester.pumpAndSettle();
    expect(find.text('Test Contact'), findsOneWidget);
    expect(find.text('contact@example.invalid'), findsOneWidget);
    expect(find.byTooltip('Add voice profile'), findsNothing);

    final notifier = container.read(
      workspaceDetailProvider(_workspaceId).notifier,
    );
    final update = notifier.updateParticipant(
      participantId: _contactId,
      name: 'Changed Contact',
      email: 'changed@example.invalid',
    );
    await tester.pumpAndSettle();
    expect(await update, isTrue);
    expect(find.text('Changed Contact'), findsOneWidget);
    expect(find.text('changed@example.invalid'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.person_remove_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Remove'));
    await tester.pumpAndSettle();
    expect(find.text('No participants yet'), findsOneWidget);
    expect(
      adapter.requests.map((request) => '${request.method} ${request.path}'),
      [
        'GET $_workspacePath',
        'GET $_contactsPath',
        'POST $_contactsPath',
        'PUT $_contactsPath/$_contactId',
        'DELETE $_contactsPath/$_contactId',
      ],
    );
    expect(adapter.requests[2].data, {
      'name': 'Test Contact',
      'email': 'contact@example.invalid',
    });
    expect(adapter.requests[3].data, {
      'name': 'Changed Contact',
      'email': 'changed@example.invalid',
    });
  });

  testWidgets('contact load error can retry and clear the old message', (
    tester,
  ) async {
    final adapter = _WorkspaceAdapter()
      ..enqueue(200, _workspace())
      ..enqueue(503, {'error': 'unavailable'})
      ..enqueue(200, _workspace())
      ..enqueue(200, []);
    final container = _container(tester, adapter);
    await _mount(
      tester,
      container,
      const WorkspaceDetailScreen(workspaceId: _workspaceId),
    );
    expect(find.text('Сервис временно недоступен.'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('No participants yet'), findsOneWidget);
    expect(find.text('Сервис временно недоступен.'), findsNothing);
    expect(adapter.requests.map((r) => r.path), [
      _workspacePath,
      _contactsPath,
      _workspacePath,
      _contactsPath,
    ]);
  });

  testWidgets(
    'empty workspace reaches microphone permission and accepts a WAV selection',
    (tester) async {
      const recorder = MethodChannel('com.llfbandit.record/messages');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      final eventChannels = <MethodChannel>[];
      var permissionChecks = 0;
      messenger.setMockMethodCallHandler(recorder, (call) async {
        switch (call.method) {
          case 'create':
            final id = call.arguments['recorderId'] as String;
            final channel = MethodChannel('com.llfbandit.record/events/$id');
            eventChannels.add(channel);
            messenger.setMockMethodCallHandler(channel, (_) async => null);
            return null;
          case 'hasPermission':
            permissionChecks++;
            return false;
          case 'dispose':
            return null;
          default:
            fail('Unexpected recorder call: ${call.method}');
        }
      });
      addTearDown(() {
        messenger.setMockMethodCallHandler(recorder, null);
        for (final channel in eventChannels) {
          messenger.setMockMethodCallHandler(channel, null);
        }
      });
      final adapter = _WorkspaceAdapter()
        ..enqueue(200, _workspace())
        ..enqueue(200, null)
        ..enqueue(200, {
          'data': [_workspace(details: false)],
          'pagination': {'page': 1, 'limit': 20, 'total': 1, 'total_pages': 1},
        });
      final container = _container(tester, adapter);
      await _mount(
        tester,
        container,
        const WorkspaceDetailScreen(workspaceId: _workspaceId),
      );
      expect(find.text('No participants yet'), findsOneWidget);
      await _mount(tester, container, const RecordScreen());
      await tester.tap(find.text('Not selected'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(_name));
      await tester.pumpAndSettle();
      expect(
        container.read(recordNotifierProvider).selectedWorkspaceId,
        _workspaceId,
      );

      final beforeStart = permissionChecks;
      await tester.tap(find.byIcon(Icons.mic_rounded));
      await tester.pumpAndSettle();
      expect(permissionChecks, beforeStart + 1);
      expect(
        find.textContaining('Microphone permission denied.'),
        findsOneWidget,
      );

      final directory = Directory.systemTemp.createTempSync(
        'dictai-profile-free-',
      );
      addTearDown(() => directory.deleteSync(recursive: true));
      final file = File('${directory.path}/fixture.wav')
        ..writeAsBytesSync(_smallWav());
      final upload = find.text('Upload Audio');
      await tester.ensureVisible(upload);
      await tester.tap(upload);
      await tester.pumpAndSettle();
      expect(find.text('Choose File'), findsOneWidget);
      final target = tester.widget<DragTarget<List<String>>>(
        find.byType(DragTarget<List<String>>),
      );
      target.onAcceptWithDetails!(
        DragTargetDetails(data: [file.path], offset: Offset.zero),
      );
      await tester.pumpAndSettle();
      expect(find.text('fixture.wav'), findsOneWidget);
      expect(adapter.requests.map((r) => r.path), [
        _workspacePath,
        _contactsPath,
        '/workspaces/',
      ]);
      expect(tester.takeException(), isNull);
    },
  );
}

Uint8List _smallWav() {
  final bytes = Uint8List(46);
  bytes.setRange(0, 4, 'RIFF'.codeUnits);
  bytes.setRange(8, 16, 'WAVEfmt '.codeUnits);
  bytes.setRange(36, 40, 'data'.codeUnits);
  ByteData.sublistView(bytes)
    ..setUint32(4, 38, Endian.little)
    ..setUint32(16, 16, Endian.little)
    ..setUint16(20, 1, Endian.little)
    ..setUint16(22, 1, Endian.little)
    ..setUint32(24, 8000, Endian.little)
    ..setUint32(28, 16000, Endian.little)
    ..setUint16(32, 2, Endian.little)
    ..setUint16(34, 16, Endian.little)
    ..setUint32(40, 2, Endian.little);
  return bytes;
}
