import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/macro_calculator_viewmodel.dart';
import '../home/home_view.dart';

class MacroCalculatorView extends StatelessWidget {
  final Map<String, dynamic> formData;

  const MacroCalculatorView({super.key, required this.formData});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => MacroCalculatorViewModel(formData: formData),
      child: const _MacroCalculatorContent(),
    );
  }
}

class _MacroCalculatorContent extends StatelessWidget {
  const _MacroCalculatorContent();

  // ── Theme colors ──
  static const _primaryGreen  = Color(0xFF22C55E);
  static const _proteinColor  = Color(0xFF378ADD);
  static const _carbColor     = Color(0xFFEF9F27);
  static const _fatColor      = Color(0xFFD4537E);

  // ── Macro tab row ──
  Widget _buildMacroTabs(MacroCalculatorViewModel vm) {
    return Row(
      children: MacroRatio.values.map((r) {
        final isActive = r == vm.macroRatio;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              right: r != MacroRatio.values.last ? 8 : 0,
            ),
            child: GestureDetector(
              onTap: () => vm.onMacroRatioChanged(r),   // ← ViewModel call
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: isActive ? _primaryGreen : Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isActive ? _primaryGreen : const Color(0xFFC2D1C5),
                  ),
                ),
                child: Text(
                  r.label.split(' ').join('\n'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight:
                    isActive ? FontWeight.bold : FontWeight.normal,
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

  // ── Single macro row card ──
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
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                name,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF4A5568),
                ),
              ),
            ],
          ),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: '$grams ',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const TextSpan(
                  text: 'g',
                  style: TextStyle(fontSize: 14, color: Colors.black54),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _onCompleteSetup(
      BuildContext context,
      MacroCalculatorViewModel vm,
      ) async {
    final success = await vm.completeSetup();

    if (!context.mounted) return;

    if (success) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const HomeView()),
            (route) => false,
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(vm.errorMessage ?? 'Unknown error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<MacroCalculatorViewModel>();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const BackButton(color: Colors.black87),
        title: const Text(
          'SETUP PROFILE',
          style: TextStyle(
            color: Colors.black87,
            fontSize: 14,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.0,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // ── Scrollable content ──
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Your Nutrition Targets',
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF4A5568),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    "We've calculated these baseline metrics based on your "
                        'profile and primary goal. You can adjust your macro split below.',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.black54,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // ── TDEE vs Target cards ──
                  Row(
                    children: [
                      Expanded(
                        child: _SummaryCard(
                          title: 'Daily Energy',
                          value: '${vm.tdee}',
                          unit: 'kcal',
                          subtitle: 'Maintenance',
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _SummaryCard(
                          title: 'Your Target',
                          value: '${vm.targetCalories}',
                          unit: 'kcal',
                          subtitle: vm.formData['goal']
                              .toString()
                              .toUpperCase(),
                          highlight: true,
                        ),
                      ),
                    ],
                  ),

                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24.0),
                    child: Divider(color: Color(0xFFC2D1C5)),
                  ),

                  // ── Macro ratio selector ──
                  const Text(
                    'PREFERRED DIET TYPE',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF4A5568),
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildMacroTabs(vm),
                  const SizedBox(height: 32),

                  // ── Macro breakdown ──
                  _buildMacroDetailCard('Protein', vm.proteinG, _proteinColor),
                  const SizedBox(height: 12),
                  _buildMacroDetailCard('Carbohydrates', vm.carbsG, _carbColor),
                  const SizedBox(height: 12),
                  _buildMacroDetailCard('Fat', vm.fatG, _fatColor),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),

          // ── Sticky bottom button ──
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
                  onPressed: vm.isLoading
                      ? null
                      : () => _onCompleteSetup(context, vm),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryGreen,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: vm.isLoading
                      ? const SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 3,
                    ),
                  )
                      : const Text(
                    'Complete Setup →',
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

// ── Reusable summary card ──
class _SummaryCard extends StatelessWidget {
  final String title, value, unit, subtitle;
  final bool highlight;

  const _SummaryCard({
    required this.title,
    required this.value,
    required this.unit,
    required this.subtitle,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: highlight
            ? const Color(0xFFF0FDF4)
            : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: highlight
              ? const Color(0xFF22C55E)
              : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: highlight
                  ? const Color(0xFF22C55E)
                  : Colors.black54,
            ),
          ),
          const SizedBox(height: 8),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: '$value ',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: highlight
                        ? const Color(0xFF22C55E)
                        : Colors.black87,
                  ),
                ),
                TextSpan(
                  text: unit,
                  style: TextStyle(
                    fontSize: 14,
                    color: highlight
                        ? const Color(0xFF22C55E).withOpacity(0.8)
                        : Colors.black54,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 12, color: Colors.black45),
          ),
        ],
      ),
    );
  }
}