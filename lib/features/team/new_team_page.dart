import 'package:flutter/material.dart';
import 'package:gdzs_calc/features/apparatus/apparatus_page.dart';
import 'package:gdzs_calc/features/firefighters/firefighters_page.dart';
import 'package:gdzs_calc/features/team/active_team_page.dart';
import 'package:gdzs_calc/features/team/models/active_team_session.dart';
import 'package:gdzs_calc/features/team/repositories/team_session_repository.dart';
import 'package:gdzs_calc/features/team/widgets/pressure_input.dart';
import 'package:gdzs_calc/features/units/units_page.dart';
import 'package:gdzs_calc/shared/models/apparatus.dart';
import 'package:gdzs_calc/shared/models/firefighter.dart';
import 'package:gdzs_calc/shared/models/unit.dart';
import 'package:gdzs_calc/shared/repositories/apparatus_repository.dart';
import 'package:gdzs_calc/shared/repositories/firefighter_repository.dart';
import 'package:gdzs_calc/shared/repositories/unit_repository.dart';
import 'package:gdzs_calc/shared/services/gdzs_calculator.dart';
import 'package:gdzs_calc/shared/widgets/app_button.dart';
import 'package:gdzs_calc/shared/utils/firefighter_watch_groups.dart';

class NewTeamPage extends StatefulWidget {
  final List<Unit>? initialUnits;
  final List<Apparatus>? initialApparatus;
  final List<Firefighter>? initialFirefighters;
  final Future<List<Firefighter>> Function()? firefightersLoader;
  final WidgetBuilder? firefightersDirectoryBuilder;
  final TeamSessionRepository? teamSessionRepository;

  const NewTeamPage({
    super.key,
    this.initialUnits,
    this.initialApparatus,
    this.initialFirefighters,
    this.firefightersLoader,
    this.firefightersDirectoryBuilder,
    this.teamSessionRepository,
  });

  @override
  State<NewTeamPage> createState() => _NewTeamPageState();
}

class _NewTeamPageState extends State<NewTeamPage> {
  final _unitRepository = UnitRepository();
  final _apparatusRepository = ApparatusRepository();
  final _firefighterRepository = FirefighterRepository();
  final _pressureFormKey = GlobalKey<FormState>();
  final Map<int, TextEditingController> _pressureControllers = {};

  List<Unit> _units = [];
  List<Apparatus> _apparatus = [];
  List<Firefighter> _firefighters = [];
  Unit? _selectedUnit;
  Apparatus? _selectedApparatus;
  final List<int> _selectedIds = [];
  int? _selectedWatch;
  int? _leaderId;
  int _watchFieldRevision = 0;
  WorkLoad _workLoad = WorkLoad.medium;
  int _step = 0;
  bool _loading = true;
  String? _error;
  bool _isSaving = false;
  late final TeamSessionRepository _teamSessionRepository;

  List<Firefighter> get _selectedFirefighters => [
    for (final id in _selectedIds)
      _firefighters.firstWhere((member) => member.id == id),
  ];

  List<int> get _watchOptions => availableWatchValues(_firefighters);

  List<Firefighter> get _visibleFirefighters {
    final watch = _selectedWatch;
    if (watch == null) return const [];
    final groups = groupFirefightersByWatch(_firefighters);
    return groups[watch] ?? const [];
  }

  bool get _compositionValid =>
      _selectedUnit != null &&
      _selectedApparatus != null &&
      _selectedIds.length >= 2 &&
      _selectedIds.length <= 5 &&
      _leaderId != null;

  @override
  void initState() {
    super.initState();
    _teamSessionRepository =
        widget.teamSessionRepository ?? const TeamSessionRepository();
    if (widget.initialUnits != null &&
        widget.initialApparatus != null &&
        widget.initialFirefighters != null) {
      _units = widget.initialUnits!;
      _apparatus = widget.initialApparatus!;
      _firefighters = widget.initialFirefighters!;
      _loading = false;
    } else {
      _loadData();
    }
  }

