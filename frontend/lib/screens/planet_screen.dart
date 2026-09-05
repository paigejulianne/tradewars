import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../services/api_client.dart';
import '../state/game_state.dart';
import '../theme.dart';

class PlanetScreen extends StatefulWidget {
  const PlanetScreen({super.key});

  @override
  State<PlanetScreen> createState() => _PlanetScreenState();
}

class _PlanetScreenState extends State<PlanetScreen> {
  bool _busy = false;

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

  Future<int?> _askQty(String title) async {
    final controller = TextEditingController(text: '10');
    return showDialog<int>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: TextField(controller: controller, keyboardType: TextInputType.number, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, int.tryParse(controller.text) ?? 0),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final gs = context.watch<GameState>();
    final planets = gs.planetsHere;
    final p = gs.player;

    if (planets.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('There is no planet in this sector. Explore the galaxy to find one.',
              textAlign: TextAlign.center, style: TextStyle(color: TWColors.textDim)),
        ),
      );
    }

    final planet = planets.first;
    final owned = p != null && planet.ownerPlayerId == p.id;

    return AbsorbPointer(
      absorbing: _busy,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(planet.name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  Text(planet.type.replaceAll('_', ' ').toUpperCase(), style: const TextStyle(color: TWColors.textDim)),
                  const SizedBox(height: 12),
                  if (planet.ownerPlayerId == null)
                    const Text('This world is unclaimed.', style: TextStyle(color: TWColors.warning))
                  else if (owned)
                    const Text('You govern this colony.', style: TextStyle(color: TWColors.accent2))
                  else
                    const Text('Claimed by another captain.', style: TextStyle(color: TWColors.textDim)),
                  const SizedBox(height: 8),
                  Text('Colonists: ${planet.colonists} / ${planet.maxColonists}'),
                  Text('Citadel level: ${planet.citadelLevel}'),
                  Text('Defense fighters: ${planet.fighters}'),
                  const SizedBox(height: 12),
                  Text('Stockpile — Fuel Ore: ${planet.fuelOreStock} · Organics: ${planet.organicsStock} · Equipment: ${planet.equipmentStock}',
                      style: const TextStyle(fontSize: 12)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (planet.ownerPlayerId == null)
            ElevatedButton.icon(
              icon: const Icon(Icons.flag),
              label: const Text('Claim this planet'),
              onPressed: () => _run(() async {
                await gs.api.planetClaim('${p?.handle}\'s Colony');
                await gs.refreshSector();
              }),
            ),
          if (owned) ...[
            const Text('Manage colony', style: TextStyle(fontWeight: FontWeight.bold, color: TWColors.accent)),
            const SizedBox(height: 8),
            for (final c in ['fuel_ore', 'organics', 'equipment', 'colonists'])
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    SizedBox(width: 90, child: Text(_label(c))),
                    Expanded(child: Text('Aboard: ${_playerQty(p, c)}', style: const TextStyle(fontSize: 12, color: TWColors.textDim))),
                    OutlinedButton(
                      onPressed: () => _run(() async {
                        final qty = await _askQty('Deposit $c');
                        if (qty == null || qty <= 0) return;
                        await gs.api.planetDeposit(c, qty);
                        await gs.refreshSector();
                      }),
                      child: const Text('Deposit'),
                    ),
                    const SizedBox(width: 6),
                    OutlinedButton(
                      onPressed: () => _run(() async {
                        final qty = await _askQty('Collect $c');
                        if (qty == null || qty <= 0) return;
                        await gs.api.planetCollect(c, qty);
                        await gs.refreshSector();
                      }),
                      child: const Text('Collect'),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }

  String _label(String c) => switch (c) {
        'fuel_ore' => 'Fuel Ore',
        'organics' => 'Organics',
        'equipment' => 'Equipment',
        'colonists' => 'Colonists',
        _ => c,
      };

  int _playerQty(Player? p, String c) {
    if (p == null) return 0;
    return switch (c) {
      'fuel_ore' => p.fuelOre,
      'organics' => p.organics,
      'equipment' => p.equipment,
      'colonists' => p.colonists,
      _ => 0,
    };
  }
}
