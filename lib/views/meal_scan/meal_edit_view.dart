import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/meal_result.dart';
import '../../viewmodels/meal_scan_viewmodel.dart';

class MealEditView extends StatefulWidget {
  final MealResult?  prefilled;     // null = manual entry, non-null = scan result
  final Uint8List?   imageBytes;    // only present for scan results

  const MealEditView({
    super.key,
    this.prefilled,
    this.imageBytes,
  });

  @override
  State<MealEditView> createState() => _MealEditViewState();
}

class _MealEditViewState extends State<MealEditView> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _foodNameCtrl;
  late final TextEditingController _caloriesCtrl;
  late final TextEditingController _proteinCtrl;
  late final TextEditingController _carbsCtrl;
  late final TextEditingController _fatCtrl;

  static const _green   = Color(0xFF22C55E);
  static const _protein = Color(0xFF378ADD);
  static const _carbs   = Color(0xFFEF9F27);
  static const _fat     = Color(0xFFD4537E);

  bool get _isManual => widget.prefilled == null;

  @override
  void initState() {
    super.initState();
    // Pre-fill with AI results if available, else empty
    _foodNameCtrl = TextEditingController(
      text: widget.prefilled?.foodName ?? '',
    );
    _caloriesCtrl = TextEditingController(
      text: widget.prefilled != null ? '${widget.prefilled!.calories}' : '',
    );
    _proteinCtrl = TextEditingController(
      text: widget.prefilled != null ? '${widget.prefilled!.proteinG}' : '',
    );
    _carbsCtrl = TextEditingController(
      text: widget.prefilled != null ? '${widget.prefilled!.carbsG}' : '',
    );
    _fatCtrl = TextEditingController(
      text: widget.prefilled != null ? '${widget.prefilled!.fatG}' : '',
    );
  }

  @override
  void dispose() {
    _foodNameCtrl.dispose();
    _caloriesCtrl.dispose();
    _proteinCtrl.dispose();
    _carbsCtrl.dispose();
    _fatCtrl.dispose();
    super.dispose();
  }

  // ── Shared input decoration ──
  // Removed the 'label' parameter to eliminate the built-in floating label
  InputDecoration _decoration(String hint, {String? suffix}) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFFC2D1C5)),
    );
    return InputDecoration(
      hintText: hint,
      suffixText: suffix,
      border: border,
      enabledBorder: border,
      focusedBorder: border.copyWith(
        borderSide: const BorderSide(color: _green, width: 2),
      ),
      errorBorder: border.copyWith(
        borderSide: const BorderSide(color: Colors.red),
      ),
      focusedErrorBorder: border.copyWith(
        borderSide: const BorderSide(color: Colors.red, width: 2),
      ),
    );
  }

  // ── Integer validator ──
  String? _validateInt(String? value, String fieldName) {
    if (value == null || value.isEmpty) return 'Please enter $fieldName';
    if (int.tryParse(value) == null) return 'Must be a whole number';
    if (int.parse(value) < 0) return 'Cannot be negative';
    return null;
  }

  // ── Macro field row ──
  Widget _buildMacroField({
    required String label,
    required TextEditingController controller,
    required Color color,
    required String suffix,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: TextInputType.number,
          // Updated to only pass the hint text and suffix
          decoration: _decoration('e.g. 0', suffix: suffix),
          validator: (v) => _validateInt(v, label),
        ),
      ],
    );
  }

  Future<void> _onSave(BuildContext context) async {
    if (!_formKey.currentState!.validate()) return;

    final meal = MealResult(
      foodName: _foodNameCtrl.text.trim(),
      calories: int.parse(_caloriesCtrl.text),
      proteinG: int.parse(_proteinCtrl.text),
      carbsG:   int.parse(_carbsCtrl.text),
      fatG:     int.parse(_fatCtrl.text),
    );

    final vm      = context.read<MealScanViewModel>();
    final success = _isManual
        ? await vm.addManualMeal(meal)
        : await vm.confirmAndSave(meal);

    if (!context.mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Meal saved successfully!'),
          backgroundColor: _green,
        ),
      );
      vm.reset();
      Navigator.popUntil(context, (route) => route.isFirst);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(vm.errorMessage ?? 'Failed to save'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<MealScanViewModel>();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8FAFC),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _isManual ? 'ADD MEAL' : 'REVIEW & EDIT',
          style: const TextStyle(
            color: Colors.black87,
            fontSize: 13,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
        centerTitle: true,
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: vm.isSaving ? null : () => _onSave(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: _green,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              child: vm.isSaving
                  ? const SizedBox(
                height: 22,
                width: 22,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.5,
                ),
              )
                  : const Text(
                'Save Meal',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // ── Scanned image (scan flow only) ──
              if (widget.imageBytes != null) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.memory(
                    widget.imageBytes!,
                    width: double.infinity,
                    height: 200,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(height: 12),

                // AI notice banner
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _green.withValues(alpha: 0.4),
                    ),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.auto_awesome, size: 16, color: _green),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'AI has pre-filled these values. Review and edit before saving.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF166534),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // ── Manual entry header ──
              if (_isManual) ...[
                const Text(
                  'Meal Details',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Enter the nutritional information for your meal.',
                  style: TextStyle(fontSize: 13, color: Colors.black45),
                ),
                const SizedBox(height: 20),
              ],

              // ── Food Name ──
              const Text(
                'FOOD NAME',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF4A5568),
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _foodNameCtrl,
                textCapitalization: TextCapitalization.words,
                // Updated to only pass the hint text
                decoration: _decoration('e.g. Nasi Lemak'),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Please enter a food name'
                    : null,
              ),
              const SizedBox(height: 20),

              // ── Calories ──
              const Text(
                'CALORIES',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF4A5568),
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _caloriesCtrl,
                keyboardType: TextInputType.number,
                // Updated to only pass the hint text and suffix
                decoration: _decoration('e.g. 450', suffix: 'kcal'),
                validator: (v) => _validateInt(v, 'Calories'),
              ),
              const SizedBox(height: 20),

              // ── Macros header ──
              const Text(
                'MACRONUTRIENTS',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF4A5568),
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 12),

              // ── Protein ──
              _buildMacroField(
                label: 'Protein',
                controller: _proteinCtrl,
                color: _protein,
                suffix: 'g',
              ),
              const SizedBox(height: 14),

              // ── Carbs ──
              _buildMacroField(
                label: 'Carbohydrates',
                controller: _carbsCtrl,
                color: _carbs,
                suffix: 'g',
              ),
              const SizedBox(height: 14),

              // ── Fat ──
              _buildMacroField(
                label: 'Fat',
                controller: _fatCtrl,
                color: _fat,
                suffix: 'g',
              ),
              const SizedBox(height: 20),

              // ── Disclaimer ──
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.amber.shade200),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, size: 15, color: Colors.amber),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Once saved, this meal will be added to your history '
                            'and macros will count toward your daily totals.',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.black54,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}