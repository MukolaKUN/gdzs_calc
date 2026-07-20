import 'package:flutter_test/flutter_test.dart';
import 'package:gdzs_calc/features/history/models/team_report_data.dart';
import 'package:gdzs_calc/features/history/services/report_filename.dart';
import 'package:gdzs_calc/features/history/services/team_pdf_report_service.dart';
import 'package:gdzs_calc/features/team/models/active_team_session.dart';
import 'package:gdzs_calc/shared/models/firefighter.dart';
import 'package:gdzs_calc/shared/services/gdzs_calculator.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('report data uses unit, apparatus and member watch snapshots', () {
    final data = TeamReportData.fromSession(_completed(mixed: true));
    expect(data.unitName, 'ДПРЧ-1 snapshot');
    expect(data.apparatusName, 'АЦ snapshot');
    expect(data.watchLabel, 'Змішаний склад');
    expect(data.members.map((e) => e.firefighter.watch), ['1', '2']);
  });

  test('single watch is shown as a concrete watch', () {
    expect(TeamReportData.fromSession(_completed()).watchLabel, '1-й караул');
  });

  test('unfinished session cannot be exported', () {
    expect(() => TeamReportData.fromSession(_advancing()), throwsStateError);
  });

  test('filename contains inclusion time and removes forbidden characters', () {
    final name = teamReportFilename(
      inclusionTime: DateTime(2026, 7, 20, 19, 20),
      unitName: r'DPRCh:/1*?"<>|',
    );
    expect(name, startsWith('GDZS_2026-07-20_19-20_'));
    expect(name, endsWith('.pdf'));
    expect(RegExp(r'[\\/:*?"<>|]').hasMatch(name.substring(5)), isFalse);
  });

  test('PDF with Ukrainian names starts with PDF signature', () async {
    final bytes = await TeamPdfReportService(now: () => DateTime(2026, 7, 20))
        .generate(
          TeamReportData.fromSession(
            _completed(name: 'Іваненко Олексій Сергійович'),
          ),
        );
    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
  });

  test('PDF with a long event journal generates without exception', () async {
    final bytes = await TeamPdfReportService().generate(
      TeamReportData.fromSession(_completed(eventCount: 50)),
    );
    expect(bytes, isNotEmpty);
  });
}

ActiveTeamSession _advancing() => ActiveTeamSession.advancing(
  databaseId: 7,
  unitName: 'ДПРЧ-1 snapshot',
  apparatusName: 'АЦ snapshot',
  participants: const [
    Firefighter(id: 1, fullName: 'Іваненко Іван', watch: '1'),
    Firefighter(id: 2, fullName: 'Петренко Петро', watch: '1'),
  ],
  leaderId: 1,
  startPressuresByFirefighterId: const {1: 300, 2: 290},
  inclusionTime: DateTime(2026, 7, 20, 19, 20),
  workLoad: WorkLoad.medium,
  cylinderVolume: 6.8,
  cylindersCount: 1,
  reservePressure: 50,
);

ActiveTeamSession _completed({
  bool mixed = false,
  String? name,
  int eventCount = 0,
}) {
  final inclusion = DateTime(2026, 7, 20, 19, 20);
  return ActiveTeamSession.restored(
    databaseId: 7,
    unitName: 'ДПРЧ-1 snapshot',
    apparatusName: 'АЦ snapshot',
    apparatusWorkingPressure: 300,
    participants: [
      Firefighter(id: 1, fullName: name ?? 'Іваненко Іван', watch: '1'),
      Firefighter(id: 2, fullName: 'Петренко Петро', watch: mixed ? '2' : '1'),
    ],
    leaderId: 1,
    startPressuresByFirefighterId: const {1: 300, 2: 290},
    inclusionTime: inclusion,
    workLoad: WorkLoad.medium,
    cylinderVolume: 6.8,
    cylindersCount: 1,
    reservePressure: 50,
    stage: ActiveTeamStage.completed,
    arrivalTime: inclusion.add(const Duration(minutes: 5)),
    arrivalPressuresByFirefighterId: const {1: 280, 2: 270},
    initialPlannedExitTime: inclusion.add(const Duration(minutes: 25)),
    currentPlannedExitTime: inclusion.add(const Duration(minutes: 26)),
    exitStartedAt: inclusion.add(const Duration(minutes: 22)),
    completedAt: inclusion.add(const Duration(minutes: 28)),
    travelPressure: 20,
    exitPressure: 70,
    workingPressure: 200,
    workingTimeMinutes: 20,
    controllingFirefighterId: 2,
    pressureChecks: const [],
    events: [
      for (var i = 0; i < eventCount; i++)
        ActiveTeamEvent(
          time: inclusion.add(Duration(seconds: i)),
          title: 'Подія $i',
          description: List.filled(8, 'Довгий опис події $i').join(' '),
        ),
    ],
  );
}
