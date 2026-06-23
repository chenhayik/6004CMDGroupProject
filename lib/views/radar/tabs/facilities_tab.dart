import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';

import '../../../models/fitness_place.dart';
import '../../../services/location_service.dart';
import '../../../viewmodels/fitness_radar_viewmodel.dart';
import '../radar_launchers.dart';

/// Map + draggable result list for nearby gyms. Consumes the
/// [FitnessRadarViewModel] provided by the parent screen (kept alive across
/// segment switches so we don't re-query Places).
class FacilitiesTab extends StatefulWidget {
  const FacilitiesTab({super.key});

  @override
  State<FacilitiesTab> createState() => _FacilitiesTabState();
}

class _FacilitiesTabState extends State<FacilitiesTab> {
  static const _green = Color(0xFF22C55E);
  static const _bg = Color(0xFFF8FAFC);

  // Muted style: hide third-party POI labels so our gym markers stand out and
  // the map reads cleanly (also slightly cheaper to render).
  static const _mapStyle = '''
[
  {"featureType":"poi.business","stylers":[{"visibility":"off"}]},
  {"featureType":"poi.park","elementType":"labels.text","stylers":[{"visibility":"off"}]},
  {"featureType":"transit","stylers":[{"visibility":"off"}]}
]''';

  GoogleMapController? _map;
  LatLng? _camTarget;
  bool _started = false;
  // Auto-centre on the user's first GPS fix exactly once. The fix usually
  // arrives after the map is built, so initialCameraPosition isn't enough.
  bool _centeredOnFix = false;

