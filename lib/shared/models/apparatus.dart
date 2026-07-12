class Apparatus {
  final int? id;

  final String name;

  final int workingPressure;

  final double cylinderVolume;

  final int cylindersCount;

  final int reservePressure;

  const Apparatus({
    this.id,
    required this.name,
    required this.workingPressure,
    required this.cylinderVolume,
    required this.cylindersCount,
    required this.reservePressure,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'workingPressure': workingPressure,
      'cylinderVolume': cylinderVolume,
      'cylindersCount': cylindersCount,
      'reservePressure': reservePressure,
    };
  }

  factory Apparatus.fromMap(Map<String, dynamic> map) {
    return Apparatus(
      id: map['id'] as int?,
      name: map['name'] as String,
      workingPressure: map['workingPressure'] as int,
      cylinderVolume: (map['cylinderVolume'] as num).toDouble(),
      cylindersCount: map['cylindersCount'] as int,
      reservePressure: map['reservePressure'] as int,
    );
  }

  Apparatus copyWith({
    int? id,
    String? name,
    int? workingPressure,
    double? cylinderVolume,
    int? cylindersCount,
    int? reservePressure,
  }) {
    return Apparatus(
      id: id ?? this.id,
      name: name ?? this.name,
      workingPressure: workingPressure ?? this.workingPressure,
      cylinderVolume: cylinderVolume ?? this.cylinderVolume,
      cylindersCount: cylindersCount ?? this.cylindersCount,
      reservePressure: reservePressure ?? this.reservePressure,
    );
  }
}
