import 'package:flutter/material.dart';
import 'package:gdzs_calc/features/apparatus/apparatus_page.dart';
import 'package:gdzs_calc/features/firefighters/firefighters_page.dart';
import 'package:gdzs_calc/features/team/widgets/pressure_input.dart';
import 'package:gdzs_calc/features/units/units_page.dart';
import 'package:gdzs_calc/shared/models/apparatus.dart';
import 'package:gdzs_calc/shared/models/firefighter.dart';
import 'package:gdzs_calc/shared/models/unit.dart';
import 'package:gdzs_calc/shared/repositories/apparatus_repository.dart';
import 'package:gdzs_calc/shared/repositories/firefighter_repository.dart';
import 'package:gdzs_calc/shared/repositories/unit_repository.dart';
import 'package:gdzs_calc/shared/services/gdzs_calculator.dart';

class NewTeamPage extends StatefulWidget {
  const NewTeamPage({super.key});

  @override
  State<NewTeamPage> createState() => _NewTeamPageState();
}

class _NewTeamPageState extends State<NewTeamPage> {
  final _unitRepository = UnitRepository();
  final _apparatusRepository = ApparatusRepository();
  final _firefighterRepository = FirefighterRepository();
  final _inclusionFormKey = GlobalKey<FormState>();
  final _arrivalFormKey = GlobalKey<FormState>();

  List<Unit> _units = [];
  List<Apparatus> _apparatus = [];
  List<Firefighter> _firefighters = [];

  bool _isLoading = true;
  String? _loadError;
  int _step = 0;

  Unit? _selectedUnit;
  Apparatus? _selectedApparatus;
  final List<int> _selectedFirefighterIds = [];
  int? _leaderId;

  DateTime? _inclusionTime;
  DateTime? _arrivalTime;

  final Map<int, TextEditingController> _startPressureControllers = {};
  final Map<int, TextEditingController> _arrivalPressureControllers = {};

  WorkLoad _workLoad = WorkLoad.medium;
  String? _pressureError;
  String? _calculationError;
  CompressedAirCalculationResult? _result;

  List<Firefighter> get _selectedFirefighters => _selectedFirefighterIds
      .map(
        (id) => _firefighters.firstWhere(
          (firefighter) => firefighter.id == id,
        ),
      )
      .toList();

