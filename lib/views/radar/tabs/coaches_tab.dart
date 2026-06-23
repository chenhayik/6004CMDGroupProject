import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../models/coach_profile.dart';
import '../../../viewmodels/coach_directory_viewmodel.dart';
import '../coach_register_view.dart';
import '../radar_launchers.dart';

/// Browsable list of locally-registered coaches with a specialization filter
/// and a register/edit entry point. Consumes the parent's
/// [CoachDirectoryViewModel].
class CoachesTab extends StatelessWidget {
  const CoachesTab({super.key});

  static const _green = Color(0xFF22C55E);
  static const _indigo = Color(0xFF6366F1);

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<CoachDirectoryViewModel>();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'coach_register',
        backgroundColor: _indigo,
        icon: Icon(vm.myCoach == null ? Icons.add : Icons.edit, size: 18),
        label: Text(vm.myCoach == null ? 'Become a coach' : 'Edit my profile'),
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CoachRegisterView(existing: vm.myCoach),
            ),
          );
          await vm.load(); // refresh after a possible save
        },
      ),
      body: Column(
        children: [
          _filterChips(vm),
          Expanded(child: _list(context, vm)),
        ],
      ),
    );
  }

  Widget _filterChips(CoachDirectoryViewModel vm) {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        children: CoachSpecializations.all.entries.map((e) {
          final selected = vm.specFilter.contains(e.key);
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => vm.toggleSpec(e.key),
              child: Container(
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: selected ? _indigo : Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                      color: selected ? _indigo : Colors.grey.shade300),
                ),
                child: Text(
                  e.value,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: selected ? Colors.white : Colors.black54,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _list(BuildContext context, CoachDirectoryViewModel vm) {
    if (vm.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (vm.error != null && vm.isEmpty) {
      return _centered(Icons.cloud_off, vm.error!, onRetry: vm.load);
    }
    final coaches = vm.coaches;
    if (coaches.isEmpty) {
      return _centered(
        Icons.person_search,
        vm.isEmpty
            ? 'No coaches registered yet.\nBe the first — tap “Become a coach”.'
            : 'No coaches match these filters.',
      );
    }
    return RefreshIndicator(
      onRefresh: vm.load,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 90),
        itemCount: coaches.length,
        itemBuilder: (context, i) => _coachCard(context, coaches[i]),
      ),
    );
  }

  Widget _coachCard(BuildContext context, CoachProfile c) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 5),
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: _indigo.withValues(alpha: 0.12),
                child: const Icon(Icons.sports_gymnastics, color: _indigo),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      c.displayName,
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Colors.black87),
                    ),
                    if (c.city.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(Icons.place,
                              size: 12, color: Colors.black38),
                          const SizedBox(width: 2),
                          Text(c.city,
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.black54)),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'RM ${c.hourlyRateMyr}',
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: _green),
                  ),
                  const Text('per hour',
                      style: TextStyle(fontSize: 10.5, color: Colors.black45)),
                ],
              ),
            ],
          ),
          if (c.specializations.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: c.specializations
                  .map((s) => Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: _indigo.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          CoachSpecializations.label(s),
                          style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: _indigo),
                        ),
                      ))
                  .toList(),
            ),
          ],
          if (c.bio.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              c.bio,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 12.5, color: Colors.black54, height: 1.4),
            ),
          ],
          if (c.availability.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.event_available,
                    size: 13, color: Colors.black38),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(c.availability,
                      style: const TextStyle(
                          fontSize: 12, color: Colors.black54)),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 42,
            child: ElevatedButton.icon(
              onPressed: () => RadarLaunchers.contactCoach(context, c),
              icon: Icon(_contactIcon(c.contactMethod), size: 18),
              label: Text('Inquire via ${c.contactMethod.label}'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _indigo,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _contactIcon(ContactMethod m) {
    switch (m) {
      case ContactMethod.whatsapp:
        return Icons.chat;
      case ContactMethod.phone:
        return Icons.call;
      case ContactMethod.email:
        return Icons.email;
    }
  }

  Widget _centered(IconData icon, String msg, {Future<void> Function()? onRetry}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 44, color: Colors.black26),
            const SizedBox(height: 12),
            Text(msg,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13.5, color: Colors.black54)),
            if (onRetry != null) ...[
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Retry'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
