import 'package:flutter/material.dart';
import 'package:gdzs_calc/features/team/models/active_team_session.dart';
import 'package:gdzs_calc/features/team/widgets/pressure_input.dart';
import 'package:gdzs_calc/shared/services/gdzs_calculator.dart';

class PressureCheckSheet extends StatefulWidget {
  final ActiveTeamSession session;
  final DateTime openedAt;

  const PressureCheckSheet({
    super.key,
    required this.session,
    required this.openedAt,
  });

  @override
  State<PressureCheckSheet> createState() => _PressureCheckSheetState();
}

class _PressureCheckSheetState extends State<PressureCheckSheet> {
  final _formKey = GlobalKey<FormState>();
  final Map<int, TextEditingController> _controllers = {};
  bool _isSubmitting = false;

  final Map<int, int> _maximumPressures = {};
  late final bool _isFirstCheck;

  @override
  void initState() {
    super.initState();

    final session = widget.session;
    final latestCheck = session.latestPressureCheck;
    _isFirstCheck = latestCheck == null;
    final referenceTime = latestCheck?.checkedAt ?? session.arrivalTime;
    final referencePressures = session.latestPressuresByFirefighterId;
    final elapsedMinutes = widget.openedAt
        .difference(referenceTime)
        .inMinutes
        .clamp(0, 1440)
        .toInt();

    for (final participant in session.participants) {
      final id = participant.id;
      if (id == null) continue;

      final referencePressure = referencePressures[id] ?? 0;
      final estimatedPressure =
          GdzsCalculator.calculateEstimatedArrivalPressure(
            startPressure: referencePressure,
            travelTimeMinutes: elapsedMinutes,
            cylinderVolume: session.cylinderVolume,
            cylindersCount: session.cylindersCount,
            workLoad: session.workLoad,
          );
      _maximumPressures[id] = referencePressure;
      _controllers[id] = TextEditingController(
        text: estimatedPressure.toString(),
      );
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _submit() {
    if (_isSubmitting) return;
    if (!_formKey.currentState!.validate()) return;

    final result = <int, int>{
      for (final entry in _controllers.entries)
        entry.key: int.parse(entry.value.text.trim()),
    };
    FocusScope.of(context).unfocus();
    _isSubmitting = true;
    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Контроль тиску',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                _isFirstCheck
                    ? 'Прогноз від тиску після прибуття'
                    : 'Прогноз від останнього контрольного заміру',
              ),
              const SizedBox(height: 12),
              ...widget.session.participants.map((participant) {
                final id = participant.id;
                final controller = id == null ? null : _controllers[id];
                if (id == null || controller == null) {
                  return const SizedBox.shrink();
                }

                return PressureInput(
                  key: ValueKey('pressure-check-$id'),
                  firefighterName: participant.fullName,
                  isLeader: id == widget.session.leaderId,
                  controller: controller,
                  minValue: 0,
                  maxValue: _maximumPressures[id]!,
                  helperText: 'Звірте прогноз із фактичною доповіддю',
                );
              }),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _isSubmitting ? null : _submit,
                child: const Text('Підтвердити замір'),
              ),
              TextButton(
                onPressed: _isSubmitting
                    ? null
                    : () => Navigator.of(context).pop(),
                child: const Text('Скасувати'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
