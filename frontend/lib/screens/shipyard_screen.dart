import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../services/api_client.dart';
import '../state/game_state.dart';
import '../theme.dart';

class ShipyardScreen extends StatefulWidget {
  const ShipyardScreen({super.key});

  @override
  State<ShipyardScreen> createState() => _ShipyardScreenState();
}

class _ShipyardScreenState extends State<ShipyardScreen> {
  List<ShipTypeInfo>? _types;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final gs = context.read<GameState>();
    final resp = await gs.api.shipTypes();
    setState(() {
      _types = (resp['ship_types'] as List).map((e) => ShipTypeInfo.fromJson(e as Map<String, dynamic>)).toList();
    });
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final gs = context.watch<GameState>();
    final p = gs.player;
    final atStardock = gs.sector?.isFederation ?? false;

    if (_types == null) return const Center(child: CircularProgressIndicator());

    return AbsorbPointer(
      absorbing: _busy,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (!atStardock)
            Card(
              color: TWColors.panelAlt,
              child: const Padding(
                padding: EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: TWColors.warning),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text('Fly to Sector 1 (Stardock) to buy ships or upgrade your fighters, shields, and cargo holds.'),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 16),
          if (p != null) _upgradesCard(gs, p, atStardock),
          const SizedBox(height: 16),
          const Text('Ships for sale', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: TWColors.accent)),
          const SizedBox(height: 8),
          ..._types!.map((t) => _shipCard(gs, t, atStardock, p)),
        ],
      ),
    );
  }

  Widget _upgradesCard(GameState gs, Player p, bool atStardock) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Upgrade your ship', style: TextStyle(fontWeight: FontWeight.bold, color: TWColors.accent)),
            const Divider(),
            _upgradeRow(gs, 'fighters', 'Fighters', p.fighters, 50, atStardock),
            _upgradeRow(gs, 'shields', 'Shields', p.shields, 30, atStardock),
            _upgradeRow(gs, 'holds', 'Cargo Holds', p.holdsTotal, 2000, atStardock),
          ],
        ),
      ),
    );
  }

  Widget _upgradeRow(GameState gs, String stat, String label, int current, int unitCost, bool atStardock) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(width: 110, child: Text(label)),
          Text('$current', style: const TextStyle(fontWeight: FontWeight.bold)),
          const Spacer(),
          Text('$unitCost cr/unit', style: const TextStyle(color: TWColors.textDim, fontSize: 12)),
          const SizedBox(width: 12),
          for (final qty in [10, 100])
            Padding(
              padding: const EdgeInsets.only(left: 6),
              child: OutlinedButton(
                onPressed: !atStardock
                    ? null
                    : () => _run(() async {
                          await gs.api.shipUpgrade(stat, qty);
                          await gs.refreshMe();
                        }),
                child: Text('+$qty'),
              ),
            ),
        ],
      ),
    );
  }

  Widget _shipCard(GameState gs, ShipTypeInfo t, bool atStardock, Player? p) {
    final owned = p?.shipTypeId == t.id;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(t.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(width: 8),
                if (owned) const Chip(label: Text('Current ship')),
                if (t.canCloak) const Padding(padding: EdgeInsets.only(left: 6), child: Icon(Icons.visibility_off, size: 16, color: TWColors.accent)),
              ],
            ),
            const SizedBox(height: 4),
            Text(t.description, style: const TextStyle(color: TWColors.textDim)),
            const SizedBox(height: 8),
            Text('Fighters ${t.maxFighters} · Shields ${t.maxShields} · Holds ${t.maxHolds} (starts ${t.baseHolds})',
                style: const TextStyle(fontSize: 12)),
            const SizedBox(height: 12),
            Row(
              children: [
                Text('${t.basePrice} cr', style: const TextStyle(color: TWColors.warning, fontWeight: FontWeight.bold)),
                const Spacer(),
                ElevatedButton(
                  onPressed: (!atStardock || owned)
                      ? null
                      : () => _run(() async {
                            await gs.api.shipBuy(t.id);
                            await gs.refreshMe();
                          }),
                  child: const Text('Purchase'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
