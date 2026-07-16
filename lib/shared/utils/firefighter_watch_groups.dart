import 'package:gdzs_calc/shared/models/firefighter.dart';

const int unspecifiedWatchValue = 0;

String watchValueLabel(int value) => value == unspecifiedWatchValue
    ? 'Без визначеного караулу'
    : '$value-й караул';

Map<int, List<Firefighter>> groupFirefightersByWatch(
  Iterable<Firefighter> firefighters,
) {
  final groups = <int, List<Firefighter>>{};
  for (final firefighter in firefighters) {
    final watch = firefighter.watchNumber ?? unspecifiedWatchValue;
    groups.putIfAbsent(watch, () => []).add(firefighter);
  }
  for (final members in groups.values) {
    members.sort((first, second) => first.fullName.compareTo(second.fullName));
  }
  final orderedKeys = groups.keys.toList()
    ..sort((first, second) {
      if (first == unspecifiedWatchValue) return 1;
      if (second == unspecifiedWatchValue) return -1;
      return first.compareTo(second);
    });
  return {for (final key in orderedKeys) key: groups[key]!};
}

List<int> availableWatchValues(Iterable<Firefighter> firefighters) {
  return groupFirefightersByWatch(firefighters).keys.toList();
}