  bool get _canContinueComposition =>
      _selectedUnit != null &&
      _selectedApparatus != null &&
      _selectedFirefighterIds.length >= 2 &&
      _selectedFirefighterIds.length <= 5 &&
      _leaderId != null;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _disposeControllers(_startPressureControllers);
    _disposeControllers(_arrivalPressureControllers);
    super.dispose();
  }

  void _disposeControllers(
    Map<int, TextEditingController> controllers,
  ) {
    for (final controller in controllers.values) {
      controller.dispose();
    }
    controllers.clear();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    try {
      final units = await _unitRepository.getAll();
      final apparatus = await _apparatusRepository.getAll();
      final firefighters = await _firefighterRepository.getAll();
      final selectedUnitId = _selectedUnit?.id;
      final selectedApparatusId = _selectedApparatus?.id;

      if (!mounted) return;

      setState(() {
        _units = units;
        _apparatus = apparatus;
        _firefighters = firefighters;
        _selectedUnit = _findUnit(units, selectedUnitId);
        _selectedApparatus = _findApparatus(
          apparatus,
          selectedApparatusId,
        );

        _selectedFirefighterIds.removeWhere(
          (id) => !firefighters.any(
            (firefighter) => firefighter.id == id,
          ),
        );

        if (_leaderId != null &&
            !_selectedFirefighterIds.contains(_leaderId)) {
          _leaderId = null;
        }

        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _loadError =
            'Не вдалося завантажити довідники. Спробуйте ще раз.';
        _isLoading = false;
      });
    }
  }

  Future<void> _openUnitsDirectory() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const UnitsPage()),
    );

    if (!mounted) return;
    await _loadData();
  }

  Future<void> _openApparatusDirectory() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ApparatusPage()),
    );

    if (!mounted) return;
    await _loadData();
  }

  Future<void> _openFirefightersDirectory() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const FirefightersPage()),
    );

    if (!mounted) return;
    await _loadData();
  }

  Unit? _findUnit(List<Unit> units, int? id) {
    for (final unit in units) {
      if (unit.id == id) return unit;
    }
    return null;
  }

  Apparatus? _findApparatus(
    List<Apparatus> apparatus,
    int? id,
  ) {
    for (final item in apparatus) {
      if (item.id == id) return item;
    }
    return null;
  }

  void _toggleFirefighter(
    Firefighter firefighter,
    bool selected,
  ) {
    final id = firefighter.id;
    if (id == null) return;

    setState(() {
      if (selected) {
        if (_selectedFirefighterIds.length < 5 &&
            !_selectedFirefighterIds.contains(id)) {
          _selectedFirefighterIds.add(id);
        }
      } else {
        _selectedFirefighterIds.remove(id);
        if (_leaderId == id) {
          _leaderId = null;
        }
      }
    });
  }

  void _startInclusion() {
    final apparatus = _selectedApparatus;
    if (apparatus == null) return;

    _disposeControllers(_startPressureControllers);
    _disposeControllers(_arrivalPressureControllers);

    for (final id in _selectedFirefighterIds) {
      _startPressureControllers[id] = TextEditingController(
        text: apparatus.workingPressure.toString(),
      );
    }

    setState(() {
      _inclusionTime = DateTime.now();
      _arrivalTime = null;
      _pressureError = null;
      _calculationError = null;
      _result = null;
      _step = 1;
    });
  }

  Future<DateTime?> _pickTime(DateTime currentTime) async {
    final selectedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(currentTime),
      builder: (context, child) {
        final mediaQuery = MediaQuery.of(context);
        return MediaQuery(
          data: mediaQuery.copyWith(
            alwaysUse24HourFormat: true,
          ),
          child: child!,
        );
      },
    );

    if (selectedTime == null) return null;

    return DateTime(
      currentTime.year,
      currentTime.month,
      currentTime.day,
      selectedTime.hour,
      selectedTime.minute,
    );
  }

  Future<void> _changeInclusionTime() async {
    final currentTime = _inclusionTime;
    if (currentTime == null) return;

    final selectedTime = await _pickTime(currentTime);
    if (selectedTime == null || !mounted) return;

    setState(() => _inclusionTime = selectedTime);
  }

  Future<void> _changeArrivalTime() async {
    final inclusionTime = _inclusionTime;
    final currentTime = _arrivalTime;

    if (inclusionTime == null || currentTime == null) return;

    final selectedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(currentTime),
      builder: (context, child) {
        final mediaQuery = MediaQuery.of(context);
        return MediaQuery(
          data: mediaQuery.copyWith(
            alwaysUse24HourFormat: true,
          ),
          child: child!,
        );
      },
    );

    if (selectedTime == null || !mounted) return;

    var arrivalTime = DateTime(
      inclusionTime.year,
      inclusionTime.month,
      inclusionTime.day,
      selectedTime.hour,
      selectedTime.minute,
    );

    if (arrivalTime.isBefore(inclusionTime)) {
      arrivalTime = arrivalTime.add(const Duration(days: 1));
    }

    setState(() => _arrivalTime = arrivalTime);
  }

  void _continueToArrival() {
    final formState = _inclusionFormKey.currentState;
    if (formState == null || !formState.validate()) return;

    final apparatus = _selectedApparatus;
    if (apparatus == null) return;

    final minimumAllowedPressure =
        (apparatus.workingPressure * 0.9).ceil();

    final hasLowPressure = _selectedFirefighterIds.any((id) {
      final pressure = int.tryParse(
        _startPressureControllers[id]?.text.trim() ?? '',
      );
      return pressure == null || pressure < minimumAllowedPressure;
    });

    if (hasLowPressure) {
      setState(() {
        _pressureError =
            'Тиск у балоні менший ніж 90% робочого тиску апарата';
      });
      return;
    }

    if (_arrivalPressureControllers.isEmpty) {
      for (final id in _selectedFirefighterIds) {
        _arrivalPressureControllers[id] = TextEditingController(
          text: _startPressureControllers[id]!.text.trim(),
        );
      }
    }

    setState(() {
      _pressureError = null;
      _arrivalTime ??= DateTime.now();
      _step = 2;
    });
  }

  void _calculate() {
    FocusScope.of(context).unfocus();

    final formState = _arrivalFormKey.currentState;
    if (formState == null || !formState.validate()) return;

    final apparatus = _selectedApparatus;
    final inclusionTime = _inclusionTime;
    final arrivalTime = _arrivalTime;

    if (apparatus == null ||
        inclusionTime == null ||
        arrivalTime == null) {
      return;
    }

    final startPressures = _selectedFirefighterIds
        .map(
          (id) => int.parse(
            _startPressureControllers[id]!.text.trim(),
          ),
        )
        .toList();

    final arrivalPressures = _selectedFirefighterIds
        .map(
          (id) => int.parse(
            _arrivalPressureControllers[id]!.text.trim(),
          ),
        )
        .toList();

    debugPrint('startPressures: $startPressures');
    debugPrint('arrivalPressures: $arrivalPressures');

    try {
      final result = GdzsCalculator.calculateCompressedAir(
        startPressures: startPressures,
        arrivalPressures: arrivalPressures,
        inclusionTime: inclusionTime,
        arrivalTime: arrivalTime,
        cylinderVolume: apparatus.cylinderVolume,
        cylindersCount: apparatus.cylindersCount,
        reservePressure: apparatus.reservePressure,
        workLoad: _workLoad,
      );

      setState(() {
        _result = result;
        _calculationError = null;
        _step = 3;
      });
    } on ArgumentError catch (error) {
      setState(() {
        _calculationError = error.message?.toString();
      });
    }
  }

  void _goBack() {
    if (_step == 0) return;

    setState(() {
      _step -= 1;
      _pressureError = null;
      _calculationError = null;
    });
  }

  String _formatTime24(DateTime value) {
    final hours = value.hour.toString().padLeft(2, '0');
    final minutes = value.minute.toString().padLeft(2, '0');
    return '$hours:$minutes';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Нова ланка')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _loadError!,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: _loadData,
                          child: const Text('Повторити'),
                        ),
                      ],
                    ),
                  ),
                )
              : SafeArea(
                  child: Column(
                    children: [
                      _StepIndicator(currentStep: _step),
                      Expanded(
                        child: ListView(
                          padding: const EdgeInsets.all(16),
                          children: [_buildStep()],
                        ),
                      ),
                      _buildNavigation(),
                    ],
                  ),
                ),
    );
  }

  Widget _buildStep() {
    switch (_step) {
      case 0:
        return _buildCompositionStep();
      case 1:
        return _buildInclusionStep();
      case 2:
        return _buildArrivalStep();
      case 3:
        return _buildResultStep();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildCompositionStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Склад ланки',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 16),
        if (_units.isEmpty)
          _EmptyDirectoryCard(
            message: 'Додайте хоча б один підрозділ у довідник.',
            actionLabel: 'Відкрити підрозділи',
            onPressed: _openUnitsDirectory,
          )
        else
          DropdownButtonFormField<Unit>(
            value: _selectedUnit,
            decoration: const InputDecoration(
              labelText: 'Підрозділ',
            ),
            items: _units
                .map(
                  (unit) => DropdownMenuItem(
                    value: unit,
                    child: Text('${unit.name} (${unit.city})'),
                  ),
                )
                .toList(),
            onChanged: (unit) {
              setState(() => _selectedUnit = unit);
            },
          ),
        const SizedBox(height: 16),
        if (_apparatus.isEmpty)
          _EmptyDirectoryCard(
            message: 'Додайте хоча б один апарат у довідник.',
            actionLabel: 'Відкрити апарати',
            onPressed: _openApparatusDirectory,
          )
        else
          DropdownButtonFormField<Apparatus>(
            value: _selectedApparatus,
            decoration: const InputDecoration(
              labelText: 'Апарат для ланки',
            ),
            items: _apparatus
                .map(
                  (apparatus) => DropdownMenuItem(
                    value: apparatus,
                    child: Text(apparatus.name),
                  ),
                )
                .toList(),
            onChanged: (apparatus) {
              setState(() => _selectedApparatus = apparatus);
            },
          ),
        const SizedBox(height: 24),
        Text(
          'Газодимозахисники (2–5)',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        if (_firefighters.isEmpty)
          _EmptyDirectoryCard(
            message:
                'Довідник газодимозахисників порожній. Спершу заповніть його в налаштуваннях.',
            actionLabel: 'Відкрити довідник газодимозахисників',
            onPressed: _openFirefightersDirectory,
          )
        else
          ..._firefighters
              .where((firefighter) => firefighter.id != null)
              .map((firefighter) {
            final id = firefighter.id!;
            final isSelected = _selectedFirefighterIds.contains(id);
            final canSelect =
                isSelected || _selectedFirefighterIds.length < 5;

            return Card(
              child: Column(
                children: [
                  CheckboxListTile(
                    value: isSelected,
                    enabled: canSelect,
                    title: Text(firefighter.fullName),
                    onChanged: (selected) {
                      if (selected != null) {
                        _toggleFirefighter(
                          firefighter,
                          selected,
                        );
                      }
                    },
                  ),
                  if (isSelected)
                    RadioListTile<int>(
                      value: id,
                      groupValue: _leaderId,
                      title: const Text('Командир ланки'),
                      onChanged: (value) {
                        setState(() => _leaderId = value);
                      },
                    ),
                ],
              ),
            );
          }),
        if (_selectedFirefighterIds.length == 2)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              'Ланка з двох осіб допускається лише у виняткових випадках',
              style: TextStyle(color: Colors.orange),
            ),
          ),
      ],
    );
  }

  Widget _buildInclusionStep() {
    final apparatus = _selectedApparatus!;
    final inclusionTime = _inclusionTime!;

    return Form(
      key: _inclusionFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Включення в ЗІЗОД',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Час включення'),
            subtitle: Text(_formatTime24(inclusionTime)),
            trailing: OutlinedButton(
              onPressed: _changeInclusionTime,
              child: const Text('Змінити'),
            ),
          ),
          ..._selectedFirefighters.map(
            (firefighter) => PressureInput(
              key: ValueKey('start-${firefighter.id}'),
              firefighterName: firefighter.fullName,
              isLeader: firefighter.id == _leaderId,
              controller:
                  _startPressureControllers[firefighter.id!]!,
              minValue: 1,
              maxValue: apparatus.workingPressure,
            ),
          ),
          if (_pressureError != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _pressureError!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildArrivalStep() {
    final arrivalTime = _arrivalTime!;

    return Form(
      key: _arrivalFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Прибуття до місця роботи',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Час прибуття'),
            subtitle: Text(_formatTime24(arrivalTime)),
            trailing: OutlinedButton(
              onPressed: _changeArrivalTime,
              child: const Text('Змінити'),
            ),
          ),
          ..._selectedFirefighters.map((firefighter) {
            final id = firefighter.id!;
            final startPressure = int.parse(
              _startPressureControllers[id]!.text.trim(),
            );

            return PressureInput(
              key: ValueKey('arrival-$id'),
              firefighterName: firefighter.fullName,
              isLeader: id == _leaderId,
              controller: _arrivalPressureControllers[id]!,
              minValue: 0,
              maxValue: startPressure,
            );
          }),
          const SizedBox(height: 12),
          DropdownButtonFormField<WorkLoad>(
            value: _workLoad,
            decoration: const InputDecoration(
              labelText: 'Навантаження',
            ),
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
            onChanged: (workLoad) {
              if (workLoad != null) {
                setState(() => _workLoad = workLoad);
              }
            },
          ),
          if (_calculationError != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _calculationError!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildResultStep() {
    final result = _result;
    if (result == null) return const SizedBox.shrink();

    final controllingFirefighter =
        _selectedFirefighters[result.controllingMemberIndex];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Результат',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ResultRow(
                  'Мінімальний початковий тиск',
                  '${result.minimumStartPressure} бар',
                ),
                _ResultRow(
                  'Критичний тиск',
                  '${result.criticalPressure} бар',
                ),
                _ResultRow(
                  'Розрахунок ведеться за',
                  controllingFirefighter.fullName,
                ),
                _ResultRow(
                  'Максимальна витрата на прямуванні',
                  '${result.travelPressure} бар',
                ),
                _ResultRow(
                  'Тиск виходу',
                  '${result.exitPressure} бар',
                ),
                _ResultRow(
                  'Тиск для роботи',
                  '${result.workingPressure} бар',
                ),
                _ResultRow(
                  'Час прямування',
                  '${result.travelTimeMinutes} хв',
                ),
                _ResultRow(
                  'Розрахунковий час роботи',
                  '${result.workingTimeMinutes} хв',
                ),
                _ResultRow(
                  'Початок виходу',
                  _formatTime24(result.exitTime),
                ),
              ],
            ),
          ),
        ),
        if (result.mustExitImmediately)
          Card(
            color: Theme.of(context).colorScheme.errorContainer,
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Ланка повинна негайно розпочати вихід',
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildNavigation() {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            if (_step > 0)
              OutlinedButton(
                onPressed: _goBack,
                child: const Text('Назад'),
              ),
            if (_step > 0) const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                onPressed: switch (_step) {
                  0 => _canContinueComposition
                      ? _startInclusion
                      : null,
                  1 => _continueToArrival,
                  2 => _calculate,
                  _ => null,
                },
                child: Text(
                  switch (_step) {
                    0 => 'Далі',
                    1 => 'Далі',
                    2 => 'Розрахувати',
                    _ => 'Готово',
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepIndicator extends StatelessWidget {
  final int currentStep;

  const _StepIndicator({
    required this.currentStep,
  });

  @override
  Widget build(BuildContext context) {
    const labels = [
      'Склад',
      'Включення',
      'Прибуття',
      'Результат',
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: Row(
        children: List.generate(labels.length, (index) {
          final isActive = index == currentStep;
          final isComplete = index < currentStep;
          final color = isActive || isComplete
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.outline;

          return Expanded(
            child: Column(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: color,
                  child: Text(
                    '${index + 1}',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimary,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  labels[index],
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}

class _EmptyDirectoryCard extends StatelessWidget {
  final String message;
  final String? actionLabel;
  final VoidCallback? onPressed;

  const _EmptyDirectoryCard({
    required this.message,
    this.actionLabel,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message),
            if (actionLabel != null) ...[
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: onPressed,
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ResultRow extends StatelessWidget {
  final String label;
  final String value;

  const _ResultRow(
    this.label,
    this.value,
  );

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(label)),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
