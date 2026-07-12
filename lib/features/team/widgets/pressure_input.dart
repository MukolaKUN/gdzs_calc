import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class PressureInput extends StatelessWidget {
  final String firefighterName;
  final bool isLeader;
  final TextEditingController controller;
  final int minValue;
  final int maxValue;
  final String? helperText;
  final String? statusText;
  final VoidCallback? onEdited;
  final ValueChanged<int>? onChanged;

  const PressureInput({
    super.key,
    required this.firefighterName,
    this.isLeader = false,
    required this.controller,
    required this.minValue,
    required this.maxValue,
    this.helperText,
    this.statusText,
    this.onEdited,
    this.onChanged,
  });

  void _notifyChanged(String text) {
    onEdited?.call();

    final pressure = int.tryParse(text.trim());
    if (pressure != null && pressure >= minValue && pressure <= maxValue) {
      onChanged?.call(pressure);
    }
  }

  void _changeBy(int delta) {
    final currentValue = int.tryParse(controller.text.trim()) ?? maxValue;
    final nextValue = (currentValue + delta).clamp(minValue, maxValue);
    final nextText = nextValue.toString();

    controller.value = TextEditingValue(
      text: nextText,
      selection: TextSelection.collapsed(offset: nextText.length),
    );

    onEdited?.call();
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
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: 'Тиск',
                suffixText: 'бар',
                helperText: helperText,
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
                final text = value?.trim() ?? '';
                if (text.isEmpty) {
                  return 'Введіть фактичний тиск';
                }

                final pressure = int.tryParse(text);
                if (pressure == null ||
                    pressure < minValue ||
                    pressure > maxValue) {
                  return 'Тиск має бути від $minValue до $maxValue бар';
                }
                return null;
              },
            ),
            if (statusText != null) ...[
              const SizedBox(height: 8),
              Text(statusText!),
            ],
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _PressureButton(label: '-10', onPressed: () => _changeBy(-10)),
                _PressureButton(label: '-1', onPressed: () => _changeBy(-1)),
                _PressureButton(label: '+1', onPressed: () => _changeBy(1)),
                _PressureButton(label: '+10', onPressed: () => _changeBy(10)),
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

  const _PressureButton({required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(onPressed: onPressed, child: Text(label));
  }
}
