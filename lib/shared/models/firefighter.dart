class Firefighter {
  final int? id;
  final String fullName;
  final String watch;

  const Firefighter({
    this.id,
    required this.fullName,
    required this.watch,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'fullName': fullName,
      'watch': watch,
    };
  }

  factory Firefighter.fromMap(Map<String, dynamic> map) {
    return Firefighter(
      id: map['id'] as int?,
      fullName: map['fullName'] as String,
      watch: map['watch'] as String,
    );
  }

  Firefighter copyWith({
    int? id,
    String? fullName,
    String? watch,
  }) {
    return Firefighter(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      watch: watch ?? this.watch,
    );
  }
}
