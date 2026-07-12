class TeamMember {
  final int? id;

  final int teamId;

  final int firefighterId;

  final int startPressure;

  const TeamMember({
    this.id,
    required this.teamId,
    required this.firefighterId,
    required this.startPressure,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'teamId': teamId,
      'firefighterId': firefighterId,
      'startPressure': startPressure,
    };
  }

  factory TeamMember.fromMap(Map<String, dynamic> map) {
    return TeamMember(
      id: map['id'] as int?,
      teamId: map['teamId'] as int,
      firefighterId: map['firefighterId'] as int,
      startPressure: map['startPressure'] as int,
    );
  }
}