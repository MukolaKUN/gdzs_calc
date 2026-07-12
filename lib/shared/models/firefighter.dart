class Firefighter {
  final int? id;
  final String fullName;

  const Firefighter({
    this.id,
    required this.fullName,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'fullName': fullName,
    };
  }

  factory Firefighter.fromMap(Map<String, dynamic> map) {
    return Firefighter(
      id: map['id'] as int?,
      fullName: map['fullName'] as String,
    );
  }

  Firefighter copyWith({
    int? id,
    String? fullName,
  }) {
    return Firefighter(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
    );
  }
}