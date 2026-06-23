import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../viewmodels/coach_directory_viewmodel.dart';
import '../../viewmodels/fitness_radar_viewmodel.dart';
import 'tabs/coaches_tab.dart';
import 'tabs/facilities_tab.dart';

/// Fitness Radar (§4.5): nearby gyms on a map + a coach directory, behind one
/// segmented control. Both ViewModels are created once at this level and kept
/// alive via an IndexedStack, so flipping the segment never re-queries Places
/// or Firestore.
class FitnessRadarView extends StatefulWidget {
  const FitnessRadarView({super.key});

  @override
  State<FitnessRadarView> createState() => _FitnessRadarViewState();
}

class _FitnessRadarViewState extends State<FitnessRadarView> {
  static const _green = Color(0xFF22C55E);
  static const _bg = Color(0xFFF8FAFC);
  int _segment = 0; // 0 = Facilities, 1 = Coaches

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => FitnessRadarViewModel()),
        ChangeNotifierProvider(create: (_) => CoachDirectoryViewModel()),
      ],
      child: Scaffold(
        backgroundColor: _bg,
        appBar: AppBar(
          backgroundColor: _bg,
          elevation: 0,
          leading: const BackButton(color: Colors.black87),
          title: const Text(
            'Fitness Radar',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black87),
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(50),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
              child: _segmentedControl(),
            ),
          ),
        ),
        body: IndexedStack(
          index: _segment,
          children: const [FacilitiesTab(), CoachesTab()],
        ),
      ),
    );
  }

  Widget _segmentedControl() {
    Widget seg(int index, IconData icon, String label) {
      final selected = _segment == index;
      return Expanded(
        child: GestureDetector(
          onTap: () => setState(() => _segment = index),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 9),
            decoration: BoxDecoration(
              color: selected ? _green : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon,
                    size: 16,
                    color: selected ? Colors.white : Colors.black54),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: selected ? Colors.white : Colors.black54,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          seg(0, Icons.map_outlined, 'Facilities'),
          seg(1, Icons.people_alt_outlined, 'Coaches'),
        ],
      ),
    );
  }
}
