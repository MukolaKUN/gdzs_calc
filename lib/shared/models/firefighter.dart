class Firefighter {
  final int? id;
  final String fullName;
  final String watch;

  const Firefighter({this.id, required this.fullName, required this.watch});

  int? get watchNumber {
    final value = int.tryParse(watch.trim());
    return value != null && value >= 1 && value <= 4 ? value : null;
  }

  String get watchLabel => watchNumber == null
      ? 'Без визначеного караулу'
      : '${watchNumber!}-й караул';

  Map<String, dynamic> toMap() {
    return {'id': id, 'fullName': fullName, 'watch': watch};
  }

  factory Firefighter.fromMap(Map<String, dynamic> map) {
    return Firefighter(
      id: map['id'] as int?,
      fullName: map['fullName'] as String,
      watch: map['watch'] as String,
    );
  }

  Firefighter copyWith({int? id, String? fullName, String? watch}) {
    return Firefighter(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      watch: watch ?? this.watch,
    );
  }
}
