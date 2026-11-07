import 'package:dict_ai/core/theme/app_theme.dart';
import 'package:dict_ai/features/workspace/presentation/workspace_detail_screen.dart';
import 'package:dict_ai/features/workspace/presentation/workspace_notifier.dart';
import 'package:dict_ai/shared/providers/providers.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fakes.dart';

const _workspaceId = '11111111-1111-4111-8111-111111111111';
const _contactId = '33333333-3333-4333-8333-333333333333';
const _path = '/workspaces/$_workspaceId/participants';
Map<String, Object> _workspace() => {
  'workspace_id': _workspaceId,
  'owner_id': '22222222-2222-4222-8222-222222222222',
  'name': 'Workspace',
  'created_at': '2026-10-24T09:00:00Z',
};
Map<String, Object> _contact({
  String id = _contactId,
  String name = 'Contact',
  String email = 'contact@example.invalid',
}) => {
  'participant_id': id,
  'workspace_id': _workspaceId,
  'name': name,
  'email': email,
};

Future<ProviderContainer> _mount(
  WidgetTester tester,
  ScriptedAdapter adapter, {
  bool loseDeleteResponse = false,
}) async {
  final dio = Dio(BaseOptions(baseUrl: 'https://fixture.invalid'))
    ..httpClientAdapter = adapter;
  var lose = loseDeleteResponse;
  dio.interceptors.add(
    InterceptorsWrapper(
      onResponse: (response, handler) {
        if (lose && response.requestOptions.method == 'DELETE') {
          lose = false;
          handler.reject(
            DioException(
              requestOptions: response.requestOptions,
              type: DioExceptionType.receiveTimeout,
            ),
          );
        } else {
          handler.next(response);
        }
      },
    ),
  );
  final container = ProviderContainer(
    overrides: [dioProvider.overrideWithValue(dio)],
  );
  await tester.binding.setSurfaceSize(const Size(1280, 900));
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    container.dispose();
    dio.close(force: true);
    await tester.pump();
    await tester.binding.setSurfaceSize(null);
  });
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: AppTheme.dark.copyWith(platform: TargetPlatform.macOS),
        home: const Scaffold(
          body: WorkspaceDetailScreen(workspaceId: _workspaceId),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

Future<void> _openAdd(
  WidgetTester tester, {
  String name = 'Contact',
  String email = 'contact@example.invalid',
}) async {
  await tester.tap(find.text('Add'));
  await tester.pumpAndSettle();
  await tester.enterText(find.widgetWithText(TextFormField, 'Full name'), name);
  await tester.enterText(
    find.widgetWithText(TextFormField, 'Email address'),
    email,
  );
}

Future<void> _action(WidgetTester tester, String text) async {
  await tester.tap(
    find.descendant(
      of: find.byType(AlertDialog),
      matching: find.widgetWithText(ElevatedButton, text),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _check(WidgetTester tester) async {
  await tester.tap(
    find.descendant(
      of: find.byType(AlertDialog),
      matching: find.widgetWithText(TextButton, 'Проверить состояние'),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'null W06 is empty, add and edit use real name/email and immutable server IDs',
    (tester) async {
      final adapter = ScriptedAdapter()
        ..enqueue(200, _workspace())
        ..enqueue(200, null)
        ..enqueue(200, _contact())
        ..enqueue(
          200,
          _contact(name: 'Edited', email: 'edited@example.invalid'),
        );
      final container = await _mount(tester, adapter);
      expect(find.text('No participants yet'), findsOneWidget);
      expect(
        find.textContaining('а не учётные записи или приглашения'),
        findsOneWidget,
      );
      expect(
        find.textContaining('для записи без workspace — только владельца'),
        findsOneWidget,
      );
      expect(
        find.textContaining('не пересылает готовое письмо'),
        findsOneWidget,
      );
      await _openAdd(tester);
      await _action(tester, 'Add');
      expect(find.text('Contact'), findsOneWidget);
      await tester.tap(find.byTooltip('Edit contact'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Full name'),
        ' Edited ',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Email address'),
        'edited@example.invalid',
      );
      await _action(tester, 'Save');
      expect(find.text('Edited'), findsOneWidget);
      expect(find.text('edited@example.invalid'), findsOneWidget);
      expect(
        container
            .read(workspaceDetailProvider(_workspaceId))
            .participants
            .single
            .participantId,
        _contactId,
      );
      expect(adapter.requests.map((r) => '${r.method} ${r.path}'), [
        'GET /workspaces/$_workspaceId',
        'GET $_path',
        'POST $_path',
        'PUT $_path/$_contactId',
      ]);
      expect(adapter.requests.last.data, {
        'name': 'Edited',
        'email': 'edited@example.invalid',
      });
      expect(
        adapter.requests.any(
          (r) => r.path.contains('speaker') || r.path.contains('voice-profile'),
        ),
        isFalse,
      );
    },
  );

  testWidgets(
    'contact form validates name/email and accepts an address supported by backend without forced domain dot',
    (tester) async {
      final adapter = ScriptedAdapter()
        ..enqueue(200, _workspace())
        ..enqueue(200, [])
        ..enqueue(200, _contact(name: 'A', email: 'a@b'));
      await _mount(tester, adapter);
      await _openAdd(tester, name: ' ', email: 'bad-email');
      await _action(tester, 'Add');
      expect(find.text('Name required'), findsOneWidget);
      expect(find.text('Invalid email'), findsOneWidget);
      expect(adapter.requests, hasLength(2));
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Full name'),
        'A',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Email address'),
        'a@b',
      );
      await _action(tester, 'Add');
      expect(find.text('A'), findsOneWidget);
    },
  );

  testWidgets(
    'server 409 keeps inputs and list unchanged, user can correct email and retry',
    (tester) async {
      final adapter = ScriptedAdapter()
        ..enqueue(200, _workspace())
        ..enqueue(200, [])
        ..enqueue(409, {'error': 'email already exists in this workspace'})
        ..enqueue(200, _contact(email: 'other@example.invalid'));
      final container = await _mount(tester, adapter);
      await _openAdd(tester);
      await _action(tester, 'Add');
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(
        find.text('Контакт с таким email уже есть в рабочем пространстве.'),
        findsNWidgets(2),
      );
      expect(
        container.read(workspaceDetailProvider(_workspaceId)).participants,
        isEmpty,
      );
      expect(adapter.requests.where((r) => r.method == 'POST'), hasLength(1));
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Email address'),
        'other@example.invalid',
      );
      await _action(tester, 'Add');
      expect(
        container.read(workspaceDetailProvider(_workspaceId)).participants,
        hasLength(1),
      );
    },
  );

  testWidgets(
    'existing exact email cannot be added twice or allocated a new fake contact ID',
    (tester) async {
      final adapter = ScriptedAdapter()
        ..enqueue(200, _workspace())
        ..enqueue(200, [_contact()]);
      await _mount(tester, adapter);
      await _openAdd(tester);
      await _action(tester, 'Add');
      expect(adapter.requests, hasLength(2));
      expect(
        find.text('Контакт с таким email уже есть в рабочем пространстве.'),
        findsNWidgets(2),
      );
    },
  );

  testWidgets(
    'pending add is single-flight and refresh cannot overwrite accepted contact',
    (tester) async {
      final adapter = ScriptedAdapter()
        ..enqueue(200, _workspace())
        ..enqueue(200, []);
      final pending = adapter.defer();
      final container = await _mount(tester, adapter);
      await _openAdd(tester);
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.widgetWithText(ElevatedButton, 'Add'),
        ),
      );
      for (var i = 0; i < 20 && adapter.requests.length < 3; i++) {
        await tester.pump(const Duration(milliseconds: 10));
      }
      final notifier = container.read(
        workspaceDetailProvider(_workspaceId).notifier,
      );
      expect(
        await notifier.addParticipant(
          name: 'Other',
          email: 'other@example.invalid',
        ),
        isFalse,
      );
      await notifier.load();
      expect(adapter.requests, hasLength(3));
      expect(
        tester
            .widget<TextButton>(find.widgetWithText(TextButton, 'Cancel'))
            .onPressed,
        isNull,
      );
      pending.complete(ScriptedAdapter.reply(200, _contact()));
      await tester.pumpAndSettle();
      expect(
        container.read(workspaceDetailProvider(_workspaceId)).participants,
        hasLength(1),
      );
    },
  );

  testWidgets(
    'lost add response requires W06 check and does not emit a second POST',
    (tester) async {
      final adapter = ScriptedAdapter()
        ..enqueue(200, _workspace())
        ..enqueue(200, [])
        ..enqueue(200, {})
        ..enqueue(200, [_contact()]);
      final container = await _mount(tester, adapter);
      await _openAdd(tester);
      await _action(tester, 'Add');
      expect(
        container
            .read(workspaceDetailProvider(_workspaceId))
            .needsContactReconciliation,
        isTrue,
      );
      expect(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.widgetWithText(ElevatedButton, 'Add'),
        ),
        findsNothing,
      );
      expect(
        tester
            .widget<TextFormField>(
              find.widgetWithText(TextFormField, 'Full name'),
            )
            .enabled,
        isFalse,
      );
      await _check(tester);
      expect(find.byType(AlertDialog), findsNothing);
      expect(
        container.read(workspaceDetailProvider(_workspaceId)).participants,
        hasLength(1),
      );
      expect(adapter.requests.where((r) => r.method == 'POST'), hasLength(1));
    },
  );

  testWidgets(
    'failed reconciliation blocks writes, then explicit retry uses the same frozen inputs',
    (tester) async {
      final adapter = ScriptedAdapter()
        ..enqueue(200, _workspace())
        ..enqueue(200, [])
        ..enqueue(200, {})
        ..enqueue(503, {'error': 'unavailable'})
        ..enqueue(200, [])
        ..enqueue(200, _contact());
      final container = await _mount(tester, adapter);
      await _openAdd(tester);
      await _action(tester, 'Add');
      await _check(tester);
      expect(
        container
            .read(workspaceDetailProvider(_workspaceId))
            .canRetryContactMutation,
        isFalse,
      );
      expect(find.text('Повторить те же изменения'), findsNothing);
      final notifier = container.read(
        workspaceDetailProvider(_workspaceId).notifier,
      );
      expect(
        await notifier.addParticipant(
          name: 'Changed',
          email: 'changed@example.invalid',
        ),
        isFalse,
      );
      expect(adapter.requests.where((r) => r.method == 'POST'), hasLength(1));
      await _check(tester);
      expect(
        container
            .read(workspaceDetailProvider(_workspaceId))
            .canRetryContactMutation,
        isTrue,
      );
      await _action(tester, 'Повторить те же изменения');
      final posts = adapter.requests.where((r) => r.method == 'POST').toList();
      expect(posts, hasLength(2));
      expect(posts[1].data, posts[0].data);
      expect(
        container.read(workspaceDetailProvider(_workspaceId)).participants,
        hasLength(1),
      );
    },
  );

  testWidgets(
    'cancelled uncertain dialog retains visible recovery in workspace instead of silently replaying',
    (tester) async {
      final adapter = ScriptedAdapter()
        ..enqueue(200, _workspace())
        ..enqueue(200, [])
        ..enqueue(200, {})
        ..enqueue(200, [_contact()]);
      final container = await _mount(tester, adapter);
      await _openAdd(tester);
      await _action(tester, 'Add');
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Добавить контакт Contact contact@example.invalid'),
        findsOneWidget,
      );
      expect(
        tester
            .widget<TextButton>(find.widgetWithText(TextButton, 'Add'))
            .onPressed,
        isNull,
      );
      await tester.tap(find.text('Проверить состояние'));
      await tester.pumpAndSettle();
      expect(
        container
            .read(workspaceDetailProvider(_workspaceId))
            .needsContactReconciliation,
        isFalse,
      );
      expect(adapter.requests.where((r) => r.method == 'POST'), hasLength(1));
    },
  );

  testWidgets(
    'lost edit response reconciles desired state without duplicate PUT',
    (tester) async {
      final adapter = ScriptedAdapter()
        ..enqueue(200, _workspace())
        ..enqueue(200, [_contact()])
        ..enqueue(200, {})
        ..enqueue(200, [_contact(name: 'Edited')]);
      final container = await _mount(tester, adapter);
      await tester.tap(find.byTooltip('Edit contact'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Full name'),
        'Edited',
      );
      await _action(tester, 'Save');
      await _check(tester);
      expect(
        container
            .read(workspaceDetailProvider(_workspaceId))
            .participants
            .single
            .name,
        'Edited',
      );
      expect(adapter.requests.where((r) => r.method == 'PUT'), hasLength(1));
    },
  );

  for (final missingTarget in [false, true]) {
    testWidgets(
      'lost edit reconciliation ends when target is ${missingTarget ? 'removed' : 'in conflict'}',
      (tester) async {
        const desiredEmail = 'changed@example.invalid';
        final adapter = ScriptedAdapter()
          ..enqueue(200, _workspace())
          ..enqueue(200, [_contact()])
          ..enqueue(200, {})
          ..enqueue(
            200,
            missingTarget
                ? []
                : [
                    _contact(),
                    _contact(
                      id: '44444444-4444-4444-8444-444444444444',
                      name: 'Other contact',
                      email: desiredEmail,
                    ),
                  ],
          );
        final container = await _mount(tester, adapter);
        await tester.tap(find.byTooltip('Edit contact'));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Email address'),
          desiredEmail,
        );
        await _action(tester, 'Save');
        expect(
          container
              .read(workspaceDetailProvider(_workspaceId))
              .needsContactReconciliation,
          isTrue,
        );
        await _check(tester);
        final state = container.read(workspaceDetailProvider(_workspaceId));
        expect(state.needsContactReconciliation, isFalse);
        expect(state.canRetryContactMutation, isFalse);
        expect(state.participants, hasLength(missingTarget ? 0 : 2));
        expect(find.text('Повторить те же изменения'), findsNothing);
        expect(
          find.textContaining(
            missingTarget ? 'контакт уже удалён' : 'этим email уже существует',
          ),
          findsWidgets,
        );
        if (missingTarget) {
          expect(find.widgetWithText(ElevatedButton, 'Save'), findsNothing);
        }
        await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<TextButton>(find.widgetWithText(TextButton, 'Add'))
              .onPressed,
          isNotNull,
        );
        expect(adapter.requests.where((r) => r.method == 'PUT'), hasLength(1));
      },
    );
  }

  testWidgets(
    'delete confirmation cancel is inert and successful delete changes only contacts',
    (tester) async {
      final adapter = ScriptedAdapter()
        ..enqueue(200, _workspace())
        ..enqueue(200, [_contact()])
        ..enqueue(200, {'message': 'participant removed successfully'});
      await _mount(tester, adapter);
      await tester.tap(find.byTooltip('Remove contact'));
      await tester.pumpAndSettle();
      expect(find.textContaining('does not rename speakers'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(adapter.requests, hasLength(2));
      await tester.tap(find.byTooltip('Remove contact'));
      await tester.pumpAndSettle();
      await _action(tester, 'Remove');
      expect(find.text('No participants yet'), findsOneWidget);
      expect(adapter.requests.last.path, '$_path/$_contactId');
      expect(adapter.requests.last.method, 'DELETE');
    },
  );

  testWidgets(
    'lost delete response is confirmed by absence and never blindly replays DELETE',
    (tester) async {
      final adapter = ScriptedAdapter()
        ..enqueue(200, _workspace())
        ..enqueue(200, [_contact()])
        ..enqueue(200, {'message': 'participant removed successfully'})
        ..enqueue(200, null);
      final container = await _mount(tester, adapter, loseDeleteResponse: true);
      await tester.tap(find.byTooltip('Remove contact'));
      await tester.pumpAndSettle();
      await _action(tester, 'Remove');
      await _check(tester);
      expect(
        container.read(workspaceDetailProvider(_workspaceId)).participants,
        isEmpty,
      );
      expect(adapter.requests.where((r) => r.method == 'DELETE'), hasLength(1));
    },
  );

  testWidgets(
    'forbidden delete preserves the contact and shows a safe real error',
    (tester) async {
      final adapter = ScriptedAdapter()
        ..enqueue(200, _workspace())
        ..enqueue(200, [_contact()])
        ..enqueue(403, {
          'error': 'only workspace owner can remove participants',
        });
      final container = await _mount(tester, adapter);
      await tester.tap(find.byTooltip('Remove contact'));
      await tester.pumpAndSettle();
      await _action(tester, 'Remove');
      expect(
        container.read(workspaceDetailProvider(_workspaceId)).participants,
        hasLength(1),
      );
      expect(
        find.text('Недостаточно прав для этого действия.'),
        findsNWidgets(2),
      );
      expect(
        container
            .read(workspaceDetailProvider(_workspaceId))
            .needsContactReconciliation,
        isFalse,
      );
    },
  );
}
