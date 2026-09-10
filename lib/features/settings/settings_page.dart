import 'package:flutter/material.dart';
import 'package:gdzs_calc/app/app_services.dart';
import 'package:gdzs_calc/features/apparatus/apparatus_page.dart';
import 'package:gdzs_calc/features/firefighters/firefighters_page.dart';
import 'package:gdzs_calc/features/units/units_page.dart';
import 'package:gdzs_calc/features/settings/backup/repositories/backup_repository.dart';
import 'package:gdzs_calc/features/settings/backup/services/database_backup_service.dart';
import 'package:gdzs_calc/shared/models/exit_warning_settings.dart';
import 'package:gdzs_calc/shared/repositories/exit_warning_settings_repository.dart';
import 'package:gdzs_calc/shared/services/exit_warning_service.dart';
import 'package:gdzs_calc/shared/services/pressure_control_reminder_service.dart';

class SettingsPage extends StatefulWidget {
  final ExitWarningSettingsRepository? warningSettingsRepository;
  final NotificationGateway? notificationGateway;
  final BackupRepository? backupRepository;

  const SettingsPage({
    super.key,
    this.warningSettingsRepository,
    this.notificationGateway,
    this.backupRepository,
  });

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final ExitWarningSettingsRepository _repository;
  NotificationGateway? _gateway;
  ExitWarningSettings? _settings;
  bool _exactAvailable = false;
  bool _notificationsEnabled = false;
  BackupRepository? _backupRepository;
  bool _backupBusy = false;
  DateTime? _lastBackup;

  @override
  void initState() {
    super.initState();
    _repository =
        widget.warningSettingsRepository ??
        const ExitWarningSettingsRepository();
    _gateway =
        widget.notificationGateway ??
        (AppServices.isInitialized ? AppServices.notificationGateway : null);
    _backupRepository =
        widget.backupRepository ??
        (AppServices.isInitialized ? AppServices.backupRepository : null);
    _load();
  }

  Future<void> _load() async {
    final settings = await _repository.load();
    final exact = await _gateway?.canScheduleExactAlarms() ?? false;
    final enabled = await _gateway?.notificationsEnabled() ?? false;
    final lastBackup = await _backupRepository?.lastManualExport();
    if (!mounted) return;
    setState(() {
      _settings = settings;
      _exactAvailable = exact;
      _notificationsEnabled = enabled;
      _lastBackup = lastBackup;
    });
  }

