import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../services/api_client.dart';
import '../state/game_state.dart';
import '../theme.dart';
import '../widgets/chat_panel.dart';
import '../widgets/port_trade_panel.dart';

class SectorScreen extends StatefulWidget {
  const SectorScreen({super.key});

  @override
  State<SectorScreen> createState() => _SectorScreenState();
}

class _SectorScreenState extends State<SectorScreen> {
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

  Future<void> _move(GameState gs, int to) => _run(() async {
        final err = await gs.moveTo(to);
        if (err != null && mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
      });

  Future<void> _attack(GameState gs, String type, int id, String name) => _run(() async {
        final resp = await gs.api.combatAttack(type, id);
        final result = resp['result'] as Map<String, dynamic>;
        await gs.refreshSector();
        if (mounted) {
          showDialog(
            context: context,
            builder: (_) => AlertDialog(
              title: Text('Battle vs $name'),
              content: Text(
                  'Outcome: ${result['outcome']}\nYour fighters left: ${result['attacker_fighters']}\n'
                  'Their fighters left: ${result['defender_fighters']}\nLooted: ${resp['looted']} credits'),
              actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
            ),
          );
        }
      });

  Future<void> _claimPlanet(GameState gs) => _run(() async {
        await gs.api.planetClaim('${gs.player?.handle}\'s Colony');
        await gs.refreshSector();
      });

  Future<void> _deployMines(GameState gs) => _run(() async {
        final qty = await _askQty(context, 'Deploy mines (uses Equipment cargo)');
        if (qty == null || qty <= 0) return;
        await gs.api.minesDeploy(qty);
        await gs.refreshSector();
      });

  Future<int?> _askQty(BuildContext context, String title) async {
    final controller = TextEditingController(text: '5');
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
    final sector = gs.sector;

    if (gs.loadingSector && sector == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (sector == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(gs.sectorError ?? 'No sector data'),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: gs.refreshSector, child: const Text('Retry')),
          ],
        ),
      );
    }

    final wide = MediaQuery.of(context).size.width > 900;

    final leftCards = <Widget>[
      _sectorInfoCard(gs, sector),
      const SizedBox(height: 12),
      if (gs.port != null) ...[
        PortTradePanel(port: gs.port!),
        const SizedBox(height: 12),
      ],
      _entitiesCard(gs),
    ];

    final rightCards = <Widget>[
      const ChatPanel(scope: 'sector'),
      const SizedBox(height: 12),
      _eventFeedCard(gs),
    ];

    final body = wide
        ? Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(12),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: leftCards),
                ),
              ),
              SizedBox(
                width: 340,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(12),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: rightCards),
                ),
              ),
            ],
          )
        : SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [...leftCards, const SizedBox(height: 12), ...rightCards],
            ),
          );

    return AbsorbPointer(
      absorbing: _busy,
      child: Opacity(opacity: _busy ? 0.6 : 1, child: body),
    );
  }

  Widget _sectorInfoCard(GameState gs, SectorInfo sector) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(sector.name ?? 'Sector ${sector.id}',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(width: 8),
                if (sector.isFederation)
                  const Chip(label: Text('FEDERATION SPACE'), backgroundColor: TWColors.accent2, labelStyle: TextStyle(color: Colors.black)),
                if (sector.hazard)
                  const Chip(label: Text('NEBULA / HAZARD'), backgroundColor: TWColors.warning, labelStyle: TextStyle(color: Colors.black)),
              ],
            ),
            const SizedBox(height: 12),
            const Text('Warp lanes:', style: TextStyle(color: TWColors.textDim)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: gs.warpsOut
                  .map((s) => OutlinedButton.icon(
                        onPressed: () => _move(gs, s),
                        icon: const Icon(Icons.double_arrow, size: 16),
                        label: Text('Sector $s'),
                      ))
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _entitiesCard(GameState gs) {
    final gsPlayer = gs.player;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('This sector', style: TextStyle(fontWeight: FontWeight.bold, color: TWColors.accent)),
            const Divider(),
            if (gs.playersHere.isEmpty && gs.npcsHere.isEmpty && gs.planetsHere.isEmpty && gs.minesHere.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('Empty space. Nothing here but stars.', style: TextStyle(color: TWColors.textDim)),
              ),
            for (final p in gs.playersHere)
              ListTile(
                dense: true,
                leading: const Icon(Icons.person, color: TWColors.accent),
                title: Text(p.handle),
                subtitle: Text('${p.shipName} · fighters ${p.fighters} · shields ${p.shields}'),
                trailing: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: TWColors.danger),
                  onPressed: (gsPlayer?.fighters ?? 0) <= 0 ? null : () => _attack(gs, 'player', p.id, p.handle),
                  child: const Text('Attack'),
                ),
              ),
            for (final n in gs.npcsHere)
              ListTile(
                dense: true,
                leading: Icon(n.kind == 'space_monster' ? Icons.bug_report : Icons.warning,
                    color: n.aggressive ? TWColors.danger : TWColors.warning),
                title: Text(n.name),
                subtitle: Text('fighters ${n.fighters} · shields ${n.shields} · bounty ${n.bountyCredits}cr'),
                trailing: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: TWColors.danger),
                  onPressed: (gsPlayer?.fighters ?? 0) <= 0 ? null : () => _attack(gs, 'npc', n.id, n.name),
                  child: const Text('Attack'),
                ),
              ),
            for (final pl in gs.planetsHere)
              ListTile(
                dense: true,
                leading: const Icon(Icons.public, color: TWColors.accent2),
                title: Text(pl.name),
                subtitle: Text(pl.ownerPlayerId == null
                    ? 'Unclaimed · ${pl.type}'
                    : 'Owned · colonists ${pl.colonists} · citadel L${pl.citadelLevel}'),
                trailing: pl.ownerPlayerId == null
                    ? ElevatedButton(onPressed: () => _claimPlanet(gs), child: const Text('Claim'))
                    : (pl.ownerPlayerId == gsPlayer?.id
                        ? const Chip(label: Text('Yours'))
                        : null),
              ),
            if (gs.minesHere.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'Mines detected: ${gs.minesHere.fold<int>(0, (a, b) => a + b.total)} (hostile to non-owners)',
                  style: const TextStyle(color: TWColors.warning),
                ),
              ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _deployMines(gs),
                  icon: const Icon(Icons.local_fire_department, size: 16),
                  label: const Text('Deploy mines'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _eventFeedCard(GameState gs) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Galaxy Feed', style: TextStyle(fontWeight: FontWeight.bold, color: TWColors.accent)),
            const Divider(),
            if (gs.events.isEmpty)
              const Text('All quiet in the sector...', style: TextStyle(color: TWColors.textDim)),
            for (final e in gs.events.take(15))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text('${e.title} — ${e.message}',
                    style: const TextStyle(fontSize: 12, color: TWColors.textDim)),
              ),
          ],
        ),
      ),
    );
  }
}
