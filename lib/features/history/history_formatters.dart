import 'package:gdzs_calc/shared/services/gdzs_calculator.dart';

String historyDate(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}.'
    '${value.month.toString().padLeft(2, '0')}.${value.year}';

String historyTime(DateTime value, {bool seconds = false}) =>
    '${value.hour.toString().padLeft(2, '0')}:'
    '${value.minute.toString().padLeft(2, '0')}'
    '${seconds ? ':${value.second.toString().padLeft(2, '0')}' : ''}';

String historyDateTime(DateTime? value) => value == null
    ? 'Не зафіксовано'
    : '${historyDate(value)} ${historyTime(value, seconds: true)}';

String historyDuration(Duration? value) {
  if (value == null) return 'Не зафіксовано';
  final duration = value.isNegative ? Duration.zero : value;
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  return hours == 0 ? '$minutes хв' : '$hours год $minutes хв';
}

String workLoadLabel(WorkLoad value) => switch (value) {
  WorkLoad.medium => 'Середнє навантаження',
  WorkLoad.heavy => 'Важке навантаження',
};

String pressureDeviation(int estimated, int actual) {
  final difference = actual - estimated;
  if (difference == 0) return 'Збігається';
  return difference < 0
      ? 'Вища витрата: $difference бар'
      : 'Запас: +$difference бар';
}
