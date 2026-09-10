import 'package:flutter/foundation.dart';
import 'package:gdzs_calc/features/team/repositories/team_session_repository.dart';

/// Shared, refreshable state of the currently active team session.
class ActiveTeamSessionProvider extends ChangeNotifier {
  ActiveTeamSessionProvider(this.repository);

  final TeamSessionRepository repository;
  TeamSessionRecord? _active;
  bool _isLoading = false;
  Object? _error;

  TeamSessionRecord? get active => _active;
  bool get isLoading => _isLoading;
  Object? get error => _error;

  Future<void> load() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _active = await repository.getActiveSession();
    } catch (error) {
      _error = error;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refresh() => load();
}
