import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'analytics_theme.dart';
import '../../viewmodels/analytics_viewmodel.dart';
import 'tabs/overview_tab.dart';
import 'tabs/nutrition_tab.dart';
import 'tabs/workout_tab.dart';
import 'widgets/range_selector.dart';
import 'widgets/analytics_common.dart';

/// Analytics tab scaffold (§5.1): title "Insights" → global RangeSelector →
/// segmented TabBar [Overview · Nutrition · Workout] → swipeable TabBarView.
class AnalyticsScreen extends StatelessWidget {
  /// 0=Overview (default), 1=Nutrition, 2=Workout. Used by deep-links (§4.2).
  final int? initialTab;

  const AnalyticsScreen({super.key, this.initialTab});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AnalyticsViewModel()..load(),
      child: _AnalyticsContent(initialTab: initialTab),
    );
  }
}

class _AnalyticsContent extends StatefulWidget {
  final int? initialTab;
  const _AnalyticsContent({this.initialTab});

  @override
  State<_AnalyticsContent> createState() => _AnalyticsContentState();
}

class _AnalyticsContentState extends State<_AnalyticsContent>
    with SingleTickerProviderStateMixin {
  static const _prefsKey = 'analytics_last_tab';
  late final TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
    _tab.addListener(_onTabChanged);
    _restoreTab();
  }

  Future<void> _restoreTab() async {
    int initial = widget.initialTab ?? 0;
    if (widget.initialTab == null) {
      // Remember the last-selected tab between visits (§4.2).
      final prefs = await SharedPreferences.getInstance();
      initial = prefs.getInt(_prefsKey) ?? 0;
    }
    if (!mounted) return;
    setState(() => _tab.index = initial.clamp(0, 2));
  }

  void _onTabChanged() {
    if (!_tab.indexIsChanging) {
      // Remember the last-selected tab between visits (§4.2).
      SharedPreferences.getInstance()
          .then((p) => p.setInt(_prefsKey, _tab.index));
    }
  }

  @override
  void dispose() {
    _tab.removeListener(_onTabChanged);
    _tab.dispose();
    super.dispose();
  }

  void _jumpToTab(int i) => _tab.animateTo(i);

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<AnalyticsViewModel>();

    return Scaffold(
      backgroundColor: AnalyticsColors.bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Title
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Insights',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      color: AnalyticsColors.ink,
                    ),
                  ),
                  Text(
                    vm.windowSubtitle,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AnalyticsColors.muted,
                    ),
                  ),
                ],
              ),
            ),

            // Global range selector
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 6, 14, 10),
              child: RangeSelector(
                selected: vm.range,
                onChanged: (r) => context.read<AnalyticsViewModel>().setRange(r),
              ),
            ),

            // Offline / saved-data banner
            if (vm.error != null && vm.summary != null)
              const Padding(
                padding: EdgeInsets.fromLTRB(14, 0, 14, 0),
                child: OfflineBanner(),
              ),

            // Segmented tabs
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: AnalyticsColors.card,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AnalyticsColors.border),
              ),
              child: TabBar(
                controller: _tab,
                indicator: BoxDecoration(
                  color: AnalyticsColors.calories,
                  borderRadius: BorderRadius.circular(10),
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                indicatorPadding: const EdgeInsets.all(4),
                dividerColor: Colors.transparent,
                labelColor: Colors.white,
                unselectedLabelColor: AnalyticsColors.muted,
                labelStyle:
                    const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                tabs: const [
                  Tab(text: 'Overview'),
                  Tab(text: 'Nutrition'),
                  Tab(text: 'Workout'),
                ],
              ),
            ),

            // Error state (no cached data to fall back on)
            if (vm.error != null && vm.summary == null)
              Expanded(child: _ErrorState(onRetry: () => vm.retry()))
            else
              Expanded(
                child: TabBarView(
                  controller: _tab,
                  // TabBarView builds each page lazily on first reveal; the
                  // keep-alive wrapper then preserves it so switching tabs
                  // doesn't blank or rebuild the others.
                  children: [
                    _KeepAlive(child: OverviewTab(onJumpToTab: _jumpToTab)),
                    const _KeepAlive(child: NutritionTab()),
                    const _KeepAlive(child: WorkoutTab()),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErrorState({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off, size: 36, color: AnalyticsColors.muted),
          const SizedBox(height: 12),
          const Text(
            'Could not load your insights.',
            style: TextStyle(fontSize: 14, color: AnalyticsColors.ink),
          ),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

/// Keeps a TabBarView page alive once it has been built, so switching tabs
/// preserves each page instead of disposing/blanking it.
class _KeepAlive extends StatefulWidget {
  final Widget child;
  const _KeepAlive({required this.child});

  @override
  State<_KeepAlive> createState() => _KeepAliveState();
}

class _KeepAliveState extends State<_KeepAlive>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context); // required by AutomaticKeepAliveClientMixin
    return widget.child;
  }
}
