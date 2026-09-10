class Team {
  final int? id;

  final int unitId;

  final int apparatusId;

  final DateTime createdAt;

  const Team({
    this.id,
    required this.unitId,
    required this.apparatusId,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'unitId': unitId,
      'apparatusId': apparatusId,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory Team.fromMap(Map<String, dynamic> map) {
    return Team(
      id: map['id'] as int?,
      unitId: map['unitId'] as int,
      apparatusId: map['apparatusId'] as int,
      createdAt: DateTime.parse(map['createdAt'] as String),
    );
  }
}
