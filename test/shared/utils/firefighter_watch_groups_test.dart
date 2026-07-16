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

  test('filters by watch and full name without changing source records', () {
    const firefighters = [
      Firefighter(id: 1, fullName: 'Іваненко Іван', watch: '2'),
      Firefighter(id: 2, fullName: 'Андренко Андрій', watch: '1'),
      Firefighter(id: 3, fullName: 'Без караулу', watch: ''),
    ];

    expect(
      filterFirefighters(
        firefighters: firefighters,
        watch: allWatchesValue,
      ).map((member) => member.id),
      [2, 1, 3],
    );
    expect(
      filterFirefighters(
        firefighters: firefighters,
        watch: 2,
        query: 'ІВАН',
      ).map((member) => member.id),
      [1],
    );
    expect(firefighters.first.watch, '2');
  });

  test('describes same-watch and mixed teams from participant snapshots', () {
    expect(
      teamWatchLabel(const [
        Firefighter(id: 1, fullName: 'А', watch: '1'),
        Firefighter(id: 2, fullName: 'Б', watch: '1'),
      ]),
      '1-й караул',
    );
    expect(
      teamWatchLabel(const [
        Firefighter(id: 1, fullName: 'А', watch: '1'),
        Firefighter(id: 2, fullName: 'Б', watch: '3'),
      ]),
      'Змішаний склад',
    );
  });
}
