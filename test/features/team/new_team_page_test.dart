import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gdzs_calc/features/team/models/active_team_session.dart';
import 'package:gdzs_calc/features/team/new_team_page.dart';
import 'package:gdzs_calc/features/team/repositories/team_session_repository.dart';
import 'package:gdzs_calc/shared/models/apparatus.dart';
import 'package:gdzs_calc/shared/models/firefighter.dart';
import 'package:gdzs_calc/shared/models/unit.dart';

void main() {
  testWidgets('default filter shows firefighters from all watches', (
    tester,
  ) async {
    await _pumpSubject(tester);

    expect(find.text('Усі караули'), findsOneWidget);
    for (final id in [1, 7, 8, 9]) {
      expect(find.byKey(ValueKey('candidate-$id')), findsOneWidget);
    }
  });

  testWidgets('watch filter affects candidates only', (tester) async {
    await _pumpSubject(tester);
    await _toggleCandidate(tester, 1);
    await _selectWatch(tester, '2-й караул');

    expect(find.byKey(const ValueKey('candidate-1')), findsNothing);
    expect(find.byKey(const ValueKey('candidate-7')), findsOneWidget);
    expect(find.byKey(const ValueKey('selected-member-1')), findsOneWidget);
    expect(find.text('1 із 5'), findsOneWidget);
    expect(find.text('Змінити караул?'), findsNothing);
  });

  testWidgets('mixed team and leader survive filter changes', (tester) async {
    await _pumpSubject(tester);
    await _selectWatch(tester, '1-й караул');
    await _toggleCandidate(tester, 1);
    await _selectWatch(tester, '2-й караул');
    await _toggleCandidate(tester, 7);
    await _selectLeader(tester, 1);
    await _selectWatch(tester, '3-й караул');

    expect(find.byKey(const ValueKey('selected-member-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('selected-member-7')), findsOneWidget);
    expect(find.text('2 із 5'), findsOneWidget);
    expect(find.text('1-й караул · Командир'), findsOneWidget);
  });

  testWidgets('search is case insensitive and checks the whole name', (
    tester,
  ) async {
    await _pumpSubject(tester);
    await tester.enterText(
      find.byKey(const Key('firefighter-search')),
      'інШий КАРАУЛ',
    );
    await tester.pump();

    expect(find.byKey(const ValueKey('candidate-7')), findsOneWidget);
    expect(find.byKey(const ValueKey('candidate-1')), findsNothing);
  });

  testWidgets('search combines with watch filter and can be cleared', (
    tester,
  ) async {
    await _pumpSubject(tester);
    await _selectWatch(tester, '1-й караул');
    await tester.enterText(
      find.byKey(const Key('firefighter-search')),
      'інший',
    );
    await tester.pump();

    expect(find.text('Газодимозахисників не знайдено'), findsOneWidget);
    expect(find.text('Змініть караул або очистьте пошук'), findsOneWidget);
    await tester.tap(find.byKey(const Key('clear-firefighter-search')));
    await tester.pump();
    expect(find.byKey(const ValueKey('candidate-1')), findsOneWidget);
  });

  testWidgets('selected team stays visible when search has no results', (
    tester,
  ) async {
    await _pumpSubject(tester);
    await _toggleCandidate(tester, 1);
    await tester.enterText(
      find.byKey(const Key('firefighter-search')),
      'немає такого прізвища',
    );
    await tester.pump();

    expect(find.byKey(const ValueKey('selected-member-1')), findsOneWidget);
    expect(find.text('Газодимозахисників не знайдено'), findsOneWidget);
  });

  testWidgets('sixth member is rejected with a snackbar', (tester) async {
    await _pumpSubject(tester);
    for (final id in [1, 2, 3, 4, 5, 6]) {
      await _toggleCandidate(tester, id);
    }

    expect(find.text('5 із 5'), findsOneWidget);
    expect(
      find.text('До складу ланки можна включити не більше 5 осіб'),
      findsOneWidget,
    );
  });

  testWidgets('removing leader clears leader and asks for replacement', (
    tester,
  ) async {
    await _pumpSubject(tester);
    await _toggleCandidate(tester, 1);
    await _toggleCandidate(tester, 7);
    await _selectLeader(tester, 1);
    await tester.tap(find.byKey(const ValueKey('remove-member-1')));
    await tester.pump();

    final field = tester.widget<DropdownButtonFormField<int>>(
      find.byKey(const Key('leader-selector')),
    );
    expect(field.initialValue, isNull);
    expect(find.text('Оберіть нового командира ланки'), findsOneWidget);
  });

  testWidgets('pressure fields include every selected watch in chosen order', (
    tester,
  ) async {
    await _pumpSubject(tester);
    await _selectUnitAndApparatus(tester);
    await _toggleCandidate(tester, 7);
    await _toggleCandidate(tester, 1);
    await _selectLeader(tester, 7);
    await tester.ensureVisible(find.text('Далі'));
    await tester.tap(find.text('Далі'));
    await tester.pumpAndSettle();

    expect(find.byType(TextFormField), findsNWidgets(2));
    expect(find.text('Інший караул · 2-й караул'), findsOneWidget);
    expect(find.text('Перший · 1-й караул'), findsOneWidget);
  });

  testWidgets('inclusion creates a mixed advancing session with snapshots', (
    tester,
  ) async {
    final repository = _CreatingRepository();
    await _pumpSubject(tester, repository: repository);
    await _selectUnitAndApparatus(tester);
    await _toggleCandidate(tester, 1);
    await _toggleCandidate(tester, 7);
    await _selectLeader(tester, 1);
    await tester.ensureVisible(find.text('Далі'));
    await tester.tap(find.text('Далі'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Увімкнутися в ЗІЗОД'));
    await tester.tap(find.text('Увімкнутися в ЗІЗОД'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Увімкнутися'));
    await tester.pumpAndSettle();

    expect(repository.session!.stage, ActiveTeamStage.advancing);
    expect(repository.session!.participants.map((e) => e.watchNumber), [1, 2]);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('unspecified filter is offered only when needed', (tester) async {
    await _pumpSubject(tester);
    await tester.tap(find.byKey(const Key('watch-selector')));
    await tester.pumpAndSettle();
    final unspecifiedOption = find.descendant(
      of: find.byType(DropdownMenuItem<int>),
      matching: find.text('Без визначеного караулу'),
    );
    expect(unspecifiedOption, findsOneWidget);
    await tester.tap(unspecifiedOption);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('candidate-9')), findsOneWidget);
    expect(find.byKey(const ValueKey('candidate-1')), findsNothing);
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
    expect(find.byKey(const ValueKey('candidate-20')), findsOneWidget);
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
  Firefighter(id: 8, fullName: 'Третій караул', watch: '3'),
  Firefighter(id: 9, fullName: 'Без караулу', watch: ''),
];

Future<void> _pumpSubject(
  WidgetTester tester, {
  TeamSessionRepository? repository,
}) async {
  _largeView(tester);
  await tester.pumpWidget(
    MaterialApp(
      home: NewTeamPage(
        teamSessionRepository: repository,
        initialUnits: _units,
        initialApparatus: _apparatus,
        initialFirefighters: _firefighters,
      ),
    ),
  );
}

void _largeView(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _toggleCandidate(WidgetTester tester, int id) async {
  final finder = find.byKey(ValueKey('candidate-$id'));
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pump();
}

Future<void> _selectWatch(WidgetTester tester, String label) async {
  final field = find.byKey(const Key('watch-selector'));
  await tester.ensureVisible(field);
  await tester.tap(field);
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

Future<void> _selectLeader(WidgetTester tester, int id) async {
  final field = find.byKey(const Key('leader-selector'));
  await tester.ensureVisible(field);
  final widget = tester.widget<DropdownButtonFormField<int>>(field);
  widget.onChanged!(id);
  await tester.pump();
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
  Future<TeamSessionRecord?> getById(int id) async =>
      TeamSessionRecord(id: id, session: session!);
}
