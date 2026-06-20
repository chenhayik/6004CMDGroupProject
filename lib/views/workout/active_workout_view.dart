import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../models/exercise.dart';
import '../../models/workout.dart';
import '../../viewmodels/active_workout_viewmodel.dart';
import 'exercise_picker_view.dart';
import 'workout_summary_view.dart';

const _green = Color(0xFF22C55E);
const _bg = Color(0xFFF8FAFC);
const _title = Color(0xFF0F172A);
const _amber = Color(0xFFF59E0B);

String _fmtClock(int seconds) {
  final m = (seconds ~/ 60).toString().padLeft(2, '0');
  final s = (seconds % 60).toString().padLeft(2, '0');
  final h = seconds ~/ 3600;
  return h > 0 ? '$h:$m:$s' : '$m:$s';
}

class ActiveWorkoutView extends StatelessWidget {
  const ActiveWorkoutView({super.key});

  Future<void> _addExercise(BuildContext context, ActiveWorkoutViewModel vm) async {
    final picked = await Navigator.push<Exercise>(
      context,
      MaterialPageRoute(builder: (_) => const ExercisePickerView()),
    );
    if (picked != null) vm.addExercise(picked);
  }

  Future<void> _finish(BuildContext context, ActiveWorkoutViewModel vm) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Finish workout?'),
        content: const Text('Your sets will be saved to history.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep going')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: _green),
            child: const Text('Finish', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    final finished = await vm.finish();
    if (finished != null && context.mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => WorkoutSummaryView(workout: finished)),
      );
    } else if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save workout. Try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ActiveWorkoutViewModel>();
    final workout = vm.workout;

    if (workout == null) {
      return const Scaffold(
        backgroundColor: _bg,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        foregroundColor: _title,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(workout.name,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold, color: _title)),
            Text(_fmtClock(vm.elapsedSec),
                style: const TextStyle(fontSize: 12, color: Colors.black54)),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton(
              onPressed: vm.isSaving ? null : () => _finish(context, vm),
              style: TextButton.styleFrom(
                backgroundColor: _green,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20)),
                padding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              child: const Text('Finish',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          _RestBar(vm: vm),
          _StatsBar(vm: vm),
          Expanded(
            child: workout.exercises.isEmpty
                ? _emptyState(context, vm)
                : ListView(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
                    children: [
                      for (int i = 0; i < workout.exercises.length; i++)
                        _ExerciseCard(vm: vm, exIndex: i),
                      const SizedBox(height: 8),
                      _addExerciseButton(context, vm),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState(BuildContext context, ActiveWorkoutViewModel vm) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.fitness_center, size: 48, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          const Text('No exercises yet',
              style: TextStyle(color: Colors.black54, fontSize: 14)),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => _addExercise(context, vm),
            style: ElevatedButton.styleFrom(
              backgroundColor: _green,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24)),
            ),
            icon: const Icon(Icons.add),
            label: const Text('Add Exercise'),
          ),
        ],
      ),
    );
  }

  Widget _addExerciseButton(BuildContext context, ActiveWorkoutViewModel vm) {
    return GestureDetector(
      onTap: () => _addExercise(context, vm),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFF0FDF4),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _green),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add, color: _green, size: 20),
            SizedBox(width: 8),
            Text('Add Exercise',
                style: TextStyle(
                    color: _green, fontWeight: FontWeight.bold, fontSize: 14)),
          ],
        ),
      ),
    );
  }
}

// ─── Rest timer bar ──────────────────────────────────────────
// The rest timer is started and stopped (paused) with a button; "Skip" still
// ends it. When idle it shows a Start button instead of auto-starting.
class _RestBar extends StatelessWidget {
  final ActiveWorkoutViewModel vm;
  const _RestBar({required this.vm});

  @override
  Widget build(BuildContext context) {
    return vm.restActive ? _activeBar() : _idleBar();
  }

