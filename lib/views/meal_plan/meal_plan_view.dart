import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/meal_plan.dart';
import '../../viewmodels/meal_plan_viewmodel.dart';

class MealPlanView extends StatelessWidget {
  const MealPlanView({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => MealPlanViewModel(),
      child: const _MealPlanContent(),
    );
  }
}

class _MealPlanContent extends StatelessWidget {
  const _MealPlanContent();

  static const _bg = Color(0xFFF8FAFC);
  static const _green = Color(0xFF27A567);
  static const _slotColors = {
    'breakfast': Color(0xFFF59E0B),
    'lunch': Color(0xFF27A567),
    'dinner': Color(0xFF6366F1),
  };

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<MealPlanViewModel>();

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        leading: const BackButton(color: Colors.black87),
        title: const Text('Meal Plan',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black87)),
        actions: [
          if (!vm.isEmpty)
            IconButton(
              tooltip: 'Regenerate this week',
              icon: vm.isRefreshing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.refresh, color: Colors.black54),
              onPressed: vm.isRefreshing ? null : () => vm.refresh(),
            ),
        ],
      ),
      body: _body(context, vm),
    );
  }

  Widget _body(BuildContext context, MealPlanViewModel vm) {
    if (vm.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (vm.isEmpty) {
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
            child: _CuisineBar(vm: vm),
          ),
          Expanded(
            child: _EmptyState(
              busy: vm.isRefreshing,
              error: vm.error,
              onGenerate: () => vm.refresh(),
            ),
          ),
        ],
      );
    }

    final base = vm.plannedAt ?? DateTime.now();
    return RefreshIndicator(
      onRefresh: () => vm.refresh(),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 28),
        children: [
          _CuisineBar(vm: vm),
          const SizedBox(height: 6),
          const Text(
            'Pick the cuisines you want more of, then tap ↻ to regenerate.',
            style: TextStyle(fontSize: 11.5, color: Colors.black45),
          ),
          const SizedBox(height: 12),
          if (vm.error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(vm.error!,
                  style: const TextStyle(color: Colors.red, fontSize: 12.5)),
            ),
          Text(
            'Generated ${DateFormat('d MMM').format(base)} · '
            'Malaysian, macro-matched. Notifications fire at 8am / 12pm / 6pm.',
            style: const TextStyle(fontSize: 12, color: Colors.black54),
          ),
          const SizedBox(height: 12),
          ...vm.days.map((d) => _DayCard(
                day: d,
                date: DateTime(base.year, base.month, base.day + d.dayOffset),
                slotColors: _slotColors,
                accent: _green,
              )),
        ],
      ),
    );
  }
}

class _DayCard extends StatelessWidget {
  final DayPlan day;
  final DateTime date;
  final Map<String, Color> slotColors;
  final Color accent;

  const _DayCard({
    required this.day,
    required this.date,
    required this.slotColors,
    required this.accent,
  });

  String get _dayLabel {
    final today = DateTime.now();
    final d0 = DateTime(today.year, today.month, today.day);
    final diff = DateTime(date.year, date.month, date.day).difference(d0).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Tomorrow';
    return DateFormat('EEEE, d MMM').format(date);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
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
                child: Text(_dayLabel,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87)),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${day.totalCalories} kcal · P${day.totalProtein} C${day.totalCarbs} F${day.totalFat}',
                    style:
                        const TextStyle(fontSize: 11.5, color: Colors.black45),
                  ),
                  if (day.totalPriceLabel.isNotEmpty)
                    Text(
                      '~${day.totalPriceLabel} / day',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: accent),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...day.meals.map((m) => _mealRow(m)),
        ],
      ),
    );
  }

  Widget _mealRow(MealPlanItem m) {
    final color = slotColors[m.slot.toLowerCase()] ?? accent;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.only(top: 5),
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(m.slot.toUpperCase(),
                        style: TextStyle(
                            fontSize: 10,
                            letterSpacing: 0.5,
                            fontWeight: FontWeight.w700,
                            color: color)),
                    if (m.isWildcard) ...[
                      const SizedBox(width: 6),
                      const Text('🎲 treat',
                          style: TextStyle(fontSize: 10, color: Colors.black45)),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(m.name,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87)),
                if (m.description.isNotEmpty)
                  Text(m.description,
                      style: const TextStyle(
                          fontSize: 12, color: Colors.black54, height: 1.3)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${m.calories} kcal',
                  style: const TextStyle(fontSize: 11, color: Colors.black45)),
              if (m.priceLabel.isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(m.priceLabel,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: color)),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// Horizontal multi-select chips for the cuisine preference. Toggling persists
/// the choice (via the ViewModel) but doesn't regenerate until the user asks.
class _CuisineBar extends StatelessWidget {
  final MealPlanViewModel vm;
  const _CuisineBar({required this.vm});

  static const _green = Color(0xFF27A567);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 34,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          // "Mixed" = balanced spread; selected whenever no cuisine is picked.
          _chip('Mixed', vm.cuisines.isEmpty, () => vm.setMixed()),
          for (final c in MealPlanViewModel.cuisineOptions)
            _chip(c, vm.cuisines.contains(c), () => vm.toggleCuisine(c)),
        ],
      ),
    );
  }

  Widget _chip(String label, bool selected, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: selected ? _green : Colors.white,
            borderRadius: BorderRadius.circular(17),
            border: Border.all(color: selected ? _green : Colors.grey.shade300),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: selected ? Colors.white : Colors.black54,
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final bool busy;
  final String? error;
  final VoidCallback onGenerate;

  const _EmptyState({
    required this.busy,
    required this.error,
    required this.onGenerate,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.restaurant_menu,
                size: 44, color: Color(0xFF27A567)),
            const SizedBox(height: 16),
            const Text('No meal plan yet',
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87)),
            const SizedBox(height: 8),
            const Text(
              'Generate a week of Malaysian meals matched to your macro targets. '
              'They’ll be scheduled as offline reminders at 8am, 12pm and 6pm.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.black54, height: 1.4),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: busy ? null : onGenerate,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF27A567),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: busy
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2.5))
                    : const Text('Generate my week',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15)),
              ),
            ),
            if (error != null) ...[
              const SizedBox(height: 12),
              Text(error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red, fontSize: 12.5)),
            ],
          ],
        ),
      ),
    );
  }
}
