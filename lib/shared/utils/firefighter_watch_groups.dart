import 'package:gdzs_calc/shared/models/firefighter.dart';

const int unspecifiedWatchValue = 0;
const int allWatchesValue = -1;

String watchValueLabel(int value) => switch (value) {
  allWatchesValue => 'Усі караули',
  unspecifiedWatchValue => 'Без визначеного караулу',
  _ => '$value-й караул',
};

List<Firefighter> filterFirefighters({
  required Iterable<Firefighter> firefighters,
  required int watch,
  String query = '',
}) {
  final normalizedQuery = query.trim().toLowerCase();
  final result = firefighters.where((firefighter) {
    final matchesWatch =
        watch == allWatchesValue ||
        (firefighter.watchNumber ?? unspecifiedWatchValue) == watch;
    final matchesQuery =
        normalizedQuery.isEmpty ||
        firefighter.fullName.toLowerCase().contains(normalizedQuery);
    return matchesWatch && matchesQuery;
  }).toList();
  result.sort((first, second) {
    final firstWatch = first.watchNumber ?? 5;
    final secondWatch = second.watchNumber ?? 5;
    final byWatch = firstWatch.compareTo(secondWatch);
    return byWatch != 0 ? byWatch : first.fullName.compareTo(second.fullName);
  });
  return result;
}

String teamWatchLabel(Iterable<Firefighter> firefighters) {
  final watches = firefighters.map((member) => member.watchNumber).toSet();
  if (watches.length > 1) return 'Змішаний склад';
  final watch = watches.firstOrNull;
  return watch == null ? 'Без визначеного караулу' : '$watch-й караул';
}

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
