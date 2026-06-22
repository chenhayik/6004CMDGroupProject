import 'package:flutter/material.dart';

import 'package:mobile_application_group/views/macros/macro_calculator_view.dart';


class SelectGoalView extends StatefulWidget {
  final Map<String, dynamic> formData;

  const SelectGoalView({super.key, required this.formData});

  @override
  State<SelectGoalView> createState() => _SelectGoalViewState();
}

class _SelectGoalViewState extends State<SelectGoalView> {
  String? _selectedGoal;
  final bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Preselect the saved goal when editing from the Profile hub.
    _selectedGoal = widget.formData['goal']?.toString();
  }

  final List<Map<String, dynamic>> _goals = [
    {
      'value': 'cut',
      'title': 'Cut',
      'subtitle': 'Caloric Deficit',
      'icon': Icons.water_drop_outlined,
    },
    {
      'value': 'maintain',
      'title': 'Maintain',
      'subtitle': 'Current Weight',
      'icon': Icons.balance_outlined,
    },
    {
      'value': 'bulk',
      'title': 'Bulk',
      'subtitle': 'Caloric Surplus',
      'icon': Icons.fitness_center_outlined,
    },
  ];

  Widget _buildGoalCard(Map<String, dynamic> goal) {
    final bool isSelected = _selectedGoal == goal['value'];

    return GestureDetector(
      onTap: () => setState(() => _selectedGoal = goal['value']),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        decoration: BoxDecoration(
          // Uses the light grey/green from your previous screens
          border: Border.all(
            color: isSelected ? const Color(0xFF22C55E) : const Color(0xFFC2D1C5),
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
          color: isSelected ? const Color(0xFFF0FDF4) : Colors.white, // Slight green tint when selected
        ),
        child: Row(
          children: [
            Icon(
              goal['icon'],
              size: 28,
              color: isSelected ? const Color(0xFF22C55E) : Colors.black54,
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  goal['title'],
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? const Color(0xFF22C55E) : const Color(0xFF4A5568),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  goal['subtitle'],
                  style: TextStyle(
                    fontSize: 13,
                    color: isSelected ? const Color(0xFF22C55E).withOpacity(0.8) : Colors.black54,
                  ),
                ),
              ],
            ),
            const Spacer(),
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? const Color(0xFF22C55E) : Colors.transparent,
                border: Border.all(
                  color: isSelected ? const Color(0xFF22C55E) : const Color(0xFFC2D1C5),
                ),
              ),
              child: isSelected
                  ? const Icon(Icons.check, size: 16, color: Colors.white)
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _onNext() async {
    if (_selectedGoal == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a goal to continue.')),
      );
      return;
    }

    // ── Merge goal into formData and navigate ──
    // No loading state needed here — CalorieCalculatorPage handles its own
    final updatedFormData = Map<String, dynamic>.from(widget.formData);
    updatedFormData['goal'] = _selectedGoal;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MacroCalculatorView(formData: updatedFormData),  // ← renamed
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const BackButton(color: Colors.black87), // Changed to black for light mode
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (index) {
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: index == 2 ? 40 : 12, // Highlights step 3
              height: 6,
              decoration: BoxDecoration(
                color: index == 2
                    ? const Color(0xFF22C55E)
                    : const Color(0xFFC2D1C5), // Light grey for incomplete steps
                borderRadius: BorderRadius.circular(3),
              ),
            );
          }),
        ),
      ),
      body: Column(
        children: [
          // 1. Scrollable Content Area
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "What's your\nprimary goal?",
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF4A5568),
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Select a path below so we can accurately calculate your daily macros and tailor your fitness journey.',
                    style: TextStyle(fontSize: 14, color: Colors.black54, height: 1.4),
                  ),
                  const SizedBox(height: 32),
                  ..._goals.map(_buildGoalCard),
                ],
              ),
            ),
          ),

          // 2. Sticky Bottom Button Area
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  offset: const Offset(0, -4),
                  blurRadius: 8,
                ),
              ],
            ),
            child: SafeArea(
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _onNext,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF22C55E),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 3,
                    ),
                  )
                      : const Text(
                    'Next →',
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
        ],
      ),
    );
  }
}