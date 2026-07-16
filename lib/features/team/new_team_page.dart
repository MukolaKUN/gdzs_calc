import 'package:flutter/material.dart';
import 'package:gdzs_calc/features/apparatus/apparatus_page.dart';
import 'package:gdzs_calc/features/firefighters/firefighters_page.dart';
import 'package:gdzs_calc/features/team/active_team_page.dart';
import 'package:gdzs_calc/features/team/models/active_team_session.dart';
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

class NewTeamPage extends StatefulWidget {
  final List<Unit>? initialUnits;
  final List<Apparatus>? initialApparatus;
  final List<Firefighter>? initialFirefighters;

  const NewTeamPage({
    super.key,
    this.initialUnits,
    this.initialApparatus,
    this.initialFirefighters,
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
  int? _leaderId;
  WorkLoad _workLoad = WorkLoad.medium;
  int _step = 0;
  bool _loading = true;
  String? _error;

  List<Firefighter> get _selectedFirefighters => [
    for (final id in _selectedIds)
      _firefighters.firstWhere((member) => member.id == id),
  ];

  bool get _compositionValid =>
      _selectedUnit != null &&
      _selectedApparatus != null &&
      _selectedIds.length >= 2 &&
      _selectedIds.length <= 5 &&
      _leaderId != null;

  @override
  void initState() {
    super.initState();
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
        _unitRepository.getAll(),
        _apparatusRepository.getAll(),
        _firefighterRepository.getAll(),
      ]);
      if (!mounted) return;
      setState(() {
        _units = values[0] as List<Unit>;
        _apparatus = values[1] as List<Apparatus>;
        _firefighters = values[2] as List<Firefighter>;
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

  void _toggleMember(Firefighter member, bool selected) {
    final id = member.id!;
    setState(() {
      if (selected) {
        if (_selectedIds.length < 5) _selectedIds.add(id);
      } else {
        _selectedIds.remove(id);
        if (_leaderId == id) _leaderId = null;
      }
    });
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
    await Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => ActiveTeamPage(session: session)),
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

  Widget _composition() => RadioGroup<int>(
    groupValue: _leaderId,
    onChanged: (value) => setState(() => _leaderId = value),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Склад ланки', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 16),
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
        const SizedBox(height: 24),
        Text(
          'Газодимозахисники (2–5)',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        if (_firefighters.isEmpty)
          _empty(
            'Додайте газодимозахисників у довідник.',
            'Відкрити довідник',
            () => _openDirectory(const FirefightersPage()),
          )
        else
          ..._firefighters.where((member) => member.id != null).map((member) {
            final selected = _selectedIds.contains(member.id);
            return Card(
              child: Column(
                children: [
                  CheckboxListTile(
                    value: selected,
                    enabled: selected || _selectedIds.length < 5,
                    title: Text(member.fullName),
                    onChanged: (value) {
                      if (value != null) _toggleMember(member, value);
                    },
                  ),
                  if (selected)
                    RadioListTile<int>(
                      value: member.id!,
                      title: const Text('Командир ланки'),
                    ),
                ],
              ),
            );
          }),
      ],
    ),
  );

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
            text: 'Увімкнутися в ЗІЗОД',
            onPressed: _includeTeam,
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