  @override
  void dispose() {
    for (final controller in _pressureControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final values = await Future.wait([
        widget.initialUnits == null
            ? _unitRepository.getAll()
            : Future.value(widget.initialUnits!),
        widget.initialApparatus == null
            ? _apparatusRepository.getAll()
            : Future.value(widget.initialApparatus!),
        widget.firefightersLoader?.call() ??
            (widget.initialFirefighters == null
                ? _firefighterRepository.getAll()
                : Future.value(widget.initialFirefighters!)),
      ]);
      if (!mounted) return;
      setState(() {
        _units = values[0] as List<Unit>;
        _apparatus = values[1] as List<Apparatus>;
        _firefighters = values[2] as List<Firefighter>;
        final availableIds = _firefighters
            .where((member) => member.id != null)
            .map((member) => member.id!)
            .toSet();
        final removedIds = _selectedIds
            .where((id) => !availableIds.contains(id))
            .toList();
        for (final id in removedIds) {
          _selectedIds.remove(id);
          _pressureControllers.remove(id)?.dispose();
        }
        if (_selectedWatch != null && _watchOptions.contains(_selectedWatch)) {
          final visibleIds = _visibleFirefighters
              .where((member) => member.id != null)
              .map((member) => member.id!)
              .toSet();
          final hiddenIds = _selectedIds
              .where((id) => !visibleIds.contains(id))
              .toList();
          for (final id in hiddenIds) {
            _selectedIds.remove(id);
            _pressureControllers.remove(id)?.dispose();
          }
        }
        if (_leaderId != null && !_selectedIds.contains(_leaderId)) {
          _leaderId = null;
        }
        if (_selectedWatch != null && !_watchOptions.contains(_selectedWatch)) {
          _clearCompositionSelection();
          _selectedWatch = null;
        }
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Не вдалося завантажити довідники. Спробуйте ще раз.';
      });
    }
  }

