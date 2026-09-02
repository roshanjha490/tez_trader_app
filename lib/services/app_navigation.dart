import 'package:flutter/foundation.dart';

/// Lets code anywhere in the widget tree (e.g. the "Sector Performance"
/// card on the Home tab) request a jump to a specific sector inside the
/// Markets tab, WITHOUT leaving [MainShell]'s tree.
///
/// This used to be done with `Navigator.push(MaterialPageRoute(builder:
/// (_) => MarketsScreen(...)))`. That pushes a brand new route ON TOP of
/// MainShell instead of switching MainShell's own bottom-nav tab, which:
///   - loses MainShell's top bar, bottom nav bar, and background gradients
///     (MarketsScreen alone has none of that chrome — it's all provided by
///     MainShell)
///   - breaks the `ActiveTab` InheritedWidget lookup that MarketsScreen /
///     SectorsTab use to decide whether to open their WebSockets, since a
///     pushed route's widget tree is a SIBLING of MainShell's tree, not a
///     descendant of it — so `ActiveTab.of(context)` can't find it, falls
///     back to its default, and the Markets socket never thinks it's
///     "active" and never connects.
///
/// The fix: keep the single, persistent [MainShell] alive (it already is,
/// via its IndexedStack) and just tell it which tab to show, then tell the
/// already-alive MarketsScreen/SectorsTab which sector to select.
class SectorTabRequest {
  final String sector;
  final int nonce; // lets listeners react even to a repeated sector name
  const SectorTabRequest(this.sector, this.nonce);
}

final ValueNotifier<SectorTabRequest?> sectorTabRequest = ValueNotifier(null);

int _sectorRequestNonce = 0;

/// Call this to jump to Markets tab -> Sectors sub-tab -> [sector].
void requestSectorTab(String sector) {
  _sectorRequestNonce++;
  sectorTabRequest.value = SectorTabRequest(sector, _sectorRequestNonce);
}