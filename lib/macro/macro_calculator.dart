import 'dart:math';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_profile.dart';

import '../../../services/firestore_service.dart';
import 'package:mobile_application_group/views/home/home_page.dart';

enum MacroRatio { balanced, highProtein, lowCarb, highCarb }

extension MacroRatioExt on MacroRatio {
  String get label {
    switch (this) {
      case MacroRatio.balanced: return 'Balanced';
      case MacroRatio.highProtein: return 'High Protein';
      case MacroRatio.lowCarb: return 'Low Carb';
      case MacroRatio.highCarb: return 'High Carb';
    }
  }

  (double, double, double) get split {
    switch (this) {
      case MacroRatio.balanced: return (0.30, 0.40, 0.30);
      case MacroRatio.highProtein: return (0.40, 0.35, 0.25);
      case MacroRatio.lowCarb: return (0.35, 0.20, 0.45);
      case MacroRatio.highCarb: return (0.25, 0.50, 0.25);
    }
  }
}

// ─────────────────────────────────────────────
//  PAGE STATE
// ─────────────────────────────────────────────

class CalorieCalculatorPage extends StatefulWidget {
  final Map<String, dynamic> formData;

  const CalorieCalculatorPage({super.key, required this.formData});

  @override
  State<CalorieCalculatorPage> createState() => _CalorieCalculatorPageState();
}

class _CalorieCalculatorPageState extends State<CalorieCalculatorPage> {
  bool _isLoading = false;
  MacroRatio _macroRatio = MacroRatio.balanced;
  late Map<String, dynamic> _results;

  // Theme Colors
  final Color _primaryGreen = const Color(0xFF22C55E);
  final Color _kProteinColor = const Color(0xFF378ADD);
  final Color _kCarbColor = const Color(0xFFEF9F27);
  final Color _kFatColor = const Color(0xFFD4537E);

  @override
  void initState() {
    super.initState();
    _calculateTargets();
  }

  void _calculateTargets() {
    // 1. Extract base metrics from previous screens
    final double weight = double.tryParse(widget.formData['weight'].toString()) ?? 70.0;
    final double height = double.tryParse(widget.formData['height'].toString()) ?? 170.0;
    final double age = double.tryParse(widget.formData['age'].toString()) ?? 30.0;
    final String sex = widget.formData['biologicalSex'].toString().toLowerCase();
    final String activityStr = widget.formData['activityLevel'].toString().toLowerCase();
    final String goal = widget.formData['goal'].toString().toLowerCase();

    // 2. Determine Activity Multiplier
    double multiplier = 1.2; // Default Sedentary
    if (activityStr.contains('light')) multiplier = 1.375;
    if (activityStr.contains('moderate')) multiplier = 1.55;
    if (activityStr.contains('very')) multiplier = 1.725;
    if (activityStr.contains('extra')) multiplier = 1.9;

    // 3. Calculate BMR & TDEE
    final double bmr = sex == 'male'
        ? (10 * weight) + (6.25 * height) - (5 * age) + 5
        : (10 * weight) + (6.25 * height) - (5 * age) - 161;
    final double tdee = bmr * multiplier;

    // 4. Apply Goal adjustments
    double targetCalories = tdee;
    if (goal == 'cut') {
      targetCalories = tdee - 500; // Standard 500 kcal deficit
    } else if (goal == 'bulk') {
      targetCalories = tdee + 300; // Lean 300 kcal surplus
    }

    // Ensure calories don't drop to dangerous levels (e.g., minimum 1200 for women, 1500 for men)
    final double minCalories = sex == 'male' ? 1500 : 1200;
    targetCalories = max(targetCalories, minCalories);

    // 5. Calculate Macros based on selected ratio
    final (pPct, cPct, fPct) = _macroRatio.split;
    final double proteinG = (targetCalories * pPct) / 4;
    final double carbsG = (targetCalories * cPct) / 4;
    final double fatG = (targetCalories * fPct) / 9;

    setState(() {
      _results = {
        'bmr': bmr.round(),
        'tdee': tdee.round(),
        'targetCalories': targetCalories.round(),
        'proteinG': proteinG.round(),
        'carbsG': carbsG.round(),
        'fatG': fatG.round(),
        'proteinKcal': targetCalories * pPct,
        'carbsKcal': targetCalories * cPct,
        'fatKcal': targetCalories * fPct,
      };
    });
  }