  @override
  void initState() {
    super.initState();
    // Kick off location + first fetch once, after the first frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_started) return;
      _started = true;
      context.read<FitnessRadarViewModel>().init();
    });
  }

  @override
  void dispose() {
    _map?.dispose();
    super.dispose();
  }

  Future<void> _moveCamera(LatLng target, {double zoom = 14}) async {
    await _map?.animateCamera(CameraUpdate.newLatLngZoom(target, zoom));
  }

  Set<Marker> _markers(FitnessRadarViewModel vm) {
    return vm.places.map((p) {
      final selected = p.id == vm.selectedId;
      return Marker(
        markerId: MarkerId(p.id),
        position: p.position,
        icon: BitmapDescriptor.defaultMarkerWithHue(
          selected
              ? BitmapDescriptor.hueAzure
              : (p.openNow == false
                  ? BitmapDescriptor.hueOrange
                  : BitmapDescriptor.hueGreen),
        ),
        infoWindow: InfoWindow(title: p.name, snippet: p.distanceLabel),
        onTap: () {
          vm.select(p.id);
          _moveCamera(p.position);
        },
      );
    }).toSet();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<FitnessRadarViewModel>();

    // The GPS fix often lands after the map is created; recentre on it once.
    if (vm.hasFix && !_centeredOnFix && _map != null) {
      _centeredOnFix = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _moveCamera(vm.center);
      });
    }

    return Stack(
      children: [
        // ── Map ──
        GoogleMap(
          initialCameraPosition: CameraPosition(target: vm.center, zoom: 13),
          style: _mapStyle,
          markers: _markers(vm),
          myLocationEnabled: vm.hasFix,
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false,
          mapToolbarEnabled: false,
          onMapCreated: (c) {
            _map = c;
            if (vm.hasFix) {
              _centeredOnFix = true;
              _moveCamera(vm.center);
            }
          },
          onCameraMove: (pos) => _camTarget = pos.target,
          onCameraIdle: () {
            if (_camTarget != null) vm.onCameraIdle(_camTarget!);
          },
          onTap: (_) => vm.select(null),
        ),

        // ── Top filter bar ──
        Positioned(top: 8, left: 8, right: 8, child: _filterBar(vm)),

        // ── "Search this area" pill ──
        if (vm.showSearchHere)
          Positioned(
            top: 58,
            left: 0,
            right: 0,
            child: Center(child: _searchHereButton(vm)),
          ),

        // ── Re-centre FAB ──
        Positioned(
          right: 12,
          bottom: MediaQuery.of(context).size.height * 0.30 + 12,
          child: _recenterButton(vm),
        ),

        // ── Permission / key banners ──
        if (vm.keyMissing || vm.permission == LocationStatus.deniedForever)
          Positioned(top: 56, left: 12, right: 12, child: _hintBanner(vm)),

        // ── Result sheet ──
        _resultSheet(vm),
      ],
    );
  }

  // ─── Filter bar ──────────────────────────────────────────
  Widget _filterBar(FitnessRadarViewModel vm) {
    return Container(
      height: 42,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(21),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        children: [
          _chip(
            label: 'Open now',
            selected: vm.openNowOnly,
            icon: Icons.schedule,
            onTap: vm.toggleOpenNow,
          ),
          _divider(),
          for (final km in const [1.0, 3.0, 5.0, 10.0])
            _chip(
              label: '${km.toInt()} km',
              selected: vm.radiusKm == km,
              onTap: () => vm.setRadius(km),
            ),
          _divider(),
          for (final t in FacilityType.values)
            _chip(
              label: t.label,
              selected: vm.typeFilter.contains(t),
              onTap: () => vm.toggleType(t),
            ),
        ],
      ),
    );
  }

  Widget _divider() => Container(
        width: 1,
        margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        color: Colors.grey.shade300,
      );

  Widget _chip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
    IconData? icon,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 3),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? _green : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              if (icon != null) ...[
                Icon(icon,
                    size: 14,
                    color: selected ? Colors.white : Colors.black54),
                const SizedBox(width: 4),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 12.5,
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

  Widget _searchHereButton(FitnessRadarViewModel vm) {
    return Material(
      color: Colors.white,
      elevation: 3,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: vm.searchHere,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              vm.searching
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.refresh, size: 16, color: _green),
              const SizedBox(width: 6),
              const Text('Search this area',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _recenterButton(FitnessRadarViewModel vm) {
    return FloatingActionButton.small(
      heroTag: 'radar_recenter',
      backgroundColor: Colors.white,
      foregroundColor: _green,
      onPressed: () => _moveCamera(vm.center),
      child: const Icon(Icons.my_location),
    );
  }

  Widget _hintBanner(FitnessRadarViewModel vm) {
    final keyMissing = vm.keyMissing;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.shade300),
      ),
      child: Row(
        children: [
          Icon(keyMissing ? Icons.vpn_key_off : Icons.location_off,
              size: 18, color: Colors.amber.shade800),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              keyMissing
                  ? 'Map search is disabled — no Maps API key configured.'
                  : 'Location is off, showing a default area. Enable it for nearby results.',
              style: const TextStyle(fontSize: 12, color: Colors.black87),
            ),
          ),
          if (!keyMissing)
            TextButton(
              onPressed: () => LocationService().openSettings(),
              child: const Text('Enable'),
            ),
        ],
      ),
    );
  }

  // ─── Result sheet ────────────────────────────────────────
  Widget _resultSheet(FitnessRadarViewModel vm) {
    return DraggableScrollableSheet(
      initialChildSize: 0.30,
      minChildSize: 0.12,
      maxChildSize: 0.85,
      snap: true,
      snapSizes: const [0.30, 0.85],
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: _bg,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            boxShadow: [
              BoxShadow(color: Colors.black26, blurRadius: 12, offset: Offset(0, -2)),
            ],
          ),
          child: CustomScrollView(
            controller: scrollController,
            slivers: [
              SliverToBoxAdapter(child: _sheetHeader(vm)),
              _sheetBody(vm),
              const SliverToBoxAdapter(child: SizedBox(height: 16)),
            ],
          ),
        );
      },
    );
  }

  Widget _sheetHeader(FitnessRadarViewModel vm) {
    return Column(
      children: [
        const SizedBox(height: 8),
        Container(
          width: 38,
          height: 4,
          decoration: BoxDecoration(
            color: Colors.grey.shade300,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
          child: Row(
            children: [
              const Icon(Icons.fitness_center, size: 18, color: _green),
              const SizedBox(width: 8),
              Text(
                vm.status == RadarStatus.ready
                    ? '${vm.places.length} nearby'
                    : 'Fitness Radar',
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87),
              ),
              const Spacer(),
              if (vm.searching)
                const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _sheetBody(FitnessRadarViewModel vm) {
    if (vm.status == RadarStatus.loading && vm.places.isEmpty) {
      return const SliverFillRemaining(
        hasScrollBody: false,
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 40),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }
    if (vm.places.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: _emptyState(vm),
      );
    }
    final items = vm.places;
    return SliverList.builder(
      itemCount: items.length,
      itemBuilder: (context, i) => _placeCard(vm, items[i]),
    );
  }

  Widget _emptyState(FitnessRadarViewModel vm) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 30, 24, 30),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            vm.status == RadarStatus.error
                ? Icons.cloud_off
                : Icons.location_searching,
            size: 40,
            color: Colors.black26,
          ),
          const SizedBox(height: 12),
          Text(
            vm.error ??
                'No gyms within ${vm.radiusKm.toInt()} km — try widening the radius.',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: Colors.black54),
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: vm.refresh,
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _placeCard(FitnessRadarViewModel vm, FitnessPlace p) {
    final selected = p.id == vm.selectedId;
    final open = p.openNow;
    return GestureDetector(
      onTap: () {
        vm.select(p.id);
        _moveCamera(p.position);
      },
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 4, 12, 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? _green : Colors.grey.shade200,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    p.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      _typePill(p.type),
                      const SizedBox(width: 8),
                      if (p.distanceLabel.isNotEmpty) ...[
                        const Icon(Icons.near_me,
                            size: 12, color: Colors.black38),
                        const SizedBox(width: 2),
                        Text(p.distanceLabel,
                            style: const TextStyle(
                                fontSize: 11.5, color: Colors.black54)),
                      ],
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      if (open != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: (open ? _green : Colors.red)
                                .withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            open ? 'Open now' : 'Closed',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              color: open ? _green : Colors.red,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      if (p.rating != null) ...[
                        const Icon(Icons.star, size: 13, color: Color(0xFFF59E0B)),
                        const SizedBox(width: 2),
                        Text(
                          '${p.rating!.toStringAsFixed(1)}'
                          '${p.userRatingCount != null ? ' (${p.userRatingCount})' : ''}',
                          style: const TextStyle(
                              fontSize: 11.5, color: Colors.black54),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Directions',
              icon: const Icon(Icons.directions, color: _green),
              onPressed: () => RadarLaunchers.directions(context, p.lat, p.lng),
            ),
          ],
        ),
      ),
    );
  }

  Widget _typePill(FacilityType t) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFF22C55E).withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        t.label,
        style: const TextStyle(
            fontSize: 10.5, fontWeight: FontWeight.w600, color: _green),
      ),
    );
  }
}