  Widget _idleBar() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const Icon(Icons.timer_outlined, color: Colors.black45, size: 20),
          const SizedBox(width: 10),
          const Text('Rest timer',
              style: TextStyle(
                  color: _title, fontWeight: FontWeight.w600, fontSize: 14)),
          const SizedBox(width: 8),
          Text('${vm.defaultRestSec}s',
              style: const TextStyle(color: Colors.black38, fontSize: 13)),
          const Spacer(),
          GestureDetector(
            onTap: vm.toggleRest,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              decoration: BoxDecoration(
                  color: _green, borderRadius: BorderRadius.circular(18)),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.play_arrow, color: Colors.white, size: 18),
                  SizedBox(width: 4),
                  Text('Start',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _activeBar() {
    final paused = vm.restPaused;
    return Container(
      color: paused ? _amber : _green,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Icon(paused ? Icons.pause : Icons.timer,
              color: Colors.white, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '${paused ? 'Paused' : 'Rest'}  ${_fmtClock(vm.restRemaining)}',
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15),
            ),
          ),
          // Start/Stop toggle
          _restBtn(paused ? 'Resume' : 'Stop', vm.toggleRest),
          const SizedBox(width: 6),
          _restBtn('+15s', () => vm.addRest(15)),
          const SizedBox(width: 6),
          _restBtn('Skip', vm.skipRest),
        ],
      ),
    );
  }

  Widget _restBtn(String label, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
          decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.25),
              borderRadius: BorderRadius.circular(16)),
          child: Text(label,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 12)),
        ),
      );
}

// ─── Stats summary bar ───────────────────────────────────────
class _StatsBar extends StatelessWidget {
  final ActiveWorkoutViewModel vm;
  const _StatsBar({required this.vm});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          _stat('Volume', '${vm.totalVolume.toStringAsFixed(0)} kg'),
          _divider(),
          _stat('Sets', '${vm.completedSets}'),
          _divider(),
          _stat('Time', _fmtClock(vm.elapsedSec)),
        ],
      ),
    );
  }

  Widget _stat(String label, String value) => Expanded(
        child: Column(
          children: [
            Text(value,
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.bold, color: _title)),
            const SizedBox(height: 2),
            Text(label,
                style: const TextStyle(fontSize: 11, color: Colors.black45)),
          ],
        ),
      );

  Widget _divider() =>
      Container(width: 1, height: 28, color: Colors.grey.shade200);
}

// ─── Exercise card with its sets ─────────────────────────────
class _ExerciseCard extends StatelessWidget {
  final ActiveWorkoutViewModel vm;
  final int exIndex;
  const _ExerciseCard({required this.vm, required this.exIndex});

  WorkoutExercise get ex => vm.workout!.exercises[exIndex];

