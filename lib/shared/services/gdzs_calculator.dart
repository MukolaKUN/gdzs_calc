enum WorkLoad { medium, heavy }

extension WorkLoadValues on WorkLoad {
  int get airConsumption {
    switch (this) {
      case WorkLoad.medium:
        return 40;
      case WorkLoad.heavy:
        return 80;
    }
  }
}

class CompressedAirCalculationResult {
  final int minimumStartPressure;
  final double criticalPressure;

  /// Номер газодимозахисника у списку, за яким ведеться розрахунок.
  /// Нумерація в коді починається з 0.
  final int controllingMemberIndex;

  final int controllingArrivalPressure;
  final int travelPressure;
  final int exitPressure;
  final int workingPressure;

  final int travelTimeMinutes;
  final int workingTimeMinutes;
  final DateTime exitTime;

  final bool mustExitImmediately;

  const CompressedAirCalculationResult({
    required this.minimumStartPressure,
    required this.criticalPressure,
    required this.controllingMemberIndex,
    required this.controllingArrivalPressure,
    required this.travelPressure,
    required this.exitPressure,
    required this.workingPressure,
    required this.travelTimeMinutes,
    required this.workingTimeMinutes,
    required this.exitTime,
    required this.mustExitImmediately,
  });
}

class GdzsCalculator {
  GdzsCalculator._();

  static int calculateEstimatedPressureAfterElapsed({
    required int basePressure,
    required Duration elapsed,
    required double cylinderVolume,
    required int cylindersCount,
    required WorkLoad workLoad,
  }) {
    final elapsedSeconds = elapsed.inSeconds < 0 ? 0 : elapsed.inSeconds;
    final elapsedMinutes = elapsedSeconds / 60.0;
    final pressureDrop =
        (elapsedMinutes *
                workLoad.airConsumption /
                (cylindersCount * cylinderVolume))
            .ceil();
    final estimatedPressure = basePressure - pressureDrop;

    return estimatedPressure.clamp(0, basePressure).toInt();
  }

  static int calculateRemainingWorkTimeMinutes({
    required int currentPressure,
    required int exitPressure,
    required double cylinderVolume,
    required int cylindersCount,
    required WorkLoad workLoad,
  }) {
    if (currentPressure <= exitPressure) return 0;

    final availablePressure = currentPressure - exitPressure;
    final remainingMinutes =
        cylindersCount *
        cylinderVolume *
        availablePressure /
        workLoad.airConsumption;
    final roundedMinutes = remainingMinutes.floor();

    return roundedMinutes < 0 ? 0 : roundedMinutes;
  }

  /// Розраховує прогнозний тиск після прямування до місця роботи.
  ///
  /// Це орієнтовне значення для контролю постовим. Остаточний розрахунок
  /// безпечних параметрів виконується за фактичним тиском, який доповів
  /// командир ланки після прибуття до місця роботи.
  static int calculateEstimatedArrivalPressure({
    required int startPressure,
    required int travelTimeMinutes,
    required double cylinderVolume,
    required int cylindersCount,
    required WorkLoad workLoad,
  }) {
    if (startPressure < 0) {
      throw ArgumentError('Початковий тиск не може бути від’ємним.');
    }

    if (travelTimeMinutes < 0) {
      throw ArgumentError('Час прямування не може бути від’ємним.');
    }

    if (cylinderVolume <= 0) {
      throw ArgumentError('Об’єм балона повинен бути більшим за нуль.');
    }

    if (cylindersCount <= 0) {
      throw ArgumentError('Кількість балонів повинна бути більшою за нуль.');
    }

    final exactPressureDrop =
        travelTimeMinutes *
        workLoad.airConsumption /
        (cylindersCount * cylinderVolume);

    // Для прогнозу використовуємо безпечне округлення витрати в більшу сторону.
    final pressureDrop = exactPressureDrop.ceil();
    final estimatedPressure = startPressure - pressureDrop;

    return estimatedPressure.clamp(0, startPressure).toInt();
  }

