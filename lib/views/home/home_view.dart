import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../viewmodels/home_viewmodel.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../widget_tree.dart';
import '../meal_scan/meal_scan_view.dart';

class HomeView extends StatelessWidget {
  const HomeView({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => HomeViewModel(),
      child: const _HomeContent(),
    );
  }
}

class _HomeContent extends StatelessWidget {
  const _HomeContent();

  static const _green        = Color(0xFF22C55E);
  static const _proteinColor = Color(0xFF378ADD);
  static const _carbColor    = Color(0xFFEF9F27);
  static const _fatColor     = Color(0xFFEF9F27);
  static const _bgColor      = Color(0xFFF8FAFC);
  static const _cardColor    = Colors.white;

  String get _todayLabel =>
      DateFormat('EEEE, MMM d').format(DateTime.now()).toUpperCase();

  // ─── Insight Banner ───────────────────────────────────────
  Widget _buildBanner(BuildContext context, HomeViewModel vm) {
    if (!vm.showInsightBanner) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(bottom: 2),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.bolt, size: 18, color: Colors.black87),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Boost Your Protein',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  vm.insightMessage,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.black54,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: vm.dismissInsightBanner,
            child: const Icon(Icons.close, size: 16, color: Colors.black38),
          ),
        ],
      ),
    );
  }

  // ─── Calorie Ring ─────────────────────────────────────────
  Widget _buildCalorieRing(HomeViewModel vm) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Calories',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Color(0xFF64748B),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: 120,
            height: 120,
            child: Stack(
              fit: StackFit.expand,
              children: [
                const CircularProgressIndicator(
                  value: 1.0,
                  strokeWidth: 10,
                  color: Color(0xFFF1F5F9),
                ),
                CircularProgressIndicator(
                  value: vm.calorieProgress,
                  strokeWidth: 10,
                  backgroundColor: Colors.transparent,
                  color: _green,
                  strokeCap: StrokeCap.round,
                ),
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        NumberFormat('#,###').format(vm.consumedCalories),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      Text(
                        '/ ${vm.targetCalories}',
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
          const SizedBox(height: 10),
          Text(
            vm.caloriesLeft >= 0
                ? '${vm.caloriesLeft} kcal left'
                : '${vm.caloriesLeft.abs()} kcal over',
            style: const TextStyle(fontSize: 12, color: Colors.black45),
          ),
        ],
      ),
    );
  }

  // ─── Protein / Carbs side cards ───────────────────────────
  Widget _buildMacroSideCard({
    required String label,
    required int consumed,
    required int target,
    required double progress,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 4),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: '$consumed',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                TextSpan(
                  text: '/${target}g',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.black45,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 5,
              backgroundColor: const Color(0xFFF1F5F9),
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${(progress * 100).toInt()}%',
            style: TextStyle(fontSize: 11, color: color),
          ),
        ],
      ),
    );
  }

  // ─── Fat bar card ─────────────────────────────────────────
  Widget _buildFatCard(HomeViewModel vm) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Fat',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF64748B),
                ),
              ),
              Row(
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    size: 13,
                    color: vm.isFatOnTrack ? _green : Colors.red,
                  ),
                  const SizedBox(width: 3),
                  Text(
                    vm.isFatOnTrack ? 'On Track' : 'Over Limit',
                    style: TextStyle(
                      fontSize: 11,
                      color: vm.isFatOnTrack ? _green : Colors.red,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 6),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: '${vm.consumedFat}',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: _fatColor,
                  ),
                ),
                TextSpan(
                  text: '/${vm.fatTarget}g',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.black45,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: vm.fatProgress,
              minHeight: 8,
              backgroundColor: const Color(0xFFF1F5F9),
              valueColor: const AlwaysStoppedAnimation(_fatColor),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${(vm.fatProgress * 100).toInt()}%',
            style: const TextStyle(fontSize: 11, color: _fatColor),
          ),
        ],
      ),
    );
  }

  // ─── Activity card (Steps / Water) ────────────────────────
  Widget _buildActivityCard({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
    required double progress,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: _cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          children: [
            SizedBox(
              width: 60,
              height: 60,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  const CircularProgressIndicator(
                    value: 1.0,
                    strokeWidth: 5,
                    color: Color(0xFFF1F5F9),
                  ),
                  CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 5,
                    backgroundColor: Colors.transparent,
                    color: color,
                    strokeCap: StrokeCap.round,
                  ),
                  Center(
                    child: Icon(icon, size: 22, color: color),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                fontSize: 10,
                letterSpacing: 0.8,
                color: Colors.black45,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Action Buttons ───────────────────────────────────────
  Widget _buildActionButton({
    required String label,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: _cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Center(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─── Bottom Nav ───────────────────────────────────────────
  Widget _buildBottomNav() {
    final items = [
      {'icon': Icons.home_rounded,        'label': 'Home',      'active': true},
      {'icon': Icons.restaurant_outlined, 'label': 'Nutrition', 'active': false},
      {'icon': Icons.fitness_center,      'label': 'Gym',       'active': false},
      {'icon': Icons.radar,               'label': 'Radar',     'active': false},
      {'icon': Icons.person_outline,      'label': 'Profile',   'active': false},
    ];

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: _cardColor,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: items.map((item) {
          final active = item['active'] as bool;
          return Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  item['icon'] as IconData,
                  size: 22,
                  color: active ? _green : Colors.black38,
                ),
                const SizedBox(height: 2),
                Text(
                  item['label'] as String,
                  style: TextStyle(
                    fontSize: 10,
                    color: active ? _green : Colors.black38,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<HomeViewModel>();

    if (vm.isLoading) {
      return const Scaffold(
        backgroundColor: _bgColor,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        backgroundColor: _bgColor,
        elevation: 0,
        leading: GestureDetector(
          onTap: () async {
            // 1. Sign out of Firebase
            await FirebaseAuth.instance.signOut();

            // 2. Route back to the WidgetTree to handle the logged-out state
            if (context.mounted) {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const WidgetTree()),
                    (route) => false,
              );
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(10.0),
            child: CircleAvatar(
              backgroundColor: Colors.grey.shade200,
              child: const Icon(Icons.person, size: 18, color: Colors.grey),
            ),
          ),
        ),
        title: Text(
          _todayLabel,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.8,
            color: Colors.black87,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none, color: Colors.black54),
            onPressed: () {},
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
        child: Column(
          children: [
            _buildBanner(context, vm),
            const SizedBox(height: 8),

            // ── Calories ring + Protein/Carbs side ──
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 5, child: _buildCalorieRing(vm)),
                const SizedBox(width: 10),
                Expanded(
                  flex: 4,
                  child: Column(
                    children: [
                      _buildMacroSideCard(
                        label: 'Protein',
                        consumed: vm.consumedProtein,
                        target: vm.proteinTarget,
                        progress: vm.proteinProgress,
                        color: const Color(0xFF378ADD),
                      ),
                      const SizedBox(height: 10),
                      _buildMacroSideCard(
                        label: 'Carbs',
                        consumed: vm.consumedCarbs,
                        target: vm.carbsTarget,
                        progress: vm.carbsProgress,
                        color: const Color(0xFFEF9F27),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // ── Fat bar ──
            _buildFatCard(vm),
            const SizedBox(height: 10),

            // ── Steps + Water ──
            Row(
              children: [
                _buildActivityCard(
                  icon: Icons.directions_walk,
                  // MODIFIED HERE: Using NumberFormat to display exact steps with commas
                  value: NumberFormat('#,###').format(vm.steps),
                  label: 'STEPS',
                  color: _green,
                  progress: (vm.steps / 10000).clamp(0.0, 1.0),
                ),
                const SizedBox(width: 10),
                _buildActivityCard(
                  icon: Icons.water_drop_outlined,
                  value: '${vm.waterLiters.toStringAsFixed(1)}L',
                  label: 'WATER',
                  color: const Color(0xFF60A5FA),
                  progress: (vm.waterLiters / 2.5).clamp(0.0, 1.0),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // ── Log buttons ──
            Row(
              children: [
                _buildActionButton(
                  label: '+ Log Meal',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const MealScanView()),
                    );
                  },
                ),
                const SizedBox(width: 10),
                _buildActionButton(
                  label: '↗ Log Workout',
                  onTap: () {
                    // TODO: Navigator.push to WorkoutLogView
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}