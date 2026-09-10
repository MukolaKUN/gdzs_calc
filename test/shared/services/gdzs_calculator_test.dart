import 'package:flutter_test/flutter_test.dart';
import 'package:gdzs_calc/shared/services/gdzs_calculator.dart';

void main() {
  group('GdzsCalculator — стиснене повітря', () {
    test('прогнозує тиск за фактично минулим часом', () {
      int calculate(int basePressure, Duration elapsed) {
        return GdzsCalculator.calculateEstimatedPressureAfterElapsed(
          basePressure: basePressure,
          elapsed: elapsed,
          cylinderVolume: 6,
          cylindersCount: 1,
          workLoad: WorkLoad.medium,
        );
      }

      expect(calculate(250, const Duration(minutes: 10)), 183);
      expect(calculate(250, Duration.zero), 250);
      expect(calculate(180, const Duration(minutes: 5)), 146);
      expect(calculate(100, const Duration(hours: 1)), 0);
    });

    test('перераховує залишок роботи за поточним тиском', () {
      int calculate(int currentPressure) {
        return GdzsCalculator.calculateRemainingWorkTimeMinutes(
          currentPressure: currentPressure,
          exitPressure: 90,
          cylinderVolume: 6,
          cylindersCount: 1,
          workLoad: WorkLoad.medium,
        );
      }

      expect(calculate(250), 24);
      expect(calculate(230), 21);
      expect(calculate(200), 16);
      expect(calculate(90), 0);
      expect(calculate(80), 0);
    });

    test('перераховує залишок роботи для важкого навантаження', () {
      expect(
        GdzsCalculator.calculateRemainingWorkTimeMinutes(
          currentPressure: 230,
          exitPressure: 90,
          cylinderVolume: 6,
          cylindersCount: 1,
          workLoad: WorkLoad.heavy,
        ),
        10,
      );
    });

    test('правильно рахує приклад із методичних рекомендацій №680', () {
      final result = GdzsCalculator.calculateCompressedAir(
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

      expect(result.exitTime, DateTime(2026, 7, 12, 19, 50));

      expect(result.mustExitImmediately, false);
    });

    test('для важкого навантаження час роботи удвічі менший', () {
      final result = GdzsCalculator.calculateCompressedAir(
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
      expect(result.exitTime, DateTime(2026, 7, 12, 19, 38));
    });

    test('прогнозує тиск після прямування для середнього навантаження', () {
      expect(
        GdzsCalculator.calculateEstimatedArrivalPressure(
          startPressure: 300,
          travelTimeMinutes: 6,
          cylinderVolume: 6,
          cylindersCount: 1,
          workLoad: WorkLoad.medium,
        ),
        260,
      );

      expect(
        GdzsCalculator.calculateEstimatedArrivalPressure(
          startPressure: 295,
          travelTimeMinutes: 6,
          cylinderVolume: 6,
          cylindersCount: 1,
          workLoad: WorkLoad.medium,
        ),
        255,
      );

      expect(
        GdzsCalculator.calculateEstimatedArrivalPressure(
          startPressure: 290,
          travelTimeMinutes: 6,
          cylinderVolume: 6,
          cylindersCount: 1,
          workLoad: WorkLoad.medium,
        ),
        250,
      );
    });

    test('прогнозує тиск після прямування для важкого навантаження', () {
      expect(
        GdzsCalculator.calculateEstimatedArrivalPressure(
          startPressure: 300,
          travelTimeMinutes: 6,
          cylinderVolume: 6,
          cylindersCount: 1,
          workLoad: WorkLoad.heavy,
        ),
        220,
      );
    });
  });
}
