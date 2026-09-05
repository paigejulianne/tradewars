import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../services/api_client.dart';
import '../state/game_state.dart';
import '../theme.dart';

class PortTradePanel extends StatefulWidget {
  final Port port;
  const PortTradePanel({super.key, required this.port});

  @override
  State<PortTradePanel> createState() => _PortTradePanelState();
}

class _PortTradePanelState extends State<PortTradePanel> {
  final Map<String, TextEditingController> _qty = {
    'fuel_ore': TextEditingController(text: '10'),
    'organics': TextEditingController(text: '10'),
    'equipment': TextEditingController(text: '10'),
  };
  bool _busy = false;

  Future<void> _trade(GameState gs, String commodity, String action) async {
    final qty = int.tryParse(_qty[commodity]!.text) ?? 0;
    if (qty <= 0) return;
    setState(() => _busy = true);
    try {
      await gs.api.portTrade(commodity, action, qty);
      await gs.refreshSector();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _row(GameState gs, String commodity, String label, int qty, double price, String mode) {
    // mode is the PORT's stance: 'sell' -> player can BUY; 'buy' -> player can SELL.
    final playerAction = mode == 'sell' ? 'buy' : 'sell';
    final actionLabel = playerAction == 'buy' ? 'BUY' : 'SELL';
    final actionColor = playerAction == 'buy' ? TWColors.accent2 : TWColors.warning;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          Expanded(
            child: Text('${price.toStringAsFixed(2)} cr · stock $qty',
                style: const TextStyle(color: TWColors.textDim, fontSize: 12)),
          ),
          SizedBox(
            width: 70,
            child: TextField(
              controller: _qty[commodity],
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8)),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 72,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: actionColor, padding: EdgeInsets.zero),
              onPressed: _busy ? null : () => _trade(gs, commodity, playerAction),
              child: Text(actionLabel, style: const TextStyle(fontSize: 12)),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final gs = context.watch<GameState>();
    final port = widget.port;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.storefront, color: TWColors.accent),
                const SizedBox(width: 8),
                Text(port.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
            const Divider(),
            _row(gs, 'fuel_ore', 'Fuel Ore', port.fuelOreQty, port.fuelOrePrice, port.fuelOreMode),
            _row(gs, 'organics', 'Organics', port.organicsQty, port.organicsPrice, port.organicsMode),
            _row(gs, 'equipment', 'Equipment', port.equipmentQty, port.equipmentPrice, port.equipmentMode),
          ],
        ),
      ),
    );
  }
}
