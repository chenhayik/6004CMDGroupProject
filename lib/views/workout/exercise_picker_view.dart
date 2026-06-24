import 'package:flutter/material.dart';
import '../../models/exercise.dart';
import '../../services/exercise_library_service.dart';

const _green = Color(0xFF22C55E);
const _bg = Color(0xFFF8FAFC);
const _title = Color(0xFF0F172A);

/// Lets the user pick an exercise (preset or custom). Pops with the chosen
/// [Exercise], or null if dismissed.
class ExercisePickerView extends StatefulWidget {
  const ExercisePickerView({super.key});

  @override
  State<ExercisePickerView> createState() => _ExercisePickerViewState();
}

class _ExercisePickerViewState extends State<ExercisePickerView> {
  final ExerciseLibraryService _service = ExerciseLibraryService();
  List<Exercise> _all = [];
  bool _loading = true;
  String _query = '';
  MuscleGroup? _muscleFilter;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final all = await _service.getAll();
    if (!mounted) return;
    setState(() {
      _all = all;
      _loading = false;
    });
  }

  List<Exercise> get _filtered {
    return _all.where((e) {
      final matchesQuery =
          _query.isEmpty || e.name.toLowerCase().contains(_query.toLowerCase());
      final matchesMuscle =
          _muscleFilter == null || e.muscleGroup == _muscleFilter;
      return matchesQuery && matchesMuscle;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        foregroundColor: _title,
        title: const Text('Add Exercise',
            style: TextStyle(fontWeight: FontWeight.bold, color: _title)),
        actions: [
          TextButton.icon(
            onPressed: _openCreateCustom,
            icon: const Icon(Icons.add, color: _green, size: 20),
            label: const Text('New', style: TextStyle(color: _green)),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Search ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: TextField(
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                hintText: 'Search exercises',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _green, width: 2),
                ),
              ),
            ),
          ),
          // ── Muscle-group filter chips ──
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                _chip('All', _muscleFilter == null,
                    () => setState(() => _muscleFilter = null)),
                ...MuscleGroup.values.map((m) => _chip(
                      m.label,
                      _muscleFilter == m,
                      () => setState(() => _muscleFilter = m),
                    )),
              ],
            ),
          ),
          const SizedBox(height: 4),
          // ── List ──
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _filtered.isEmpty
                    ? const Center(
                        child: Text('No exercises found',
                            style: TextStyle(color: Colors.black45)))
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                        itemCount: _filtered.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (_, i) => _tile(_filtered[i]),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, bool selected, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
        showCheckmark: false,
        selectedColor: _green,
        backgroundColor: Colors.white,
        labelStyle: TextStyle(
            color: selected ? Colors.white : Colors.black54,
            fontSize: 12,
            fontWeight: FontWeight.w600),
        side: BorderSide(color: selected ? _green : Colors.grey.shade300),
      ),
    );
  }

  Widget _tile(Exercise e) {
    return GestureDetector(
      onTap: () => Navigator.pop(context, e),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(11)),
              child: const Icon(Icons.fitness_center,
                  color: _green, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(e.name,
                            style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: _title),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ),
                      if (e.isCustom) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(6)),
                          child: const Text('CUSTOM',
                              style: TextStyle(
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF378ADD))),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${e.muscleGroup.label} · ${e.equipment.label} · ${e.type.label}',
                    style:
                        const TextStyle(fontSize: 11, color: Colors.black45),
                  ),
                ],
              ),
            ),
            const Icon(Icons.add_circle_outline, color: _green),
          ],
        ),
      ),
    );
  }

  Future<void> _openCreateCustom() async {
    final created = await showModalBottomSheet<Exercise>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const _CreateCustomSheet(),
    );
    if (created != null && mounted) {
      // Newly created — return it straight to the session.
      Navigator.pop(context, created);
    }
  }
}

class _CreateCustomSheet extends StatefulWidget {
  const _CreateCustomSheet();

  @override
  State<_CreateCustomSheet> createState() => _CreateCustomSheetState();
}

class _CreateCustomSheetState extends State<_CreateCustomSheet> {
  final _nameController = TextEditingController();
  final _videoController = TextEditingController();
  ExerciseType _type = ExerciseType.weightReps;
  MuscleGroup _muscle = MuscleGroup.chest;
  Equipment _equipment = Equipment.barbell;
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _videoController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_nameController.text.trim().isEmpty) return;
    setState(() => _saving = true);
    try {
      final created = await ExerciseLibraryService().createCustom(
        name: _nameController.text.trim(),
        type: _type,
        muscleGroup: _muscle,
        equipment: _equipment,
        videoUrl: _videoController.text.trim().isEmpty
            ? null
            : _videoController.text.trim(),
      );
      if (mounted) Navigator.pop(context, created);
    } catch (_) {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 16),
          const Text('New Exercise',
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold, color: _title)),
          const SizedBox(height: 16),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
                labelText: 'Name', border: OutlineInputBorder()),
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 12),
          _dropdown<ExerciseType>('Type', _type, ExerciseType.values,
              (v) => _type = v!, (t) => t.label),
          const SizedBox(height: 12),
          _dropdown<MuscleGroup>('Muscle group', _muscle, MuscleGroup.values,
              (v) => _muscle = v!, (m) => m.label),
          const SizedBox(height: 12),
          _dropdown<Equipment>('Equipment', _equipment, Equipment.values,
              (v) => _equipment = v!, (e) => e.label),
          const SizedBox(height: 12),
          TextField(
            controller: _videoController,
            decoration: const InputDecoration(
                labelText: 'How-to video URL (optional)',
                border: OutlineInputBorder()),
            keyboardType: TextInputType.url,
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: _green,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(26)),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Text('Create & Add',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dropdown<T>(String label, T value, List<T> items,
      ValueChanged<T?> onChanged, String Function(T) labelOf) {
    return DropdownButtonFormField<T>(
      initialValue: value,
      decoration: InputDecoration(
          labelText: label, border: const OutlineInputBorder()),
      items: items
          .map((e) => DropdownMenuItem(value: e, child: Text(labelOf(e))))
          .toList(),
      onChanged: (v) => setState(() => onChanged(v)),
    );
  }
}
