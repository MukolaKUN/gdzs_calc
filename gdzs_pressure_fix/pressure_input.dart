import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class PressureInput extends StatelessWidget {
  final String firefighterName;
  final bool isLeader;
  final TextEditingController controller;
  final int minValue;
  final int maxValue;
  final ValueChanged<int>? onChanged;

  const PressureInput({
    super.key,
    required this.firefighterName,
    this.isLeader = false,
    required this.controller,
    required this.minValue,
    required this.maxValue,
    this.onChanged,
  });

  void _notifyChanged(String text) {
    final pressure = int.tryParse(text.trim());
    if (pressure != null &&
        pressure >= minValue &&
        pressure <= maxValue) {
      onChanged?.call(pressure);
    }
  }

  void _changeBy(int delta) {
    final currentValue = int.tryParse(controller.text.trim()) ?? minValue;
    final nextValue = (currentValue + delta).clamp(minValue, maxValue);
    final nextText = nextValue.toString();

    controller.value = TextEditingValue(
      text: nextText,
      selection: TextSelection.collapsed(offset: nextText.length),
    );

    onChanged?.call(nextValue);
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              firefighterName,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (isLeader)
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text('Командир ланки'),
              ),
            const SizedBox(height: 8),
            TextFormField(
              controller: controller,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              inputFormatters: const [
                FilteringTextInputFormatter.digitsOnly,
              ],
              decoration: const InputDecoration(
                labelText: 'Тиск',
                suffixText: 'бар',
              ),
              onTap: () {
                controller.selection = TextSelection(
                  baseOffset: 0,
                  extentOffset: controller.text.length,
                );
              },
              onChanged: _notifyChanged,
              onFieldSubmitted: _notifyChanged,
              validator: (value) {
                final pressure = int.tryParse(value?.trim() ?? '');
                if (pressure == null ||
                    pressure < minValue ||
                    pressure > maxValue) {
                  return 'Від $minValue до $maxValue бар';
                }
                return null;
              },
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _PressureButton(
                  label: '-10',
                  onPressed: () => _changeBy(-10),
                ),
                _PressureButton(
                  label: '-1',
                  onPressed: () => _changeBy(-1),
                ),
                _PressureButton(
                  label: '+1',
                  onPressed: () => _changeBy(1),
                ),
                _PressureButton(
                  label: '+10',
                  onPressed: () => _changeBy(10),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PressureButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const _PressureButton({
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      child: Text(label),
    );
  }
}
