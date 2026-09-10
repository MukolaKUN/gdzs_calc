import 'package:flutter/material.dart';
import 'package:gdzs_calc/features/team/models/active_team_session.dart';

class EmergencyFormInput {
  final EmergencyReason reason;
  final bool communicationAvailable;
  final String? note;

  const EmergencyFormInput({
    required this.reason,
    required this.communicationAvailable,
    this.note,
  });
}

class EmergencyFormDialog extends StatefulWidget {
  const EmergencyFormDialog({super.key});

  @override
  State<EmergencyFormDialog> createState() => _EmergencyFormDialogState();
}

class _EmergencyFormDialogState extends State<EmergencyFormDialog> {
  final _noteController = TextEditingController();
  EmergencyReason _reason = EmergencyReason.communicationLost;
  bool _communicationAvailable = false;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Зафіксувати надзвичайну ситуацію'),
    contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
    content: SingleChildScrollView(
      child: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: double.infinity,
              child: DropdownButtonFormField<EmergencyReason>(
                initialValue: _reason,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Причина'),
                selectedItemBuilder: (context) => [
                  for (final reason in EmergencyReason.values)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        reason.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                items: [
                  for (final reason in EmergencyReason.values)
                    DropdownMenuItem(
                      value: reason,
                      child: Text(
                        reason.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: (reason) {
                  if (reason == null) return;
                  setState(() {
                    _reason = reason;
                    if (reason == EmergencyReason.communicationLost) {
                      _communicationAvailable = false;
                    }
                  });
                },
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _noteController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Примітка (необов’язково)',
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Зв’язок із ланкою наявний'),
              value: _communicationAvailable,
              onChanged: (value) =>
                  setState(() => _communicationAvailable = value),
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Скасувати'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(
          context,
          EmergencyFormInput(
            reason: _reason,
            communicationAvailable: _communicationAvailable,
            note: _noteController.text.trim().isEmpty
                ? null
                : _noteController.text.trim(),
          ),
        ),
        child: const Text('Далі'),
      ),
    ],
  );
}
