import 'package:flutter/material.dart';

import '../../services/app_navigation.dart';
import 'sector_rotation_tab.dart';
import 'sectors_tab.dart';

/// Sectors section with two sub-tabs, like the portal: Sector Rotation and
/// Stock Weightage. A request to open a specific sector (from the Home
/// "Sector Performance" card) always lands on Stock Weightage.
class SectorsHub extends StatefulWidget {
  final String? initialSector;

  const SectorsHub({super.key, this.initialSector});

  @override
  State<SectorsHub> createState() => _SectorsHubState();
}

class _SectorsHubState extends State<SectorsHub> with SingleTickerProviderStateMixin {
  static const int _rotation = 0;
  static const int _weightage = 1;

  late final TabController _controller;

  @override
  void initState() {
    super.initState();
    final wantsSector = widget.initialSector != null || sectorTabRequest.value != null;
    _controller = TabController(
      length: 2,
      vsync: this,
      initialIndex: wantsSector ? _weightage : _rotation,
    );
    sectorTabRequest.addListener(_onSectorRequest);
  }

  void _onSectorRequest() {
    if (sectorTabRequest.value != null) _controller.animateTo(_weightage);
  }

  @override
  void dispose() {
    sectorTabRequest.removeListener(_onSectorRequest);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 8),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: TabBar(
            controller: _controller,
            indicator: BoxDecoration(
              color: Colors.white.withOpacity(0.12),
              borderRadius: BorderRadius.circular(7),
            ),
            indicatorSize: TabBarIndicatorSize.tab,
            dividerColor: Colors.transparent,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white54,
            labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            tabs: const [Tab(text: 'Sector Rotation'), Tab(text: 'Stock Weightage')],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _controller,
            children: [
              const SectorRotationTab(),
              SectorsTab(initialSector: widget.initialSector),
            ],
          ),
        ),
      ],
    );
  }
}
