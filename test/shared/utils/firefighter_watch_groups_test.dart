import 'package:flutter_test/flutter_test.dart';
import 'package:gdzs_calc/shared/models/firefighter.dart';
import 'package:gdzs_calc/shared/utils/firefighter_watch_groups.dart';

void main() {
  test('groups and sorts firefighters by watch and full name', () {
    const firefighters = [
      Firefighter(id: 1, fullName: 'Яременко Яна', watch: '2'),
      Firefighter(id: 2, fullName: 'Андренко Андрій', watch: '2'),
      Firefighter(id: 3, fullName: 'Бондар Богдан', watch: '1'),
      Firefighter(id: 4, fullName: 'Старий запис', watch: ''),
      Firefighter(id: 5, fullName: 'Невідомий караул', watch: 'черговий'),
      Firefighter(id: 6, fullName: 'Четвертий', watch: '4'),
    ];

    final groups = groupFirefightersByWatch(firefighters);

    expect(groups.keys, [1, 2, 4, unspecifiedWatchValue]);
    expect(groups[2]!.map((member) => member.fullName), [
      'Андренко Андрій',
      'Яременко Яна',
    ]);
    expect(groups[unspecifiedWatchValue]!.map((member) => member.fullName), [
      'Невідомий караул',
      'Старий запис',
    ]);
    expect(watchValueLabel(unspecifiedWatchValue), 'Без визначеного караулу');
  });
}
