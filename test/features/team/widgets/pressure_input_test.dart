import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gdzs_calc/features/team/widgets/pressure_input.dart';

void main() {
  Widget buildSubject({
    required TextEditingController controller,
    required ValueChanged<int> onChanged,
    GlobalKey<FormState>? formKey,
    int maxValue = 300,
    String? helperText,
    String? statusText,
    VoidCallback? onEdited,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: Form(
          key: formKey,
          child: PressureInput(
            firefighterName: 'Тестовий ГДЗС',
            controller: controller,
            minValue: 0,
            maxValue: maxValue,
            helperText: helperText,
            statusText: statusText,
            onEdited: onEdited,
            onChanged: onChanged,
          ),
        ),
      ),
    );
  }

  testWidgets('reports manual and button pressure changes to its parent', (
    tester,
  ) async {
    final changedValues = <int>[];
    final controller = TextEditingController(text: '300');
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      buildSubject(controller: controller, onChanged: changedValues.add),
    );
    expect(controller.text, '300');

    await tester.enterText(find.byType(TextFormField), '265');
    expect(controller.text, '265');
    expect(changedValues.last, 265);

    await tester.tap(find.text('-10'));
    await tester.pump();
    expect(controller.text, '255');
    expect(changedValues.last, 255);
  });

  testWidgets('reports only user edits through onEdited', (tester) async {
    var editCount = 0;
    final controller = TextEditingController(text: '260');
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      buildSubject(
        controller: controller,
        onChanged: (_) {},
        onEdited: () => editCount += 1,
        statusText: 'Збігається з розрахунковим',
      ),
    );

    controller.text = '250';
    await tester.pump();
    expect(editCount, 0);
    expect(find.text('Збігається з розрахунковим'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField), '255');
    expect(editCount, 1);

    await tester.tap(find.text('-10'));
    await tester.pump();
    expect(editCount, 2);
  });

  testWidgets('requires arrival pressure and starts buttons from max value', (
    tester,
  ) async {
    final formKey = GlobalKey<FormState>();
    final changedValues = <int>[];
    final controller = TextEditingController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      buildSubject(
        controller: controller,
        onChanged: changedValues.add,
        formKey: formKey,
        helperText: 'Початковий тиск: 300 бар',
      ),
    );

    expect(controller.text, isEmpty);
    expect(formKey.currentState!.validate(), isFalse);
    await tester.pump();
    expect(find.text('Введіть фактичний тиск'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField), '265');
    expect(controller.text, '265');
    expect(changedValues.last, 265);
    expect(formKey.currentState!.validate(), isTrue);

    controller.clear();
    await tester.tap(find.text('-10'));
    await tester.pump();
    expect(controller.text, '290');
    expect(changedValues.last, 290);
  });

  test('controller texts form distinct start and arrival pressure lists', () {
    final startControllers = {
      1: TextEditingController(text: '300'),
      2: TextEditingController(text: '290'),
      3: TextEditingController(text: '295'),
    };
    final arrivalControllers = {
      1: TextEditingController(text: '265'),
      2: TextEditingController(text: '250'),
      3: TextEditingController(text: '260'),
    };
    addTearDown(() {
      for (final controller in [
        ...startControllers.values,
        ...arrivalControllers.values,
      ]) {
        controller.dispose();
      }
    });

    final ids = [1, 2, 3];
    final startPressures = ids
        .map((id) => int.parse(startControllers[id]!.text))
        .toList();
    final arrivalPressures = ids
        .map((id) => int.parse(arrivalControllers[id]!.text))
        .toList();

    expect(startPressures, [300, 290, 295]);
    expect(arrivalPressures, [265, 250, 260]);
  });
}
