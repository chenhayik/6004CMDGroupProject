import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../viewmodels/meal_scan_viewmodel.dart';
import '../../../models/meal_result.dart';
import '../meal_scan/meal_edit_view.dart';

class MealScanView extends StatelessWidget {
  const MealScanView({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => MealScanViewModel(),
      child: const _MealScanContent(),
    );
  }
}

class _MealScanContent extends StatelessWidget {
  const _MealScanContent();

  static const _green = Color(0xFF22C55E);
  static const _blue  = Color(0xFF378ADD);
  static const _bg    = Color(0xFFF8FAFC);

  void _handleStateChange(BuildContext context, MealScanViewModel vm) {
    if (vm.scanState == MealScanState.success &&
        vm.lastResult != null &&
        vm.selectedImageBytes != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChangeNotifierProvider.value(
            value: vm,
            child: MealEditView(
              prefilled:  vm.lastResult,
              imageBytes: vm.selectedImageBytes,
            ),
          ),
        ),
      );
    }
  }

  bool _isProcessing(MealScanViewModel vm) =>
      vm.scanState == MealScanState.analysing ||
      vm.scanState == MealScanState.picking;

  // ─── Hero: Snap & Track (AI) ─────────────────────────────────
  Widget _buildSnapCard(BuildContext context, MealScanViewModel vm) {
    final processing = _isProcessing(vm);
    return GestureDetector(
      onTap: processing ? null : () => _showSourcePicker(context, vm),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF22C55E), Color(0xFF15803D)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: _green.withValues(alpha: 0.3),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.25),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.camera_alt, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Snap & Track (AI)',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Auto-log your food instantly',
                    style: TextStyle(fontSize: 12, color: Colors.white),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white, size: 22),
          ],
        ),
      ),
    );
  }

  // ─── Log Manually card ───────────────────────────────────────
  Widget _buildManualCard(BuildContext context, MealScanViewModel vm) {
    final processing = _isProcessing(vm);
    return GestureDetector(
      onTap: processing
          ? null
          : () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ChangeNotifierProvider.value(
                    value: vm,
                    child: const MealEditView(),
                  ),
                ),
              ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                color: Color(0xFFF1F5F9),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.edit_outlined,
                  color: Colors.black54, size: 19),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Log Manually',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'ACCURATE',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: Colors.black54,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Enter your food and macros yourself',
                    style: TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.black26, size: 22),
          ],
        ),
      ),
    );
  }

  // ─── Source picker (camera / gallery) ────────────────────────
  void _showSourcePicker(BuildContext context, MealScanViewModel vm) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Snap & Track',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFDCFCE7),
                  child: Icon(Icons.camera_alt, color: _green),
                ),
                title: const Text('Take Photo'),
                subtitle: const Text('Use your camera'),
                onTap: () async {
                  Navigator.pop(sheetContext);
                  await vm.pickFromCamera(context);
                  if (context.mounted) _handleStateChange(context, vm);
                },
              ),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFEFF6FF),
                  child: Icon(Icons.photo_library_outlined, color: _blue),
                ),
                title: const Text('Choose from Gallery'),
                subtitle: const Text('Pick an existing photo'),
                onTap: () async {
                  Navigator.pop(sheetContext);
                  await vm.pickFromGallery(context);
                  if (context.mounted) _handleStateChange(context, vm);
                },
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLoadingCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          const CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation(_green),
            strokeWidth: 3,
          ),
          const SizedBox(height: 16),
          const Text(
            'Analysing your meal...',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            'Gemini AI is identifying the food and calculating macros',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorCard(String message, VoidCallback onDismiss) {
    return Container(
      padding: const EdgeInsets.only(left: 16, top: 8, bottom: 8, right: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(fontSize: 12, color: Colors.red),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18, color: Colors.red),
            onPressed: onDismiss,
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
          ),
        ],
      ),
    );
  }

  // ── Groups history by date label ──
  Map<String, List<MealResult>> _groupByDate(List<MealResult> meals) {
    final Map<String, List<MealResult>> groups = {};
    final now   = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    for (final meal in meals) {
      final String label;

      if (meal.loggedAt == null) {
        label = 'Today';
      } else {
        final date = DateTime(
          meal.loggedAt!.year,
          meal.loggedAt!.month,
          meal.loggedAt!.day,
        );
        final diff = today.difference(date).inDays;

        if (diff == 0) {
          label = 'Today';
        } else if (diff == 1) {
          label = 'Yesterday';
        } else {
          label = DateFormat('EEEE, MMM d').format(date);
        }
      }

      groups.putIfAbsent(label, () => []).add(meal);
    }
    return groups;
  }

  Widget _buildHistorySection(BuildContext context, MealScanViewModel vm) {
    if (vm.mealHistory.isEmpty && !vm.isLoadingHistory) {
      return _buildEmptyHistory();
    }

    final grouped = _groupByDate(vm.mealHistory);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Recent Meals',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            if (vm.isLoadingHistory)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              TextButton(
                onPressed: vm.loadHistory,
                style: TextButton.styleFrom(
                  foregroundColor: _green,
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 0),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(
                  'REFRESH',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),

        ...grouped.entries.map((entry) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Date group header ──
              Padding(
                padding: const EdgeInsets.only(bottom: 8, top: 4),
                child: Text(
                  entry.key,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade500,
                    letterSpacing: 0.5,
                  ),
                ),
              ),

              // ── Meals in this group ──
              ...entry.value.map(
                (meal) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _MealHistoryCard(
                    meal: meal,
                    onTap: () => _showMealOptions(context, vm, meal),
                    onQuickLog: () async {
                      final ok = await vm.reLogMeal(meal);
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            ok
                                ? '${meal.foodName} logged again!'
                                : 'Failed to log meal',
                          ),
                          backgroundColor: ok ? _green : Colors.red,
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          );
        }),
      ],
    );
  }

  // ── Bottom sheet: Log Again / Log with Edits / Delete ──
  void _showMealOptions(
      BuildContext context,
      MealScanViewModel vm,
      MealResult meal,
      ) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              // Handle bar
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),

              // Meal name header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFFDCFCE7),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.restaurant,
                        color: Color(0xFF22C55E),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            meal.foodName,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            '${meal.calories} kcal · P${meal.proteinG}g · C${meal.carbsG}g · F${meal.fatG}g',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.black45,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Divider(height: 1),

              // ── Log Again ──
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFDCFCE7),
                  child: Icon(Icons.add, color: Color(0xFF22C55E), size: 20),
                ),
                title: const Text(
                  'Log Again',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: const Text(
                  'Add same meal to today\'s totals',
                  style: TextStyle(fontSize: 12),
                ),
                onTap: () async {
                  Navigator.pop(sheetContext);
                  final success = await vm.reLogMeal(meal);
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        success
                            ? '${meal.foodName} logged!'
                            : 'Failed to log meal',
                      ),
                      backgroundColor:
                      success ? const Color(0xFF22C55E) : Colors.red,
                    ),
                  );
                },
              ),

              // ── Log with Edits ──
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFEFF6FF),
                  child: Icon(Icons.edit_outlined, color: Color(0xFF378ADD), size: 20),
                ),
                title: const Text(
                  'Log with Edits',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: const Text(
                  'Adjust portion or macros before saving',
                  style: TextStyle(fontSize: 12),
                ),
                onTap: () {
                  Navigator.pop(sheetContext);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChangeNotifierProvider.value(
                        value: vm,
                        child: MealEditView(
                          prefilled: meal,   // pre-fill with history values
                          // no imageBytes — this is from history not a scan
                        ),
                      ),
                    ),
                  );
                },
              ),

              // ── Delete ──
              if (meal.id != null)
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFFEF2F2),
                    child: Icon(Icons.delete_outline, color: Colors.red, size: 20),
                  ),
                  title: const Text(
                    'Delete',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.red,
                    ),
                  ),
                  subtitle: const Text(
                    'Remove this entry from history',
                    style: TextStyle(fontSize: 12),
                  ),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    vm.deleteMeal(meal.id!);
                  },
                ),

              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyHistory() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Recent Meals',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            children: [
              Icon(Icons.restaurant_outlined,
                  size: 40, color: Colors.grey.shade300),
              const SizedBox(height: 12),
              const Text(
                'No meals logged yet',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.black54),
              ),
              const SizedBox(height: 4),
              const Text(
                'Snap a photo to get started',
                style: TextStyle(fontSize: 12, color: Colors.black38),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<MealScanViewModel>();

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        foregroundColor: Colors.black87,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.black87),
            onPressed: vm.loadHistory,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──
            const Text(
              'Log Your Meal',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Choose how you want to track your nutrition today.',
              style: TextStyle(fontSize: 14, color: Colors.black54, height: 1.4),
            ),
            const SizedBox(height: 20),

            // ── Snap & Track (AI) hero ──
            _buildSnapCard(context, vm),
            const SizedBox(height: 14),

            // ── Log Manually ──
            _buildManualCard(context, vm),
            const SizedBox(height: 14),

            // ── Loading / Error feedback ──
            AnimatedSize(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              child: Column(
                children: [
                  if (vm.scanState == MealScanState.analysing) ...[
                    _buildLoadingCard(),
                    const SizedBox(height: 14),
                  ],
                  if (vm.scanState == MealScanState.error &&
                      vm.errorMessage != null) ...[
                    _buildErrorCard(vm.errorMessage!, vm.reset),
                    const SizedBox(height: 14),
                  ],
                ],
              ),
            ),

            // ── Recent Meals (history) ──
            _buildHistorySection(context, vm),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

