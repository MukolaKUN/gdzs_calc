import 'package:flutter/material.dart';
import 'package:gdzs_calc/features/team/widgets/pressure_input.dart';
import 'package:gdzs_calc/shared/models/firefighter.dart';

class PressureCheckSheet extends StatefulWidget {
  final List<Firefighter> participants;
  final int leaderId;
  final Map<int, int> maximumPressuresByFirefighterId;
  final Map<int, int> estimatedPressuresByFirefighterId;

  const PressureCheckSheet({
    super.key,
    required this.participants,
    required this.leaderId,
    required this.maximumPressuresByFirefighterId,
    required this.estimatedPressuresByFirefighterId,
  });

  @override
  State<PressureCheckSheet> createState() => _PressureCheckSheetState();
}

class _PressureCheckSheetState extends State<PressureCheckSheet> {
  final _formKey = GlobalKey<FormState>();
  final Map<int, TextEditingController> _controllers = {};
  bool _isSubmitting = false;

  final Map<int, int> _maximumPressures = {};

  @override
  void initState() {
    super.initState();

    for (final participant in widget.participants) {
      final id = participant.id;
      if (id == null) continue;

      final referencePressure = widget.maximumPressuresByFirefighterId[id] ?? 0;
      final estimatedPressure =
          widget.estimatedPressuresByFirefighterId[id] ?? referencePressure;
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

  String _statusText(int id, int estimatedPressure) {
    final actualPressure = int.tryParse(_controllers[id]!.text.trim());
    if (actualPressure == null) return '';

    final deviation = actualPressure - estimatedPressure;
    if (deviation == 0) return 'Збігається з розрахунковим';
    if (deviation < 0) {
      return 'Витрата вища за розрахункову: $deviation бар';
    }
    return 'Запас відносно розрахункового: +$deviation бар';
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
              const Text('Звірте прогноз із фактичною доповіддю'),
              const SizedBox(height: 12),
              ...widget.participants.map((participant) {
                final id = participant.id;
                final controller = id == null ? null : _controllers[id];
                if (id == null || controller == null) {
                  return const SizedBox.shrink();
                }
                final estimatedPressure =
                    widget.estimatedPressuresByFirefighterId[id] ??
                    _maximumPressures[id]!;

                return PressureInput(
                  key: ValueKey('pressure-check-$id'),
                  firefighterName: participant.fullName,
                  isLeader: id == widget.leaderId,
                  controller: controller,
                  minValue: 0,
                  maxValue: _maximumPressures[id]!,
                  helperText: 'Розрахунковий тиск: $estimatedPressure бар',
                  statusText: _statusText(id, estimatedPressure),
                  onEdited: () {
                    setState(() {});
                  },
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
