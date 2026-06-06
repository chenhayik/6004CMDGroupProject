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

  Widget _buildActionButtons(BuildContext context, MealScanViewModel vm) {
    final bool isProcessing = vm.scanState == MealScanState.analysing ||
        vm.scanState == MealScanState.picking;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _PrimaryActionButton(
                icon:    Icons.camera_alt,
                label:   'Take Photo',
                color:   _green,
                enabled: !isProcessing,
                onTap:   () async {
                  await vm.pickFromCamera(context);
                  if (context.mounted) _handleStateChange(context, vm);
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _PrimaryActionButton(
                icon:    Icons.photo_library_outlined,
                label:   'Upload Photo',
                color:   _blue,
                enabled: !isProcessing,
                onTap:   () async {
                  await vm.pickFromGallery(context);
                  if (context.mounted) _handleStateChange(context, vm);
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        GestureDetector(
          onTap: isProcessing
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
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.edit_outlined, size: 18, color: Colors.black54),
                SizedBox(width: 8),
                Text(
                  'Add Meal Manually',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.black54,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
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

        if (diff == 0)      label = 'Today';
        else if (diff == 1) label = 'Yesterday';
        else                label = DateFormat('EEEE, MMM d').format(date);
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
              'Meal History',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            if (vm.isLoadingHistory)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
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
                    onDelete: meal.id != null
                        ? () => vm.deleteMeal(meal.id!)
                        : null,
                    onTap: () => _showMealOptions(context, vm, meal),
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Icon(Icons.restaurant_outlined, size: 40, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          const Text(
            'No meals logged yet',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.black54),
          ),
          const SizedBox(height: 4),
          const Text(
            'Take a photo to get started',
            style: TextStyle(fontSize: 12, color: Colors.black38),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<MealScanViewModel>();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8FAFC),
        elevation: 0,
        title: const Text(
          'SNAP & TRACK',
          style: TextStyle(
            color: Colors.black87,
            fontSize: 14,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.black87),
            onPressed: vm.loadHistory,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF22C55E), Color(0xFF16A34A)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'AI Meal Scanner',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Snap your food and get instant macro breakdown powered by Gemini AI',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Icon(Icons.document_scanner_outlined, color: Colors.white, size: 40),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _buildActionButtons(context, vm),
            const SizedBox(height: 12),
            AnimatedSize(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              child: Column(
                children: [
                  if (vm.scanState == MealScanState.analysing) ...[
                    _buildLoadingCard(),
                    const SizedBox(height: 12),
                  ],
                  if (vm.scanState == MealScanState.error && vm.errorMessage != null) ...[
                    _buildErrorCard(vm.errorMessage!, vm.reset),
                    const SizedBox(height: 12),
                  ],
                ],
              ),
            ),
            _buildHistorySection(context, vm),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

// ─── Primary Button ─────────────────────────────────────────
class _PrimaryActionButton extends StatelessWidget {
  final IconData icon;
  final String   label;
  final Color    color;
  final bool     enabled;
  final VoidCallback onTap;

  const _PrimaryActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: enabled ? 1.0 : 0.5,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 18),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(enabled ? 0.3 : 0.0),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              Icon(icon, color: Colors.white, size: 28),
              const SizedBox(height: 6),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── History Card ────────────────────────────────────────────
class _MealHistoryCard extends StatelessWidget {
  final MealResult    meal;
  final VoidCallback? onDelete;
  final VoidCallback  onTap;

  const _MealHistoryCard({
    required this.meal,
    required this.onTap,
    this.onDelete,
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
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFFDCFCE7),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.restaurant, color: Color(0xFF22C55E), size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          meal.foodName,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        timeLabel,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.black38,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: [
                      _MacroPill(label: '${meal.calories} kcal', color: const Color(0xFF22C55E)),
                      _MacroPill(label: 'P ${meal.proteinG}g',   color: const Color(0xFF378ADD)),
                      _MacroPill(label: 'C ${meal.carbsG}g',     color: const Color(0xFFEF9F27)),
                      _MacroPill(label: 'F ${meal.fatG}g',       color: const Color(0xFFD4537E)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, size: 18, color: Colors.black26),
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
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}