// ─── History Card ────────────────────────────────────────────
class _MealHistoryCard extends StatelessWidget {
  final MealResult    meal;
  final VoidCallback  onTap;
  final VoidCallback  onQuickLog;

  const _MealHistoryCard({
    required this.meal,
    required this.onTap,
    required this.onQuickLog,
  });

  @override
  Widget build(BuildContext context) {
    final timeLabel = meal.loggedAt != null
        ? DateFormat('h:mm a').format(meal.loggedAt!)
        : 'Just now';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFFDCFCE7),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.restaurant,
                  color: Color(0xFF22C55E), size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    meal.foodName,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  // Calories + time — mirrors the "320 kcal • Breakfast" line
                  Text(
                    '${meal.calories} kcal · $timeLabel',
                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                  const SizedBox(height: 6),
                  // Full macro breakdown retained from history
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: [
                      _MacroPill(
                          label: 'P ${meal.proteinG}g',
                          color: const Color(0xFF378ADD)),
                      _MacroPill(
                          label: 'C ${meal.carbsG}g',
                          color: const Color(0xFFEF9F27)),
                      _MacroPill(
                          label: 'F ${meal.fatG}g',
                          color: const Color(0xFFD4537E)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Quick "+" re-log button (from the mockup)
            GestureDetector(
              onTap: onQuickLog,
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF22C55E), width: 1.2),
                ),
                child: const Icon(Icons.add,
                    color: Color(0xFF22C55E), size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MacroPill extends StatelessWidget {
  final String label;
  final Color  color;

  const _MacroPill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}
