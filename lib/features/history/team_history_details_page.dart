import 'package:flutter/material.dart';
import 'package:gdzs_calc/features/history/history_formatters.dart';
import 'package:gdzs_calc/features/history/team_report_preview_page.dart';
import 'package:gdzs_calc/features/team/models/active_team_session.dart';
import 'package:gdzs_calc/features/team/repositories/team_session_repository.dart';
import 'package:gdzs_calc/shared/models/firefighter.dart';
import 'package:gdzs_calc/shared/utils/firefighter_watch_groups.dart';

class TeamHistoryDetailsPage extends StatefulWidget {
  final int sessionId;
  final TeamSessionRepository? repository;

  const TeamHistoryDetailsPage({
    super.key,
    required this.sessionId,
    this.repository,
  });

  @override
  State<TeamHistoryDetailsPage> createState() => _TeamHistoryDetailsPageState();
}

class _TeamHistoryDetailsPageState extends State<TeamHistoryDetailsPage> {
  late final TeamSessionRepository _repository;
  ActiveTeamSession? _session;
  bool _loading = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? const TeamSessionRepository();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() => _failed = false);
    try {
      final record = await _repository.getById(widget.sessionId);
      if (!mounted) return;
      setState(() {
        _session = record?.session;
        _loading = false;
        _failed = record == null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _failed = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Деталі ланки')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _failed
          ? _DetailsError(onRetry: _load)
          : _content(_session!),
    );
  }

  Widget _content(ActiveTeamSession session) => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      _section(
        title: 'Загальна інформація',
        initiallyExpanded: true,
        children: [
          _line('Статус', 'Завершено'),
          _line('Підрозділ', session.unitName),
          _line('Караул', teamWatchLabel(session.participants)),
          _line('Апарат', session.apparatusName),
          _line('Умови роботи', workLoadLabel(session.workLoad)),
          _line('Командир', _memberName(session, session.leaderId)),
          _line('Кількість учасників', '${session.participants.length}'),
        ],
      ),
      _section(
        title: 'Часові точки',
        initiallyExpanded: true,
        children: [
          _line('Включення в ЗІЗОД', historyDateTime(session.inclusionTime)),
          _line(
            'Прибуття до місця роботи',
            historyDateTime(session.arrivalTime),
          ),
          _line('Початок виходу', historyDateTime(session.exitStartedAt)),
          _line('Вихід на свіже повітря', historyDateTime(session.completedAt)),
          _line(
            'Загальний час у ЗІЗОД',
            historyDuration(session.totalDuration),
          ),
          _line(
            'Час прямування',
            historyDuration(
              session.arrivalTime?.difference(session.inclusionTime),
            ),
          ),
          _line(
            'Час роботи до початку виходу',
            historyDuration(
              session.arrivalTime == null || session.exitStartedAt == null
                  ? null
                  : session.exitStartedAt!.difference(session.arrivalTime!),
            ),
          ),
        ],
      ),
      _section(
        title: 'Склад ланки',
        initiallyExpanded: true,
        children: [
          for (final member in session.participants)
            _memberCard(session, member),
        ],
      ),
      _section(
        title: 'Розрахунок',
        children: [
          _line(
            'Максимальна витрата на прямування',
            _bar(session.travelPressure),
          ),
          _line('Тиск виходу', _bar(session.exitPressure)),
          _line('Робочий запас тиску', _bar(session.workingPressure)),
          _line(
            'Початково розрахований час роботи',
            historyDuration(
              session.arrivalTime == null ||
                      session.initialPlannedExitTime == null
                  ? null
                  : session.initialPlannedExitTime!.difference(
                      session.arrivalTime!,
                    ),
            ),
          ),
        ],
      ),
      _section(
        title: 'Контроль тиску',
        children: session.pressureCheckDetails.isEmpty
            ? [const Text('Контрольні заміри не зафіксовано')]
            : [
                for (final check in session.pressureCheckDetails)
                  _pressureCheck(session, check),
              ],
      ),
      if (session.emergencies.isNotEmpty)
        _section(
          title: 'Надзвичайні ситуації',
          children: [
            for (final emergency in session.emergencies) _emergency(emergency),
          ],
        ),
      _section(
        title: 'Журнал подій',
        children: session.events.isEmpty
            ? [const Text('Події не зафіксовано')]
            : [
                for (final event in session.events)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Text(historyTime(event.time, seconds: true)),
                    title: Text(event.title),
                    subtitle: event.description.isEmpty
                        ? null
                        : Text(event.description),
                  ),
              ],
      ),
      if (session.stage == ActiveTeamStage.completed)
        SizedBox(
          height: 52,
          child: FilledButton.icon(
            key: const Key('create-pdf-report'),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => TeamReportPreviewPage(
                  sessionId: widget.sessionId,
                  repository: _repository,
                ),
              ),
            ),
            icon: const Icon(Icons.picture_as_pdf_rounded),
            label: const Text('Сформувати PDF-звіт'),
          ),
        ),
    ],
  );

  Widget _section({
    required String title,
    required List<Widget> children,
    bool initiallyExpanded = false,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Card(
      child: ExpansionTile(
        initiallyExpanded: initiallyExpanded,
        title: Text(title),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: children,
      ),
    ),
  );

  Widget _line(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: Text(label)),
        const SizedBox(width: 12),
        Flexible(child: Text(value, textAlign: TextAlign.end)),
      ],
    ),
  );

  Widget _memberCard(ActiveTeamSession session, Firefighter member) {
    final id = member.id!;
    final latest =
        session.latestPressuresByFirefighterId[id] ??
        session.arrivalPressuresByFirefighterId[id] ??
        session.startPressuresByFirefighterId[id];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(member.fullName),
            Text(id == session.leaderId ? 'Командир' : 'Учасник'),
            Text(member.watchLabel),
            _line(
              'Початковий тиск',
              '${session.startPressuresByFirefighterId[id]} бар',
            ),
            _line(
              'Тиск після прибуття',
              _bar(session.arrivalPressuresByFirefighterId[id]),
            ),
            _line('Останній підтверджений тиск', _bar(latest)),
          ],
        ),
      ),
    );
  }

  Widget _pressureCheck(
    ActiveTeamSession session,
    PressureCheckDetails check,
  ) => Card(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(historyDateTime(check.checkedAt)),
          _line(
            'Визначальний газодимозахисник',
            _memberName(session, check.controllingFirefighterId),
          ),
          _line('Залишок роботи', '${check.remainingWorkMinutes} хв'),
          _line(
            'Розрахований початок виходу',
            historyDateTime(check.plannedExitTimeAfterCheck),
          ),
          if (check.emergencyMode)
            const Text('Заміри виконано в аварійному режимі'),
          const Divider(height: 20),
          for (final member in session.participants) ...[
            Text(member.fullName),
            _line(
              'Розрахунковий тиск',
              _bar(check.estimatedPressuresByFirefighterId[member.id]),
            ),
            _line(
              'Фактичний тиск',
              _bar(check.actualPressuresByFirefighterId[member.id]),
            ),
            if (check.estimatedPressuresByFirefighterId[member.id] != null &&
                check.actualPressuresByFirefighterId[member.id] != null)
              Text(
                pressureDeviation(
                  check.estimatedPressuresByFirefighterId[member.id]!,
                  check.actualPressuresByFirefighterId[member.id]!,
                ),
              ),
            const SizedBox(height: 8),
          ],
        ],
      ),
    ),
  );

  Widget _emergency(TeamEmergency emergency) => Card(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(emergency.reason.label),
          _line('Початок', historyDateTime(emergency.startedAt)),
          _line('Етап виникнення', emergency.stageAtStart.label),
          _line(
            'Стан зв’язку',
            emergency.communicationAvailable ? 'Наявний' : 'Відсутній',
          ),
          _line('Останній контакт', historyDateTime(emergency.lastContactAt)),
          _line(
            'Примітка',
            emergency.note?.trim().isNotEmpty == true
                ? emergency.note!
                : 'Не зафіксовано',
          ),
          _line('Завершення', historyDateTime(emergency.resolvedAt)),
          _line(
            'Тривалість',
            historyDuration(
              emergency.resolvedAt?.difference(emergency.startedAt),
            ),
          ),
        ],
      ),
    ),
  );

  String _memberName(ActiveTeamSession session, int id) =>
      session.participants
          .where((member) => member.id == id)
          .map((member) => member.fullName)
          .firstOrNull ??
      'Не зафіксовано';

  String _bar(int? value) => value == null ? 'Не зафіксовано' : '$value бар';
}

class _DetailsError extends StatelessWidget {
  final VoidCallback onRetry;
  const _DetailsError({required this.onRetry});
  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('Не вдалося завантажити дані ланки'),
        const SizedBox(height: 12),
        FilledButton(onPressed: onRetry, child: const Text('Повторити')),
      ],
    ),
  );
}