  Future<void> _createBackup() async {
    final repository = _backupRepository;
    if (repository == null || _backupBusy) return;
    setState(() => _backupBusy = true);
    try {
      await repository.exportAndShare();
      final last = await repository.lastManualExport();
      if (mounted) setState(() => _lastBackup = last);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не вдалося створити резервну копію')),
        );
      }
    } finally {
      if (mounted) setState(() => _backupBusy = false);
    }
  }

  Future<void> _restoreBackup() async {
    final repository = _backupRepository;
    if (repository == null || _backupBusy) return;
    setState(() => _backupBusy = true);
    try {
      final file = await repository.pickBackup();
      if (file == null) return;
      final validated = await repository.validate(file);
      if (!mounted) return;
      final confirmed = await _showBackupPreview(validated);
      if (confirmed != true || !mounted) return;
      if (await repository.hasActiveSession()) {
        if (!mounted || await _confirmActiveRestore() != true) return;
      }
      await repository.restore(validated);
      if (!mounted) return;
      Navigator.pop(context, true);
    } on BackupValidationException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не вдалося відновити дані')),
        );
      }
    } finally {
      if (mounted) setState(() => _backupBusy = false);
    }
  }

  Future<bool?> _showBackupPreview(ValidatedBackup validated) {
    final p = validated.preview;
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Відновлення резервної копії'),
        content: SingleChildScrollView(
          child: SizedBox(
            width: double.maxFinite,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Файл: ${p.fileName}'),
                Text('Створено: ${p.createdAtUtc.toLocal()}'),
                Text('Версія застосунку: ${p.appVersion}'),
                Text('Версія бази: ${p.databaseSchemaVersion}'),
                Text('Працівників: ${p.firefighters}'),
                Text('Завершених сесій: ${p.completedSessions}'),
                Text('Активна сесія: ${p.hasActiveSession ? 'так' : 'ні'}'),
                Text('Контрольних замірів: ${p.pressureChecks}'),
                Text('Аварій: ${p.emergencies}'),
                Text('Усього записів: ${p.totalRecords}'),
                const SizedBox(height: 12),
                const Text(
                  'Поточні дані застосунку буде замінено даними з резервної копії',
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Скасувати'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Відновити дані'),
          ),
        ],
      ),
    );
  }

  Future<bool?> _confirmActiveRestore() => showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Активна ланка'),
      content: const Text(
        'Зараз триває робота активної ланки. Відновлення резервної копії замінить її дані та скасує поточні нагадування',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Скасувати'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('Продовжити'),
        ),
      ],
    ),
  );

  Future<void> _testNotification() async {
    final gateway = _gateway;
    if (gateway == null) return;
    var enabled = await gateway.notificationsEnabled();
    if (!enabled) {
      final granted = await gateway.requestPermission();
      enabled = granted && await gateway.notificationsEnabled();
      if (mounted) setState(() => _notificationsEnabled = enabled);
    }
    if (!mounted || !enabled) return;
    try {
      await gateway.showNow(
        id: PressureControlReminderService.notificationId(0, 0),
        title: 'Тестове сповіщення GDZS',
        body: 'Системні сповіщення працюють',
        payload: 'pressureControlReminder:0',
        sound: _settings!.sound,
        vibration: _settings!.vibration,
        channel: NotificationChannelKind.pressureControlReminder,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Тестове сповіщення надіслано')),
      );
    } catch (_) {
      // Платформна помилка не повинна показувати хибне повідомлення про успіх.
    }
  }

  Future<void> _update(ExitWarningSettings value) async {
    setState(() => _settings = value);
    await _repository.save(value);
    if (AppServices.isInitialized) {
      await AppServices.synchronizeActiveSession();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Налаштування')),
      body: _settings == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _warningSettings(),
                const SizedBox(height: 12),
                _backupSettings(),
                const SizedBox(height: 12),
                _directoryCard(
                  icon: Icons.business,
                  title: 'Підрозділ',
                  subtitle: 'Назва та основні дані',
                  page: const UnitsPage(),
                ),
                const SizedBox(height: 12),
                _directoryCard(
                  icon: Icons.air,
                  title: 'Апарати',
                  subtitle: 'Типи апаратів та балонів',
                  page: const ApparatusPage(),
                ),
                const SizedBox(height: 12),
                _directoryCard(
                  icon: Icons.groups,
                  title: 'Газодимозахисники',
                  subtitle: 'Особовий склад',
                  page: const FirefightersPage(),
                ),
                const SizedBox(height: 12),
                const Card(
                  child: ListTile(
                    leading: Icon(Icons.info_outline),
                    title: Text('Про застосунок'),
                    trailing: Icon(Icons.chevron_right),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _backupSettings() => Card(
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text(
              'Резервне копіювання',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.backup_outlined),
            title: const Text('Створити резервну копію'),
            subtitle: const Text(
              'Зберегти особовий склад, історію, налаштування та активну ланку',
            ),
            onTap: _backupBusy ? null : _createBackup,
          ),
          ListTile(
            leading: const Icon(Icons.restore),
            title: const Text('Відновити з файла'),
            subtitle: const Text(
              'Замінити поточні дані даними з резервної копії',
            ),
            onTap: _backupBusy ? null : _restoreBackup,
          ),
          if (_backupBusy)
            const Padding(
              padding: EdgeInsets.all(16),
              child: LinearProgressIndicator(),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Text(
              _lastBackup == null
                  ? 'Остання резервна копія: немає'
                  : 'Остання резервна копія: ${_lastBackup!.toLocal()}',
            ),
          ),
        ],
      ),
    ),
  );

  Widget _warningSettings() {
    final settings = _settings!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Text(
                'Попередження про вихід',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            SwitchListTile(
              title: const Text('Системні сповіщення'),
              value: settings.systemNotifications,
              onChanged: (value) =>
                  _update(settings.copyWith(systemNotifications: value)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: _testNotification,
                  icon: const Icon(Icons.notifications_active_outlined),
                  label: const Text('Перевірити сповіщення'),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Text(
                _notificationsEnabled
                    ? 'Системні сповіщення дозволені'
                    : 'Сповіщення заборонені в налаштуваннях Android',
              ),
            ),
            if (!_exactAvailable)
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, 4),
                child: Text(
                  'Точні нагадування недоступні — використовується приблизний час',
                ),
              ),
            SwitchListTile(
              title: const Text('Контроль тиску кожні 10 хвилин'),
              subtitle: const Text(
                'Нагадувати постовому про перевірку зв’язку та фактичного тиску ланки',
              ),
              value: settings.pressureControlReminders,
              onChanged: (value) =>
                  _update(settings.copyWith(pressureControlReminders: value)),
            ),
            SwitchListTile(
              title: const Text('Звук'),
              value: settings.sound,
              onChanged: (value) => _update(settings.copyWith(sound: value)),
            ),
            SwitchListTile(
              title: const Text('Вібрація'),
              value: settings.vibration,
              onChanged: (value) =>
                  _update(settings.copyWith(vibration: value)),
            ),
            SwitchListTile(
              title: const Text('Попередження за 5 хвилин'),
              value: settings.fiveMinutes,
              onChanged: (value) =>
                  _update(settings.copyWith(fiveMinutes: value)),
            ),
            SwitchListTile(
              title: const Text('Попередження за 2 хвилини'),
              value: settings.twoMinutes,
              onChanged: (value) =>
                  _update(settings.copyWith(twoMinutes: value)),
            ),
            SwitchListTile(
              title: const Text('Попередження за 1 хвилину'),
              value: settings.oneMinute,
              onChanged: (value) =>
                  _update(settings.copyWith(oneMinute: value)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _directoryCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget page,
  }) => Card(
    child: ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: () =>
          Navigator.push(context, MaterialPageRoute(builder: (_) => page)),
    ),
  );
}