  Future<void> _openDirectory(Widget page) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => page));
    if (!mounted) return;
    setState(() => _loading = true);
    await _loadData();
  }

  Future<void> _openFirefightersDirectory() async {
    final page =
        widget.firefightersDirectoryBuilder?.call(context) ??
        const FirefightersPage();
    await _openDirectory(page);
  }

  void _toggleMember(Firefighter member, bool selected) {
    final id = member.id!;
    if (selected && _selectedIds.length >= 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('До складу ланки можна включити не більше 5 осіб'),
        ),
      );
      return;
    }
    final removedLeader = !selected && _leaderId == id;
    setState(() {
      if (selected) {
        _selectedIds.add(id);
      } else {
        _selectedIds.remove(id);
        _pressureControllers.remove(id)?.dispose();
        if (removedLeader) _leaderId = null;
      }
    });
    if (removedLeader) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Оберіть нового командира ланки')),
      );
    }
  }

  void _clearCompositionSelection() {
    _selectedIds.clear();
    _leaderId = null;
    for (final controller in _pressureControllers.values) {
      controller.dispose();
    }
    _pressureControllers.clear();
  }

  Future<void> _changeWatch(int? watch) async {
    if (watch == null || watch == _selectedWatch) return;
    if (_selectedIds.isNotEmpty) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Змінити караул?'),
          content: const Text('Обраний склад ланки та командир будуть очищені'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Скасувати'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Змінити караул'),
            ),
          ],
        ),
      );
      if (!mounted) return;
      if (confirmed != true) {
        setState(() => _watchFieldRevision += 1);
        return;
      }
      _clearCompositionSelection();
    }
    setState(() => _selectedWatch = watch);
  }

  void _continueToPreparation() {
    if (!_compositionValid) return;
    final defaultPressure = _selectedApparatus!.workingPressure.toString();
    for (final member in _selectedFirefighters) {
      _pressureControllers.putIfAbsent(
        member.id!,
        () => TextEditingController(text: defaultPressure),
      );
    }
    setState(() => _step = 1);
  }

  Future<void> _includeTeam() async {
    if (_isSaving) return;
    if (!_pressureFormKey.currentState!.validate()) return;
    final apparatus = _selectedApparatus!;
    final pressures = {
      for (final id in _selectedIds)
        id: int.parse(_pressureControllers[id]!.text.trim()),
    };
    final minimumAllowed = (apparatus.workingPressure * 0.9).ceil();
    if (pressures.values.any((pressure) => pressure < minimumAllowed)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Початковий тиск має бути не менше $minimumAllowed бар (90%).',
          ),
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Підтвердити включення в ЗІЗОД?'),
        content: const Text(
          'Буде зафіксовано час включення та розпочато відлік часу прямування.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Скасувати'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Увімкнутися'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;

    setState(() => _isSaving = true);
    try {
      final active = await _teamSessionRepository.getActiveSession();
      if (!mounted) return;
      if (active != null) {
        setState(() => _isSaving = false);
        await _showExistingSession(active.id);
        return;
      }

      final inclusionTime = DateTime.now();
      final session = ActiveTeamSession.advancing(
        unitName: _selectedUnit!.name,
        apparatusName: apparatus.name,
        participants: _selectedFirefighters,
        leaderId: _leaderId!,
        startPressuresByFirefighterId: pressures,
        inclusionTime: inclusionTime,
        workLoad: _workLoad,
        cylinderVolume: apparatus.cylinderVolume,
        cylindersCount: apparatus.cylindersCount,
        reservePressure: apparatus.reservePressure,
        events: [
          ActiveTeamEvent(
            time: inclusionTime,
            title: 'Ланка увімкнулася в ЗІЗОД',
          ),
        ],
      );
      final sessionId = await _teamSessionRepository.createAdvancingSession(
        unit: _selectedUnit!,
        apparatus: apparatus,
        session: session,
      );
      if (!mounted) return;
      await Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ActiveTeamPage(
            sessionId: sessionId,
            repository: _teamSessionRepository,
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не вдалося зберегти активну ланку.')),
      );
    }
  }

  Future<void> _showExistingSession(int sessionId) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Уже є активна ланка'),
        content: const Text(
          'Спочатку завершіть поточну ланку або відкрийте її для продовження',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Скасувати'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => ActiveTeamPage(
                    sessionId: sessionId,
                    repository: _teamSessionRepository,
                  ),
                ),
              );
            },
            child: const Text('Відкрити активну ланку'),
          ),
        ],
      ),
    );
  }

  Widget _empty(String message, String action, VoidCallback onPressed) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 8),
          OutlinedButton(onPressed: onPressed, child: Text(action)),
        ],
      ),
    ),
  );

  Widget _composition() {
    final visibleFirefighters = _visibleFirefighters;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_units.isEmpty)
          _empty(
            'Додайте підрозділ у довідник.',
            'Відкрити підрозділи',
            () => _openDirectory(const UnitsPage()),
          )
        else
          DropdownButtonFormField<Unit>(
            initialValue: _selectedUnit,
            decoration: const InputDecoration(labelText: 'Підрозділ'),
            items: [
              for (final unit in _units)
                DropdownMenuItem(
                  value: unit,
                  child: Text('${unit.name} (${unit.city})'),
                ),
            ],
            onChanged: (value) => setState(() => _selectedUnit = value),
          ),
        const SizedBox(height: 16),
        if (_apparatus.isEmpty)
          _empty(
            'Додайте апарат у довідник.',
            'Відкрити апарати',
            () => _openDirectory(const ApparatusPage()),
          )
        else
          DropdownButtonFormField<Apparatus>(
            initialValue: _selectedApparatus,
            decoration: const InputDecoration(labelText: 'Апарат'),
            items: [
              for (final item in _apparatus)
                DropdownMenuItem(value: item, child: Text(item.name)),
            ],
            onChanged: (value) => setState(() => _selectedApparatus = value),
          ),
        const SizedBox(height: 20),
        if (_firefighters.isEmpty)
          _empty(
            'Додайте газодимозахисників у довідник.',
            'Додати газодимозахисника',
            _openFirefightersDirectory,
          )
        else
          KeyedSubtree(
            key: ValueKey('watch-$_selectedWatch-$_watchFieldRevision'),
            child: DropdownButtonFormField<int>(
              key: const Key('watch-selector'),
              initialValue: _selectedWatch,
              decoration: const InputDecoration(
                labelText: 'Караул',
                hintText: 'Оберіть караул',
                prefixIcon: Icon(Icons.shield_outlined),
              ),
              items: [
                for (final watch in _watchOptions)
                  DropdownMenuItem(
                    value: watch,
                    child: Text(watchValueLabel(watch)),
                  ),
              ],
              onChanged: _changeWatch,
            ),
          ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: Text(
                'Склад ланки',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
            Text(
              'Обрано: ${_selectedIds.length}',
              key: const Key('selected-members-count'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_selectedWatch == null)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('Спочатку оберіть караул'),
            ),
          )
        else if (visibleFirefighters.isEmpty)
          _empty(
            'У цьому караулі немає доданих газодимозахисників',
            'Додати газодимозахисника',
            _openFirefightersDirectory,
          )
        else
          ...visibleFirefighters.map((member) {
            final selected = _selectedIds.contains(member.id);
            return Card(
              color: selected
                  ? Theme.of(context).colorScheme.primaryContainer
                  : null,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: selected
                    ? BorderSide(
                        color: Theme.of(context).colorScheme.primary,
                        width: 1.5,
                      )
                    : BorderSide.none,
              ),
              child: CheckboxListTile(
                dense: true,
                value: selected,
                title: Text(member.fullName),
                subtitle: member.id == _leaderId
                    ? const Text('Командир')
                    : null,
                onChanged: (value) {
                  if (value != null) _toggleMember(member, value);
                },
              ),
            );
          }),
        const SizedBox(height: 16),
        KeyedSubtree(
          key: ValueKey('leader-$_leaderId-${_selectedIds.join('-')}'),
          child: DropdownButtonFormField<int>(
            key: const Key('leader-selector'),
            initialValue: _leaderId,
            decoration: const InputDecoration(labelText: 'Командир ланки'),
            items: [
              for (final member in _selectedFirefighters)
                DropdownMenuItem(
                  value: member.id,
                  child: Text(member.fullName),
                ),
            ],
            onChanged: _selectedIds.isEmpty
                ? null
                : (value) => setState(() => _leaderId = value),
          ),
        ),
      ],
    );
  }

  Widget _preparation() {
    final apparatus = _selectedApparatus!;
    return Form(
      key: _pressureFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Підготовка ланки',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          const Text('Введіть початковий тиск перед включенням у ЗІЗОД.'),
          const SizedBox(height: 12),
          ..._selectedFirefighters.map(
            (member) => PressureInput(
              key: ValueKey('start-${member.id}'),
              firefighterName: member.fullName,
              isLeader: member.id == _leaderId,
              controller: _pressureControllers[member.id!]!,
              minValue: 1,
              maxValue: apparatus.workingPressure,
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<WorkLoad>(
            initialValue: _workLoad,
            decoration: const InputDecoration(labelText: 'Умови роботи'),
            items: const [
              DropdownMenuItem(
                value: WorkLoad.medium,
                child: Text('Середнє навантаження'),
              ),
              DropdownMenuItem(
                value: WorkLoad.heavy,
                child: Text('Важке навантаження'),
              ),
            ],
            onChanged: (value) {
              if (value != null) setState(() => _workLoad = value);
            },
          ),
          const SizedBox(height: 24),
          AppButton(
            text: _isSaving ? 'Збереження…' : 'Увімкнутися в ЗІЗОД',
            onPressed: _isSaving ? null : _includeTeam,
            icon: Icons.timer,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Нова ланка')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_error!),
                  FilledButton(
                    onPressed: _loadData,
                    child: const Text('Повторити'),
                  ),
                ],
              ),
            )
          : SafeArea(
              child: Column(
                children: [
                  LinearProgressIndicator(value: (_step + 1) / 2),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [_step == 0 ? _composition() : _preparation()],
                    ),
                  ),
                  if (_step == 0)
                    SafeArea(
                      top: false,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: AppButton(
                          text: 'Далі',
                          onPressed: _compositionValid
                              ? _continueToPreparation
                              : null,
                          icon: Icons.arrow_forward,
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}
