import 'package:flutter/services.dart';
import 'package:gdzs_calc/features/history/history_formatters.dart';
import 'package:gdzs_calc/features/history/models/team_report_data.dart';
import 'package:gdzs_calc/features/team/models/active_team_session.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class TeamPdfReportService {
  final Future<ByteData> Function(String asset) loadAsset;
  final DateTime Function() now;

  TeamPdfReportService({
    Future<ByteData> Function(String)? loadAsset,
    DateTime Function()? now,
  }) : loadAsset = loadAsset ?? rootBundle.load,
       now = now ?? DateTime.now;

  Future<Uint8List> generate(TeamReportData data) async {
    final regular = pw.Font.ttf(
      await loadAsset('assets/fonts/NotoSans-Regular.ttf'),
    );
    final bold = pw.Font.ttf(await loadAsset('assets/fonts/NotoSans-Bold.ttf'));
    final generatedAt = now();
    final session = data.session;
    final document = pw.Document();
    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(48, 48, 48, 52),
        theme: pw.ThemeData.withFont(base: regular, bold: bold),
        header: (_) => pw.Column(
          children: [
            pw.Text(
              'ЗВІТ ПРО РОБОТУ ЛАНКИ ГДЗС',
              style: pw.TextStyle(
                font: bold,
                fontSize: 16,
                color: PdfColors.blue900,
              ),
            ),
            pw.SizedBox(height: 5),
            pw.Text(
              '${data.unitName} • ${historyDate(session.inclusionTime)} • сесія №${session.databaseId ?? '—'} • Завершено',
            ),
            pw.Divider(color: PdfColors.blueGrey400),
          ],
        ),
        footer: (context) => pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('GDZS Calculator', style: const pw.TextStyle(fontSize: 8)),
            pw.Text(
              'Сформовано ${historyDateTime(generatedAt)}',
              style: const pw.TextStyle(fontSize: 8),
            ),
            pw.Text(
              'Сторінка ${context.pageNumber}',
              style: const pw.TextStyle(fontSize: 8),
            ),
          ],
        ),
        build: (_) => [
          ..._section('Загальна інформація', [
            _pairs([
              ['Підрозділ', data.unitName],
              ['Склад караулу', data.watchLabel],
              ['Тип апарата', data.apparatusName],
              ['Робочий тиск апарата', _bar(session.apparatusWorkingPressure)],
              ['Об’єм балона', '${session.cylinderVolume} л'],
              ['Кількість балонів', '${session.cylindersCount}'],
              ['Резервний тиск', _bar(session.reservePressure)],
              ['Умови роботи', workLoadLabel(session.workLoad)],
              [
                'Командир ланки',
                data.members
                        .where((e) => e.isLeader)
                        .map((e) => e.firefighter.fullName)
                        .firstOrNull ??
                    _missing,
              ],
              ['Кількість учасників', '${data.members.length}'],
            ]),
          ]),
          ..._section('Часові показники', [
            _pairs([
              ['Включення в ЗІЗОД', _dateTime(session.inclusionTime)],
              ['Прибуття до місця роботи', _dateTime(session.arrivalTime)],
              ['Початок виходу з НДС', _dateTime(session.exitStartedAt)],
              ['Вихід на свіже повітря', _dateTime(session.completedAt)],
              [
                'Час прямування',
                _duration(
                  session.arrivalTime?.difference(session.inclusionTime),
                ),
              ],
              [
                'Загальний час роботи в ЗІЗОД',
                _duration(session.totalDuration),
              ],
            ]),
          ]),
          ..._section('Склад ланки', [
            _table(
              [
                '№',
                'ПІБ',
                'Роль',
                'Караул',
                'Початковий',
                'Після прибуття',
                'Останній',
              ],
              [
                for (var i = 0; i < data.members.length; i++)
                  [
                    '${i + 1}',
                    data.members[i].firefighter.fullName,
                    data.members[i].isLeader ? 'Командир' : 'Газодимозахисник',
                    data.members[i].firefighter.watchLabel,
                    _bar(data.members[i].startPressure),
                    _bar(data.members[i].arrivalPressure),
                    _bar(data.members[i].latestPressure),
                  ],
              ],
            ),
          ]),
          ..._section('Результати початкового розрахунку', [
            _pairs([
              [
                'Максимальна витрата тиску на прямування',
                _bar(session.travelPressure),
              ],
              ['Тиск виходу', _bar(session.exitPressure)],
              ['Робочий запас тиску', _bar(session.workingPressure)],
              [
                'Розрахунковий час роботи',
                session.workingTimeMinutes == null
                    ? _missing
                    : '${session.workingTimeMinutes} хв',
              ],
              [
                'Початково визначальний газодимозахисник',
                _memberName(data, session.controllingFirefighterId),
              ],
              [
                'Розрахунковий час початку виходу',
                _dateTime(session.initialPlannedExitTime),
              ],
            ]),
          ]),
          ..._section(
            'Контроль тиску',
            session.pressureCheckDetails.isEmpty
                ? [pw.Text('Контрольні заміри не проводилися')]
                : [
                    for (
                      var i = 0;
                      i < session.pressureCheckDetails.length;
                      i++
                    )
                      _check(data, i),
                  ],
          ),
          if (session.emergencies.isNotEmpty)
            ..._section('Надзвичайні ситуації', [
              for (final e in session.emergencies) _emergency(e),
            ], accent: true),
          ..._section(
            'Журнал подій',
            session.events.isEmpty
                ? [pw.Text(_missing)]
                : [
                    _table(
                      ['№', 'Час', 'Подія', 'Опис'],
                      [
                        for (
                          var i = 0;
                          i <
                              (session.events.toList()
                                    ..sort((a, b) => a.time.compareTo(b.time)))
                                  .length;
                          i++
                        )
                          [
                            '${i + 1}',
                            historyTime(
                              (session.events.toList()..sort(
                                    (a, b) => a.time.compareTo(b.time),
                                  ))[i]
                                  .time,
                              seconds: true,
                            ),
                            (session.events.toList()
                                  ..sort((a, b) => a.time.compareTo(b.time)))[i]
                                .title,
                            (session.events.toList()
                                  ..sort((a, b) => a.time.compareTo(b.time)))[i]
                                .description,
                          ],
                      ],
                    ),
                  ],
          ),
          ..._section('Підсумок роботи', [
            _pairs([
              ['Фактичний час виходу', _dateTime(session.completedAt)],
              ['Загальний час у ЗІЗОД', _duration(session.totalDuration)],
              [
                'Останній мінімальний підтверджений тиск',
                _bar(
                  session.latestPressuresByFirefighterId.values.isEmpty
                      ? null
                      : session.latestPressuresByFirefighterId.values.reduce(
                          (a, b) => a < b ? a : b,
                        ),
                ),
              ],
              [
                'Кількість контрольних замірів',
                '${session.pressureCheckDetails.length}',
              ],
              [
                'Кількість надзвичайних ситуацій',
                '${session.emergencies.length}',
              ],
            ]),
            pw.SizedBox(height: 24),
            pw.Text('Постовий на посту безпеки ____________________'),
            pw.SizedBox(height: 18),
            pw.Text('Командир ланки ГДЗС _________________________'),
            pw.SizedBox(height: 18),
            pw.Text(
              'Документ сформовано автоматично на підставі даних, зафіксованих у застосунку GDZS Calculator.',
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
            ),
          ]),
        ],
      ),
    );
    return document.save();
  }

  static const _missing = 'Не зафіксовано';
  static String _bar(int? value) => value == null ? _missing : '$value бар';
  static String _dateTime(DateTime? value) => value == null
      ? _missing
      : '${historyDate(value)} ${historyTime(value, seconds: true)}';
  static String _duration(Duration? value) {
    if (value == null) return _missing;
    final d = value.isNegative ? Duration.zero : value;
    return d.inHours == 0
        ? '${d.inMinutes} хв ${d.inSeconds.remainder(60)} с'
        : '${d.inHours} год ${d.inMinutes.remainder(60).toString().padLeft(2, '0')} хв ${d.inSeconds.remainder(60)} с';
  }

  static String _memberName(TeamReportData data, int? id) =>
      data.members
          .where((e) => e.firefighter.id == id)
          .map((e) => e.firefighter.fullName)
          .firstOrNull ??
      _missing;

  List<pw.Widget> _section(
    String title,
    List<pw.Widget> children, {
    bool accent = false,
  }) => [
    pw.Container(
      padding: const pw.EdgeInsets.only(left: 7),
      decoration: pw.BoxDecoration(
        border: pw.Border(
          left: pw.BorderSide(
            width: 3,
            color: accent ? PdfColors.deepOrange700 : PdfColors.blue900,
          ),
        ),
      ),
      child: pw.Text(
        title,
        style: pw.TextStyle(
          fontWeight: pw.FontWeight.bold,
          fontSize: 13,
          color: accent ? PdfColors.deepOrange800 : PdfColors.blue900,
        ),
      ),
    ),
    pw.SizedBox(height: 7),
    ...children,
    pw.SizedBox(height: 14),
  ];
  pw.Widget _pairs(List<List<String>> rows) =>
      _table(['Показник', 'Значення'], rows);
  pw.Widget _table(List<String> headers, List<List<String>> rows) =>
      pw.TableHelper.fromTextArray(
        headers: headers,
        data: rows,
        headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
        headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
        border: pw.TableBorder.all(color: PdfColors.grey400, width: .5),
        cellStyle: const pw.TextStyle(fontSize: 8),
        cellPadding: const pw.EdgeInsets.all(4),
        cellAlignment: pw.Alignment.topLeft,
      );
  pw.Widget _check(TeamReportData data, int index) {
    final c = data.session.pressureCheckDetails[index];
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Заміp №${index + 1} • ${_dateTime(c.checkedAt)}${c.emergencyMode ? ' • АВАРІЙНИЙ РЕЖИМ' : ''}',
          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
        ),
        pw.Text(
          'Визначальний: ${_memberName(data, c.controllingFirefighterId)}; залишок: ${c.remainingWorkMinutes} хв; вихід: ${_dateTime(c.plannedExitTimeAfterCheck)}',
        ),
        _table(
          ['ПІБ', 'Розрахунковий', 'Фактичний', 'Відхилення'],
          [
            for (final m in data.members)
              [
                m.firefighter.fullName,
                _bar(c.estimatedPressuresByFirefighterId[m.firefighter.id]),
                _bar(c.actualPressuresByFirefighterId[m.firefighter.id]),
                c.estimatedPressuresByFirefighterId[m.firefighter.id] == null ||
                        c.actualPressuresByFirefighterId[m.firefighter.id] ==
                            null
                    ? _missing
                    : pressureDeviation(
                        c.estimatedPressuresByFirefighterId[m.firefighter.id]!,
                        c.actualPressuresByFirefighterId[m.firefighter.id]!,
                      ),
              ],
          ],
        ),
        pw.SizedBox(height: 8),
      ],
    );
  }

  pw.Widget _emergency(TeamEmergency e) => pw.Container(
    margin: const pw.EdgeInsets.only(bottom: 7),
    child: _pairs([
      ['Причина', e.reason.label],
      ['Етап виникнення', e.stageAtStart.label],
      ['Час початку', _dateTime(e.startedAt)],
      ['Зв’язок', e.communicationAvailable ? 'Наявний' : 'Відсутній'],
      ['Останній контакт', _dateTime(e.lastContactAt)],
      ['Примітка', e.note?.trim().isNotEmpty == true ? e.note! : _missing],
      ['Завершення', _dateTime(e.resolvedAt)],
      ['Тривалість', _duration(e.resolvedAt?.difference(e.startedAt))],
    ]),
  );
}
