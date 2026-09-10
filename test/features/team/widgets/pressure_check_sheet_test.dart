import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gdzs_calc/features/team/widgets/pressure_check_sheet.dart';
import 'package:gdzs_calc/shared/models/firefighter.dart';

void main() {
  const participants = [
    Firefighter(id: 1, fullName: 'Перший', watch: '1'),
    Firefighter(id: 2, fullName: 'Другий', watch: '1'),
  ];

  Widget host(ValueChanged<Map<int, int>?> onResult) {
    return MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: FilledButton(
            onPressed: () async {
              final result = await showModalBottomSheet<Map<int, int>>(
                context: context,
                isScrollControlled: true,
                useSafeArea: true,
                builder: (_) => const PressureCheckSheet(
                  participants: participants,
                  leaderId: 1,
                  maximumPressuresByFirefighterId: {1: 300, 2: 295},
                  estimatedPressuresByFirefighterId: {1: 280, 2: 275},
                ),
              );
              onResult(result);
            },
            child: const Text('Відкрити'),
          ),
        ),
      ),
    );
  }

  testWidgets('returns edited map and can be reopened then closed', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final results = <Map<int, int>?>[];
    await tester.pumpWidget(host(results.add));

    await tester.tap(find.text('Відкрити'));
    await tester.pumpAndSettle();
    final fields = find.byType(TextFormField);
    expect(fields, findsNWidgets(2));
    await tester.enterText(fields.first, '270');
    await tester.enterText(fields.last, '260');
    await tester.ensureVisible(find.text('Підтвердити замір'));
    await tester.pump();
    await tester.tap(find.text('Підтвердити замір'));
    await tester.pumpAndSettle();
    expect(results.single, {1: 270, 2: 260});
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Відкрити'));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(results.last, isNull);
    expect(tester.takeException(), isNull);
  });
}
