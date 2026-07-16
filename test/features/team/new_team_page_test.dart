import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gdzs_calc/features/team/models/active_team_session.dart';
import 'package:gdzs_calc/features/team/new_team_page.dart';
import 'package:gdzs_calc/features/team/repositories/team_session_repository.dart';
import 'package:gdzs_calc/shared/models/apparatus.dart';
import 'package:gdzs_calc/shared/models/firefighter.dart';
import 'package:gdzs_calc/shared/models/unit.dart';

void main() {
  testWidgets('inclusion button creates an advancing session', (tester) async {
    tester.view.physicalSize = const Size(1200, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = _CreatingRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: NewTeamPage(
          teamSessionRepository: repository,
          initialUnits: [Unit(id: 1, name: 'ДПРЧ-1', city: 'Київ')],
          initialApparatus: [
            Apparatus(
              id: 1,
              name: 'Drager',
              workingPressure: 300,
              cylinderVolume: 6.8,
              cylindersCount: 1,
              reservePressure: 50,
            ),
          ],
          initialFirefighters: [
            Firefighter(id: 1, fullName: 'Перший', watch: '1'),
            Firefighter(id: 2, fullName: 'Другий', watch: '1'),
          ],
        ),
      ),
    );

    await tester.tap(find.byType(DropdownButtonFormField<Unit>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ДПРЧ-1 (Київ)').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byType(DropdownButtonFormField<Apparatus>));
    await tester.tap(find.byType(DropdownButtonFormField<Apparatus>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Drager').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('watch-selector')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('1-й караул').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Перший'));
    await tester.tap(find.text('Другий'));
    await tester.pump();
    await tester.tap(find.byKey(const Key('leader-selector')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Перший').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Далі'));
    await tester.pumpAndSettle();

    expect(find.text('Увімкнутися в ЗІЗОД'), findsOneWidget);
    final before = DateTime.now();
    await tester.ensureVisible(find.text('Увімкнутися в ЗІЗОД'));
    await tester.pump();
    await tester.tap(find.text('Увімкнутися в ЗІЗОД'));
    await tester.pumpAndSettle();
    expect(find.text('Підтвердити включення в ЗІЗОД?'), findsOneWidget);
    await tester.tap(find.text('Увімкнутися'));
    await tester.pumpAndSettle();

    expect(repository.session!.stage, ActiveTeamStage.advancing);
    expect(repository.session!.arrivalTime, isNull);
    expect(repository.session!.inclusionTime.isBefore(before), isFalse);
    expect(find.text('Час прямування'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('watch filter shows only firefighters from selected watch', (
    tester,
  ) async {
    _largeView(tester);
    await tester.pumpWidget(_subject(_firefighters));

    expect(find.text('Спочатку оберіть караул'), findsOneWidget);
    expect(find.text('Перший'), findsNothing);
    await _selectWatch(tester, '1-й караул');

    expect(find.text('Перший'), findsOneWidget);
    expect(find.text('Другий'), findsOneWidget);
    expect(find.text('Інший караул'), findsNothing);
  });

  testWidgets('multiple selection limits leader choices to selected members', (
    tester,
  ) async {
    _largeView(tester);
    await tester.pumpWidget(_subject(_firefighters));
    await _selectWatch(tester, '1-й караул');
    await tester.tap(find.text('Перший'));
    await tester.tap(find.text('Другий'));
    await tester.pump();

    expect(find.text('Обрано: 2'), findsOneWidget);
    await tester.tap(find.byKey(const Key('leader-selector')));
    await tester.pumpAndSettle();
    expect(find.text('Перший'), findsNWidgets(2));
    expect(find.text('Другий'), findsNWidgets(2));
    expect(find.text('Третій'), findsOneWidget);
  });

  testWidgets('sixth member is rejected with a snackbar', (tester) async {
    _largeView(tester);
    await tester.pumpWidget(_subject(_firefighters));
    await _selectWatch(tester, '1-й караул');
    for (final name in ['Перший', 'Другий', 'Третій', 'Четвертий', 'П’ятий']) {
      await tester.ensureVisible(find.text(name));
      await tester.tap(find.text(name));
      await tester.pump();
    }
    await tester.ensureVisible(find.text('Шостий'));
    await tester.tap(find.text('Шостий'));
    await tester.pump();

    expect(find.text('Обрано: 5'), findsOneWidget);
    expect(
      find.text('До складу ланки можна включити не більше 5 осіб'),
      findsOneWidget,
    );
  });

  testWidgets('removing leader clears selection and asks for a new leader', (
    tester,
  ) async {
    _largeView(tester);
    await tester.pumpWidget(_subject(_firefighters));
    await _selectWatch(tester, '1-й караул');
    await tester.tap(find.text('Перший'));
    await tester.tap(find.text('Другий'));
    await tester.pump();
    await _selectLeader(tester, 'Перший');

    await tester.tap(find.text('Перший').first);
    await tester.pump();
    final leaderField = tester.widget<DropdownButtonFormField<int>>(
      find.byKey(const Key('leader-selector')),
    );
    expect(leaderField.initialValue, isNull);
    expect(find.text('Оберіть нового командира ланки'), findsOneWidget);
  });

  testWidgets('watch change can be cancelled or confirmed', (tester) async {
    _largeView(tester);
    await tester.pumpWidget(_subject(_firefighters));
    await _selectWatch(tester, '1-й караул');
    await tester.tap(find.text('Перший'));
    await tester.pump();

    await _requestWatch(tester, '2-й караул');
    expect(find.text('Змінити караул?'), findsOneWidget);
    await tester.tap(find.text('Скасувати'));
    await tester.pumpAndSettle();
    expect(find.text('Обрано: 1'), findsOneWidget);
    expect(find.text('Перший'), findsOneWidget);

    await _requestWatch(tester, '2-й караул');
    await tester.tap(find.text('Змінити караул'));
    await tester.pumpAndSettle();
    expect(find.text('Обрано: 0'), findsOneWidget);
    expect(find.text('Інший караул'), findsOneWidget);
    expect(find.text('Перший'), findsNothing);
  });

  testWidgets('pressure fields are created only for selected members', (
    tester,
  ) async {
    _largeView(tester);
    await tester.pumpWidget(_subject(_firefighters));
    await _selectUnitAndApparatus(tester);
    await _selectWatch(tester, '1-й караул');
    await tester.tap(find.text('Перший'));
    await tester.tap(find.text('Другий'));
    await tester.pump();
    await _selectLeader(tester, 'Перший');
    await tester.tap(find.text('Далі'));
    await tester.pumpAndSettle();

    expect(find.byType(TextFormField), findsNWidgets(2));
    expect(find.text('Перший'), findsOneWidget);
    expect(find.text('Другий'), findsOneWidget);
    expect(find.text('Третій'), findsNothing);
  });

  testWidgets('returning from directory reloads firefighters', (tester) async {
    _largeView(tester);
    var loadCount = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: NewTeamPage(
          initialUnits: _units,
          initialApparatus: _apparatus,
          initialFirefighters: const [],
          firefightersLoader: () async {
            loadCount += 1;
            return const [
              Firefighter(id: 20, fullName: 'Новий працівник', watch: '3'),
            ];
          },
          firefightersDirectoryBuilder: (_) => Scaffold(
            body: Builder(
              builder: (context) => FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Повернутися'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Додати газодимозахисника'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Повернутися'));
    await tester.pumpAndSettle();
    expect(loadCount, 1);
    await _selectWatch(tester, '3-й караул');
    expect(find.text('Новий працівник'), findsOneWidget);
  });
}

const _units = [Unit(id: 1, name: 'ДПРЧ-1', city: 'Київ')];
const _apparatus = [
  Apparatus(
    id: 1,
    name: 'Drager',
    workingPressure: 300,
    cylinderVolume: 6.8,
    cylindersCount: 1,
    reservePressure: 50,
  ),
];
const _firefighters = [
  Firefighter(id: 1, fullName: 'Перший', watch: '1'),
  Firefighter(id: 2, fullName: 'Другий', watch: '1'),
  Firefighter(id: 3, fullName: 'Третій', watch: '1'),
  Firefighter(id: 4, fullName: 'Четвертий', watch: '1'),
  Firefighter(id: 5, fullName: 'П’ятий', watch: '1'),
  Firefighter(id: 6, fullName: 'Шостий', watch: '1'),
  Firefighter(id: 7, fullName: 'Інший караул', watch: '2'),
];

Widget _subject(List<Firefighter> firefighters) => MaterialApp(
  home: NewTeamPage(
    initialUnits: _units,
    initialApparatus: _apparatus,
    initialFirefighters: firefighters,
  ),
);

void _largeView(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _selectWatch(WidgetTester tester, String label) async {
  await tester.tap(find.byKey(const Key('watch-selector')));
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

Future<void> _requestWatch(WidgetTester tester, String label) async {
  await tester.ensureVisible(find.byKey(const Key('watch-selector')));
  await tester.tap(find.byKey(const Key('watch-selector')));
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

Future<void> _selectLeader(WidgetTester tester, String name) async {
  await tester.ensureVisible(find.byKey(const Key('leader-selector')));
  await tester.tap(find.byKey(const Key('leader-selector')));
  await tester.pumpAndSettle();
  await tester.tap(find.text(name).last);
  await tester.pumpAndSettle();
}

Future<void> _selectUnitAndApparatus(WidgetTester tester) async {
  await tester.tap(find.byType(DropdownButtonFormField<Unit>));
  await tester.pumpAndSettle();
  await tester.tap(find.text('ДПРЧ-1 (Київ)').last);
  await tester.pumpAndSettle();
  await tester.tap(find.byType(DropdownButtonFormField<Apparatus>));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Drager').last);
  await tester.pumpAndSettle();
}

class _CreatingRepository extends TeamSessionRepository {
  ActiveTeamSession? session;

  @override
  Future<TeamSessionRecord?> getActiveSession() async => null;

  @override
  Future<int> createAdvancingSession({
    required Unit unit,
    required Apparatus apparatus,
    required ActiveTeamSession session,
  }) async {
    this.session = session;
    return 1;
  }

  @override
  Future<TeamSessionRecord?> getById(int id) async => TeamSessionRecord(
    id: id,
    session: session!,
    watchNumber: session!.participants.first.watchNumber,
  );
}