  Future<void> _onCompleteSetup() async {
    setState(() => _isLoading = true);

    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;

      // Bundle everything together
      final profile = UserProfile(
        uid: uid,
        age: widget.formData['age'],
        biologicalSex: widget.formData['biologicalSex'],
        height: widget.formData['height'],
        weight: widget.formData['weight'],
        activityLevel: widget.formData['activityLevel'],
        goal: widget.formData['goal'],
      );

      await FirestoreService().createUserProfile(profile);

      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const HomePage()),
              (route) => false,
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving profile: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const BackButton(color: Colors.black87),
        title: const Text(
          'SETUP PROFILE',
          style: TextStyle(color: Colors.black87, fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1.0),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // 1. Scrollable Details Area
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Your Nutrition Targets",
                    style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: Color(0xFF4A5568)),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    "We've calculated these baseline metrics based on your profile and primary goal. You can adjust your macro split below.",
                    style: TextStyle(fontSize: 14, color: Colors.black54, height: 1.4),
                  ),
                  const SizedBox(height: 32),

                  // TDEE and Target Summary Row
                  Row(
                    children: [
                      Expanded(
                        child: _SummaryCard(
                          title: 'Daily Energy',
                          value: '${_results['tdee']}',
                          unit: 'kcal',
                          subtitle: 'Maintenance',
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _SummaryCard(
                          title: 'Your Target',
                          value: '${_results['targetCalories']}',
                          unit: 'kcal',
                          subtitle: widget.formData['goal'].toString().toUpperCase(),
                          highlight: true,
                        ),
                      ),
                    ],
                  ),

                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24.0),
                    child: Divider(color: Color(0xFFC2D1C5)),
                  ),

                  // Interactive Macro Split Selector
                  const Text(
                    "PREFFERED DIET TYPE",
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF4A5568), letterSpacing: 0.5),
                  ),
                  const SizedBox(height: 12),
                  _buildMacroTabs(),

                  const SizedBox(height: 32),

                  // Final Output Macros
                  _buildMacroDetailCard('Protein', _results['proteinG'], _kProteinColor),
                  const SizedBox(height: 12),
                  _buildMacroDetailCard('Carbohydrates', _results['carbsG'], _kCarbColor),
                  const SizedBox(height: 12),
                  _buildMacroDetailCard('Fat', _results['fatG'], _kFatColor),
                ],
              ),
            ),
          ),

          // 2. Sticky Bottom Complete Button
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.05), offset: const Offset(0, -4), blurRadius: 8),
              ],
            ),
            child: SafeArea(
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _onCompleteSetup,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryGreen,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  ),
                  child: _isLoading
                      ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                      : const Text(
                    'Complete Setup →',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- Helper UI Widgets ---

  Widget _buildMacroTabs() {
    return Row(
      children: MacroRatio.values.map((r) {
        final isActive = r == _macroRatio;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: r != MacroRatio.values.last ? 8 : 0),
            child: GestureDetector(
              onTap: () {
                setState(() => _macroRatio = r);
                _calculateTargets(); // Recalculate grams when split changes
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: isActive ? _primaryGreen : Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: isActive ? _primaryGreen : const Color(0xFFC2D1C5)),
                ),
                child: Text(
                  r.label.split(' ').join('\n'), // Splits "High Protein" to two lines for narrow screens
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                    color: isActive ? Colors.white : Colors.black54,
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildMacroDetailCard(String name, int grams, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFC2D1C5)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
              const SizedBox(width: 12),
              Text(name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF4A5568))),
            ],
          ),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(text: '$grams ', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                const TextSpan(text: 'g', style: TextStyle(fontSize: 14, color: Colors.black54)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String title, value, unit, subtitle;
  final bool highlight;

  const _SummaryCard({
    required this.title, required this.value, required this.unit, required this.subtitle, this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: highlight ? const Color(0xFFF0FDF4) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: highlight ? const Color(0xFF22C55E) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: highlight ? const Color(0xFF22C55E) : Colors.black54)),
          const SizedBox(height: 8),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(text: '$value ', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: highlight ? const Color(0xFF22C55E) : Colors.black87)),
                TextSpan(text: unit, style: TextStyle(fontSize: 14, color: highlight ? const Color(0xFF22C55E).withOpacity(0.8) : Colors.black54)),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.black45)),
        ],
      ),
    );
  }
}