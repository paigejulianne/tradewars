import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../state/game_state.dart';
import '../theme.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  List<LeaderboardEntry>? _rows;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final gs = context.read<GameState>();
    final resp = await gs.api.leaderboard();
    setState(() {
      _rows = (resp['leaderboard'] as List).map((e) => LeaderboardEntry.fromJson(e as Map<String, dynamic>)).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_rows == null) return const Center(child: CircularProgressIndicator());
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _rows!.length,
        itemBuilder: (context, i) {
          final r = _rows![i];
          return Card(
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: i < 3 ? TWColors.warning : TWColors.panelAlt,
                child: Text('${i + 1}', style: TextStyle(color: i < 3 ? Colors.black : TWColors.text)),
              ),
              title: Text('${r.handle}${r.corpTag != null ? ' [${r.corpTag}]' : ''}'),
              subtitle: Text('${r.shipName} · XP ${r.experience} · Alignment ${r.alignment}'),
              trailing: Text('${r.credits} cr', style: const TextStyle(fontWeight: FontWeight.bold, color: TWColors.warning)),
            ),
          );
        },
      ),
    );
  }
}