  static CompressedAirCalculationResult calculateCompressedAir({
    required List<int> startPressures,
    required List<int> arrivalPressures,
    required DateTime inclusionTime,
    required DateTime arrivalTime,
    required double cylinderVolume,
    required int cylindersCount,
    required int reservePressure,
    required WorkLoad workLoad,
  }) {
    _validateInput(
      startPressures: startPressures,
      arrivalPressures: arrivalPressures,
      inclusionTime: inclusionTime,
      arrivalTime: arrivalTime,
      cylinderVolume: cylinderVolume,
      cylindersCount: cylindersCount,
      reservePressure: reservePressure,
    );

    final minimumStartPressure = _findMinimum(startPressures);

    // Pкр = (Pвкл мінімальний - Pрез) / 2
    final criticalPressure = (minimumStartPressure - reservePressure) / 2;

    // Визначаємо газодимозахисника з найбільшою витратою
    // повітря під час прямування.
    int controllingMemberIndex = 0;
    int maximumTravelPressure = startPressures.first - arrivalPressures.first;

    for (int index = 1; index < startPressures.length; index++) {
      final travelPressure = startPressures[index] - arrivalPressures[index];

      final hasGreaterTravelConsumption =
          travelPressure > maximumTravelPressure;

      final hasSameConsumptionButLowerArrivalPressure =
          travelPressure == maximumTravelPressure &&
          arrivalPressures[index] < arrivalPressures[controllingMemberIndex];

      if (hasGreaterTravelConsumption ||
          hasSameConsumptionButLowerArrivalPressure) {
        controllingMemberIndex = index;
        maximumTravelPressure = travelPressure;
      }
    }

    final controllingArrivalPressure = arrivalPressures[controllingMemberIndex];

    // Pвих = Pпр + Pрез
    final exitPressure = maximumTravelPressure + reservePressure;

    // Pроб = Pпоч.роб - Pвих
    final rawWorkingPressure = controllingArrivalPressure - exitPressure;

    final workingPressure = rawWorkingPressure > 0 ? rawWorkingPressure : 0;

    // τроб = Nбал × Vбал × Pроб / Qвитр
    final exactWorkingTime =
        cylindersCount *
        cylinderVolume *
        workingPressure /
        workLoad.airConsumption;

    // У прикладах методики дробова частина хвилини відкидається.
    final workingTimeMinutes = exactWorkingTime.floor();

    final travelTimeMinutes = arrivalTime.difference(inclusionTime).inMinutes;

    // Tвих = Tвкл + τпр + τроб
    final exitTime = inclusionTime.add(
      Duration(minutes: travelTimeMinutes + workingTimeMinutes),
    );

    return CompressedAirCalculationResult(
      minimumStartPressure: minimumStartPressure,
      criticalPressure: criticalPressure,
      controllingMemberIndex: controllingMemberIndex,
      controllingArrivalPressure: controllingArrivalPressure,
      travelPressure: maximumTravelPressure,
      exitPressure: exitPressure,
      workingPressure: workingPressure,
      travelTimeMinutes: travelTimeMinutes,
      workingTimeMinutes: workingTimeMinutes,
      exitTime: exitTime,
      mustExitImmediately: controllingArrivalPressure <= exitPressure,
    );
  }

  static int _findMinimum(List<int> values) {
    int minimum = values.first;

    for (final value in values.skip(1)) {
      if (value < minimum) {
        minimum = value;
      }
    }

    return minimum;
  }

  static void _validateInput({
    required List<int> startPressures,
    required List<int> arrivalPressures,
    required DateTime inclusionTime,
    required DateTime arrivalTime,
    required double cylinderVolume,
    required int cylindersCount,
    required int reservePressure,
  }) {
    if (startPressures.length != arrivalPressures.length) {
      throw ArgumentError(
        'Кількість початкових і контрольних тисків не збігається.',
      );
    }

    if (startPressures.length < 2 || startPressures.length > 5) {
      throw ArgumentError('Ланка повинна складатися з 2–5 газодимозахисників.');
    }

    if (cylinderVolume <= 0) {
      throw ArgumentError('Об’єм балона повинен бути більшим за нуль.');
    }

    if (cylindersCount <= 0) {
      throw ArgumentError('Кількість балонів повинна бути більшою за нуль.');
    }

    if (reservePressure < 0) {
      throw ArgumentError('Резервний тиск не може бути від’ємним.');
    }

    if (arrivalTime.isBefore(inclusionTime)) {
      throw ArgumentError('Час прибуття не може бути раніше часу включення.');
    }

    for (int index = 0; index < startPressures.length; index++) {
      final startPressure = startPressures[index];
      final arrivalPressure = arrivalPressures[index];

      if (startPressure <= 0 || arrivalPressure < 0) {
        throw ArgumentError('Значення тиску повинні бути коректними.');
      }

      if (arrivalPressure > startPressure) {
        throw ArgumentError(
          'Тиск після прямування не може бути більшим '
          'за початковий тиск.',
        );
      }
    }
  }
}
