import 'package:gdzs_calc/features/team/models/active_team_session.dart';
import 'package:gdzs_calc/shared/models/firefighter.dart';

class TeamReportMember {
  final Firefighter firefighter;
  final bool isLeader;
  final int? startPressure;
  final int? arrivalPressure;
  final int? latestPressure;

  const TeamReportMember({
    required this.firefighter,
    required this.isLeader,
    this.startPressure,
    this.arrivalPressure,
    this.latestPressure,
  });
}

class TeamReportData {
  final ActiveTeamSession session;
  final String unitName;
  final String apparatusName;
  final String watchLabel;
  final List<TeamReportMember> members;

  const TeamReportData._({
    required this.session,
    required this.unitName,
    required this.apparatusName,
    required this.watchLabel,
    required this.members,
  });

  factory TeamReportData.fromSession(ActiveTeamSession session) {
    if (session.stage != ActiveTeamStage.completed) {
      throw StateError('PDF-звіт доступний після завершення роботи ланки');
    }
    final watches = session.participants.map((e) => e.watchNumber).toSet();
    final watchLabel = watches.length == 1 && watches.single != null
        ? '${watches.single}-й караул'
        : 'Змішаний склад';
    return TeamReportData._(
      session: session,
      unitName: session.unitName,
      apparatusName: session.apparatusName,
      watchLabel: watchLabel,
      members: [
        for (final member in session.participants)
          TeamReportMember(
            firefighter: member,
            isLeader: member.id == session.leaderId,
            startPressure: session.startPressuresByFirefighterId[member.id],
            arrivalPressure: session.arrivalPressuresByFirefighterId[member.id],
            latestPressure: session.latestPressuresByFirefighterId[member.id],
          ),
      ],
    );
  }
}
