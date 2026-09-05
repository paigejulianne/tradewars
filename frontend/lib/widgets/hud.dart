import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/game_state.dart';
import '../theme.dart';

class Hud extends StatelessWidget implements PreferredSizeWidget {
  const Hud({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(64);

  Widget _stat(IconData icon, String value, String tooltip, {Color? color}) {
    return Tooltip(
      message: tooltip,
      waitDuration: const Duration(milliseconds: 300),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color ?? TWColors.textDim),
            const SizedBox(width: 4),
            Text(value, style: TextStyle(color: color ?? TWColors.text, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final gs = context.watch<GameState>();
    final p = gs.player;
    final width = MediaQuery.of(context).size.width;
    final narrow = width < 640;

    final stats = p == null
        ? const SizedBox.shrink()
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _stat(Icons.paid, '${p.credits}', 'Credits — spend at ports and the Shipyard',
                  color: TWColors.warning),
              _stat(Icons.bolt, '${p.turnsRemaining}',
                  'Turns remaining — moving, attacking, and deploying mines cost turns; resets daily'),
              _stat(Icons.shield, '${p.shields}', 'Shields — absorb combat damage before your fighters take losses',
                  color: TWColors.accent),
              _stat(Icons.gps_fixed, '${p.fighters}', 'Fighters — your ship\'s weapons; lose them all and your ship is destroyed',
                  color: TWColors.danger),
              _stat(Icons.inventory_2, '${p.holdsUsed}/${p.holdsTotal}',
                  'Cargo holds used / total — limits how much you can carry'),
            ],
          );

    return AppBar(
      titleSpacing: 12,
      title: Row(
        children: [
          const Icon(Icons.rocket_launch, color: TWColors.accent, size: 22),
          if (!narrow) ...[
            const SizedBox(width: 8),
            const Text('TRADEWARS', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 2)),
          ],
          if (gs.sector != null) ...[
            const SizedBox(width: 12),
            Text('SECTOR ${gs.sector!.id}', style: const TextStyle(color: TWColors.accent2)),
          ],
        ],
      ),
      actions: [
        // Bounded + horizontally scrollable so the stat cluster can never
        // overflow AppBar's actions row on narrow (phone) widths.
        SizedBox(
          width: narrow ? width * 0.5 : null,
          child: narrow
              ? SingleChildScrollView(scrollDirection: Axis.horizontal, child: stats)
              : stats,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Tooltip(
            message: gs.wsConnected ? 'Live connection active' : 'Reconnecting...',
            child: Icon(Icons.circle, size: 12, color: gs.wsConnected ? TWColors.accent2 : TWColors.danger),
          ),
        ),
        const SizedBox(width: 8),
      ],
    );
  }
}
