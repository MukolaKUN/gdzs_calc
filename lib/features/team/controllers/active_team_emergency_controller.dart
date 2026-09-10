import 'package:flutter/material.dart';
import 'package:gdzs_calc/features/team/models/active_team_session.dart';
import 'package:gdzs_calc/features/team/repositories/team_session_repository.dart';
import 'package:gdzs_calc/features/team/widgets/emergency_form_dialog.dart';

typedef EmergencyConfirmation =
    Future<bool> Function({
      required String title,
      required String text,
      required String action,
    });

/// Owns emergency-mode workflows while the page retains navigation and UI state.
class ActiveTeamEmergencyController {
  const ActiveTeamEmergencyController({
    required this.sessionId,
    required this.repository,
    required this.now,
    required this.session,
    required this.reload,
    required this.isMounted,
    required this.confirm,
    required this.openPressureSheet,
    required this.cancelPressureReminders,
  });

  final int sessionId;
  final TeamSessionRepository repository;
  final DateTime Function() now;
  final ActiveTeamSession Function() session;
  final Future<void> Function() reload;
  final bool Function() isMounted;
  final EmergencyConfirmation confirm;
  final Future<Map<int, int>?> Function({
    required Map<int, int> estimates,
    required Map<int, int> maximums,
  })
  openPressureSheet;
  final Future<void> Function() cancelPressureReminders;

  Future<void> start(BuildContext context) async {
    final current = session();
    if (current.hasActiveEmergency) return;
    final input = await showDialog<EmergencyFormInput>(
      context: context,
      builder: (_) => const EmergencyFormDialog(),
    );
    if (!isMounted() || input == null) return;
    final confirmed = await confirm(
      title: 'Підтвердити аварійний режим?',
      text: 'Буде увімкнено аварійний режим та зафіксовано час події.',
      action: 'Увімкнути',
    );
    if (!isMounted() || !confirmed) return;
    final at = now();
    final communicationAvailable =
        input.reason == EmergencyReason.communicationLost
        ? false
        : input.communicationAvailable;
    final emergency = TeamEmergency(
      reason: input.reason,
      startedAt: at,
      stageAtStart: current.stage,
      communicationAvailable: communicationAvailable,
      lastContactAt: communicationAvailable ? at : null,
      note: input.note,
    );
    await repository.startEmergency(
      sessionId,
      emergency,
      'Причина: ${input.reason.label}.\n'
      'Етап: ${current.stage.label}.\n'
      'Зв’язок із ланкою ${communicationAvailable ? 'наявний' : 'відсутній'}.'
      '${input.note == null ? '' : '\nПримітка: ${input.note}'}',
    );
    if (isMounted()) await reload();
  }

  Future<void> emergencyPressureCheck() async {
    final current = session();
    final emergency = current.activeEmergency;
    if (emergency == null || !emergency.communicationAvailable) return;
    final checkedAt = now();
    final snapshots = current.emergencyPressureSnapshotsAt(checkedAt);
    final estimates = {
      for (final entry in snapshots.entries)
        entry.key: entry.value.estimatedPressure,
    };
    final result = await openPressureSheet(
      estimates: estimates,
      maximums: {
        for (final entry in snapshots.entries)
          entry.key: entry.value.confirmedPressure,
      },
    );
    if (!isMounted() || result == null) return;
    await repository.addPressureCheck(
      sessionId: sessionId,
      checkedAt: checkedAt,
      estimated: estimates,
      actual: result,
      emergencyMode: true,
    );
    if (isMounted()) await reload();
  }

  Future<void> restoreCommunication() async {
    await repository.restoreCommunication(sessionId, now());
    if (!isMounted()) return;
    await reload();
    await emergencyPressureCheck();
  }

  Future<void> recordAction(BuildContext context) async {
    const actions = [
      'Резервну ланку направлено',
      'Встановлено зв’язок',
      'Шлях виходу заблоковано',
      'Розпочато деблокування',
      'Ланка продовжує вихід',
      'Інша дія',
    ];
    final selected = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const ListTile(title: Text('Зафіксувати дію')),
            for (final action in actions)
              ListTile(
                title: Text(action),
                onTap: () => Navigator.pop(sheetContext, action),
              ),
          ],
        ),
      ),
    );
    if (!isMounted() || !context.mounted || selected == null) return;
    var title = selected;
    if (selected == 'Інша дія') {
      final field = TextEditingController();
      final note = await showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Інша дія'),
          content: TextField(
            controller: field,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Опис дії'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Скасувати'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, field.text.trim()),
              child: const Text('Зберегти'),
            ),
          ],
        ),
      );
      field.dispose();
      if (!isMounted() || note == null || note.isEmpty) return;
      title = note;
    }
    await repository.addEmergencyAction(sessionId, now(), title);
    if (isMounted()) await reload();
  }

  Future<void> resolve() async {
    final confirmed = await confirm(
      title: 'Надзвичайну ситуацію усунено?',
      text: 'Аварійний режим буде завершено без зміни основного етапу.',
      action: 'Підтвердити',
    );
    if (!isMounted() || !confirmed) return;
    final emergency = session().activeEmergency!;
    final at = now();
    final duration = at.difference(emergency.startedAt);
    await repository.resolveEmergency(
      sessionId,
      at,
      'Причина: ${emergency.reason.label}. Тривалість: ${duration.inMinutes} хв ${duration.inSeconds % 60} с.',
    );
    if (isMounted()) await reload();
  }

  Future<void> complete() async {
    final confirmed = await confirm(
      title: 'Підтвердити вихід ланки?',
      text: 'Ланка вийшла з НДС на свіже повітря.',
      action: 'Підтвердити вихід',
    );
    if (!isMounted() || !confirmed) return;
    await repository.completeSession(sessionId, now(), fromEmergency: true);
    await cancelPressureReminders();
    if (isMounted()) await reload();
  }
}
