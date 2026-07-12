import 'package:flutter_test/flutter_test.dart';
import 'package:gdzs_calc/shared/services/gdzs_calculator.dart';

void main() {
  group('GdzsCalculator — стиснене повітря', () {
    test(
      'правильно рахує приклад із методичних рекомендацій №680',
      () {
        final result =
            GdzsCalculator.calculateCompressedAir(
          startPressures: const [300, 295, 290],
          arrivalPressures: const [265, 260, 250],
          inclusionTime: DateTime(2026, 7, 12, 19, 20),
          arrivalTime: DateTime(2026, 7, 12, 19, 26),
          cylinderVolume: 6,
          cylindersCount: 1,
          reservePressure: 50,
          workLoad: WorkLoad.medium,
        );

        expect(result.minimumStartPressure, 290);
        expect(result.criticalPressure, 120);

        // Третій газодимозахисник, індекс 2.
        expect(result.controllingMemberIndex, 2);

        expect(result.controllingArrivalPressure, 250);
        expect(result.travelPressure, 40);
        expect(result.exitPressure, 90);
        expect(result.workingPressure, 160);

        expect(result.travelTimeMinutes, 6);
        expect(result.workingTimeMinutes, 24);

        expect(
          result.exitTime,
          DateTime(2026, 7, 12, 19, 50),
        );

        expect(result.mustExitImmediately, false);
      },
    );

    test('для важкого навантаження час роботи удвічі менший', () {
      final result =
          GdzsCalculator.calculateCompressedAir(
        startPressures: const [300, 295, 290],
        arrivalPressures: const [265, 260, 250],
        inclusionTime: DateTime(2026, 7, 12, 19, 20),
        arrivalTime: DateTime(2026, 7, 12, 19, 26),
        cylinderVolume: 6,
        cylindersCount: 1,
        reservePressure: 50,
        workLoad: WorkLoad.heavy,
      );

      expect(result.workingTimeMinutes, 12);
      expect(
        result.exitTime,
        DateTime(2026, 7, 12, 19, 38),
      );
    });
  });
}