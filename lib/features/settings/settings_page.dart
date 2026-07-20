import 'package:flutter/material.dart';
import 'package:gdzs_calc/app/app_services.dart';
import 'package:gdzs_calc/features/apparatus/apparatus_page.dart';
import 'package:gdzs_calc/features/firefighters/firefighters_page.dart';
import 'package:gdzs_calc/features/units/units_page.dart';
import 'package:gdzs_calc/shared/models/exit_warning_settings.dart';
import 'package:gdzs_calc/shared/repositories/exit_warning_settings_repository.dart';
import 'package:gdzs_calc/shared/services/exit_warning_service.dart';
import 'package:gdzs_calc/shared/services/pressure_control_reminder_service.dart';

class SettingsPage extends StatefulWidget {
  final ExitWarningSettingsRepository? warningSettingsRepository;
  final NotificationGateway? notificationGateway;

  const SettingsPage({
    super.key,
    this.warningSettingsRepository,
    this.notificationGateway,
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

  @override
  void initState() {
    super.initState();
    _repository =
        widget.warningSettingsRepository ??
        const ExitWarningSettingsRepository();
    _gateway =
        widget.notificationGateway ??
        (AppServices.isInitialized ? AppServices.notificationGateway : null);
    _load();
  }

  Future<void> _load() async {
    final settings = await _repository.load();
    final exact = await _gateway?.canScheduleExactAlarms() ?? false;
    final enabled = await _gateway?.notificationsEnabled() ?? false;
    if (!mounted) return;
    setState(() {
      _settings = settings;
      _exactAvailable = exact;
      _notificationsEnabled = enabled;
    });
  }

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
