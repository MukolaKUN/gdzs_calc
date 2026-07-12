class Unit {
  final int? id;
  final String name;
  final String city;

  const Unit({
    this.id,
    required this.name,
    required this.city,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'city': city,
    };
  }

  factory Unit.fromMap(Map<String, dynamic> map) {
    return Unit(
      id: map['id'] as int?,
      name: map['name'] as String,
      city: map['city'] as String,
    );
  }

  Unit copyWith({
    int? id,
    String? name,
    String? city,
  }) {
    return Unit(
      id: id ?? this.id,
      name: name ?? this.name,
      city: city ?? this.city,
    );
  }
}