  @override
  Widget build(BuildContext context) {
    final type = ex.type;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(ex.name,
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: _title)),
              ),
              IconButton(
                icon: const Icon(Icons.more_vert, size: 20, color: Colors.black38),
                onPressed: () => _showExerciseMenu(context),
              ),
            ],
          ),
          const SizedBox(height: 4),
          _SetHeader(type: type),
          for (int i = 0; i < ex.sets.length; i++)
            _SetRow(vm: vm, exIndex: exIndex, setIndex: i),
          const SizedBox(height: 6),
          GestureDetector(
            onTap: () => vm.addSet(exIndex),
            child: Container(
              margin: const EdgeInsets.only(right: 6),
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Center(
                child: Text('+ Add Set',
                    style: TextStyle(
                        color: Colors.black54,
                        fontWeight: FontWeight.w600,
                        fontSize: 13)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showExerciseMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('Remove exercise',
                  style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(sheet);
                vm.removeExercise(exIndex);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// ─── Column headers per exercise type ────────────────────────
class _SetHeader extends StatelessWidget {
  final ExerciseType type;
  const _SetHeader({required this.type});

  @override
  Widget build(BuildContext context) {
    final labels = <String>['SET', 'PREV'];
    if (type.needsWeight) labels.add('KG');
    if (type.needsReps) labels.add('REPS');
    if (type.needsDistance) labels.add('M');
    if (type.needsDuration) labels.add('SEC');

    return Padding(
      padding: const EdgeInsets.only(right: 44, bottom: 2, top: 2),
      child: Row(
        children: [
          SizedBox(width: 34, child: _h(labels[0])),
          SizedBox(width: 64, child: _h(labels[1])),
          for (int i = 2; i < labels.length; i++) Expanded(child: _h(labels[i])),
        ],
      ),
    );
  }

  Widget _h(String t) => Text(t,
      textAlign: TextAlign.center,
      style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: Colors.black38,
          letterSpacing: 0.5));
}

// ─── A single editable set row ───────────────────────────────
class _SetRow extends StatelessWidget {
  final ActiveWorkoutViewModel vm;
  final int exIndex;
  final int setIndex;
  const _SetRow(
      {required this.vm, required this.exIndex, required this.setIndex});

  @override
  Widget build(BuildContext context) {
    final ex = vm.workout!.exercises[exIndex];
    final set = ex.sets[setIndex];
    final type = ex.type;
    final prev = vm.previousSet(ex.exerciseId, setIndex);

    final fields = <Widget>[];
    if (type.needsWeight) {
      fields.add(Expanded(
        child: _NumField(
          value: set.weightKg,
          decimal: true,
          hint: '0',
          onChanged: (v) => vm.updateSet(exIndex, setIndex, weightKg: v ?? 0),
        ),
      ));
    }
    if (type.needsReps) {
      fields.add(Expanded(
        child: _NumField(
          value: set.reps?.toDouble(),
          hint: '0',
          onChanged: (v) =>
              vm.updateSet(exIndex, setIndex, reps: v?.round() ?? 0),
        ),
      ));
    }
    if (type.needsDistance) {
      fields.add(Expanded(
        child: _NumField(
          value: set.distanceM,
          decimal: true,
          hint: '0',
          onChanged: (v) => vm.updateSet(exIndex, setIndex, distanceM: v ?? 0),
        ),
      ));
    }
    if (type.needsDuration) {
      fields.add(Expanded(
        child: _NumField(
          value: set.durationSec?.toDouble(),
          hint: '0',
          onChanged: (v) =>
              vm.updateSet(exIndex, setIndex, durationSec: v?.round() ?? 0),
        ),
      ));
    }

    final bg = set.completed ? const Color(0xFFF0FDF4) : Colors.transparent;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      padding: const EdgeInsets.symmetric(vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          // Set badge — tap to change set type (warm-up/drop/failure)
          GestureDetector(
            onTap: () => _pickSetType(context, set),
            child: SizedBox(
              width: 34,
              child: _SetBadge(set: set, number: setIndex + 1),
            ),
          ),
          // Previous column
          SizedBox(
            width: 64,
            child: Text(
              _prevLabel(prev, type),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11, color: Colors.black38),
            ),
          ),
          ...fields,
          // PR badge
          SizedBox(
            width: 24,
            child: set.isPR
                ? const Icon(Icons.emoji_events, color: _amber, size: 16)
                : const SizedBox.shrink(),
          ),
          // Complete checkbox
          GestureDetector(
            onTap: () => vm.toggleComplete(exIndex, setIndex),
            child: Container(
              width: 30,
              height: 30,
              margin: const EdgeInsets.only(left: 2, right: 4),
              decoration: BoxDecoration(
                color: set.completed ? _green : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: set.completed ? _green : Colors.grey.shade400,
                    width: 1.5),
              ),
              child: Icon(Icons.check,
                  size: 18,
                  color: set.completed ? Colors.white : Colors.grey.shade400),
            ),
          ),
        ],
      ),
    );
  }

  String _prevLabel(WorkoutSet? prev, ExerciseType type) {
    if (prev == null) return '—';
    if (type.needsWeight && prev.weightKg != null && prev.reps != null) {
      return '${_n(prev.weightKg)}×${prev.reps}';
    }
    if (type.needsReps && prev.reps != null) return '${prev.reps} reps';
    if (type.needsDistance && prev.distanceM != null) {
      return '${_n(prev.distanceM)} m';
    }
    if (type.needsDuration && prev.durationSec != null) {
      return '${prev.durationSec}s';
    }
    return '—';
  }

  String _n(double? v) {
    if (v == null) return '0';
    return v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
  }

  void _pickSetType(BuildContext context, WorkoutSet set) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            const Text('Set type',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            for (final t in SetType.values)
              ListTile(
                dense: true,
                title: Text(_setTypeLabel(t)),
                trailing: set.type == t
                    ? const Icon(Icons.check, color: _green)
                    : null,
                onTap: () {
                  Navigator.pop(sheet);
                  vm.setSetType(exIndex, setIndex, t);
                },
              ),
            // Remove set
            ListTile(
              dense: true,
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('Remove set',
                  style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(sheet);
                vm.removeSet(exIndex, setIndex);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  String _setTypeLabel(SetType t) {
    switch (t) {
      case SetType.warmup:  return 'Warm-up';
      case SetType.normal:  return 'Normal';
      case SetType.drop:    return 'Drop set';
      case SetType.failure: return 'Failure';
    }
  }
}

class _SetBadge extends StatelessWidget {
  final WorkoutSet set;
  final int number;
  const _SetBadge({required this.set, required this.number});

  @override
  Widget build(BuildContext context) {
    final isWarm = set.type == SetType.warmup;
    final short = set.type.shortLabel;
    final text = short.isEmpty ? '$number' : short;
    final color = switch (set.type) {
      SetType.warmup => _amber,
      SetType.drop => const Color(0xFF378ADD),
      SetType.failure => Colors.red,
      SetType.normal => Colors.black54,
    };
    return Center(
      child: Container(
        width: 26,
        height: 26,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isWarm ? const Color(0xFFFEF3C7) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(text,
            style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.bold, color: color)),
      ),
    );
  }
}

// ─── Numeric field that survives prefills without cursor jumps ───
class _NumField extends StatefulWidget {
  final double? value;
  final String hint;
  final bool decimal;
  final ValueChanged<double?> onChanged;
  const _NumField({
    required this.value,
    required this.hint,
    required this.onChanged,
    this.decimal = false,
  });

  @override
  State<_NumField> createState() => _NumFieldState();
}

class _NumFieldState extends State<_NumField> {
  late final TextEditingController _c;
  final FocusNode _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _c = TextEditingController(text: _fmt(widget.value));
  }

  String _fmt(double? v) {
    if (v == null || v == 0) return '';
    if (widget.decimal) {
      return v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();
    }
    return v.round().toString();
  }

  @override
  void didUpdateWidget(covariant _NumField old) {
    super.didUpdateWidget(old);
    // Reflect external prefills (e.g. "previous") only when not being edited.
    if (!_focus.hasFocus && widget.value != old.value) {
      final t = _fmt(widget.value);
      if (t != _c.text) _c.text = t;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: TextField(
        controller: _c,
        focusNode: _focus,
        textAlign: TextAlign.center,
        keyboardType:
            TextInputType.numberWithOptions(decimal: widget.decimal),
        inputFormatters: [
          widget.decimal
              ? FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))
              : FilteringTextInputFormatter.digitsOnly,
        ],
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        decoration: InputDecoration(
          hintText: widget.hint,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 8),
          filled: true,
          fillColor: const Color(0xFFF8FAFC),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.grey.shade200),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: _green, width: 1.5),
          ),
        ),
        onChanged: (v) => widget.onChanged(double.tryParse(v)),
      ),
    );
  }
}
