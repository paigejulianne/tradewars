import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../services/api_client.dart';
import '../state/game_state.dart';
import '../theme.dart';

class CorpScreen extends StatefulWidget {
  const CorpScreen({super.key});

  @override
  State<CorpScreen> createState() => _CorpScreenState();
}

class _CorpScreenState extends State<CorpScreen> {
  Map<String, dynamic>? _mine;
  List<CorpSummary>? _list;
  bool _busy = false;
  final _name = TextEditingController();
  final _tag = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final gs = context.read<GameState>();
    if (gs.player?.corporationId != null) {
      final resp = await gs.api.corp(id: gs.player!.corporationId);
      setState(() => _mine = resp);
    } else {
      final resp = await gs.api.corp();
      setState(() {
        _list = (resp['corporations'] as List).map((e) => CorpSummary.fromJson(e as Map<String, dynamic>)).toList();
      });
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
      await _load();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final gs = context.watch<GameState>();

    return AbsorbPointer(
      absorbing: _busy,
      child: _mine != null ? _buildMine(gs) : _buildBrowse(gs),
    );
  }

  Widget _buildMine(GameState gs) {
    final corp = _mine!['corporation'] as Map<String, dynamic>;
    final members = _mine!['members'] as List;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${corp['name']} [${corp['tag']}]',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                Text('Treasury: ${corp['treasury']} credits', style: const TextStyle(color: TWColors.textDim)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        const Text('Members', style: TextStyle(fontWeight: FontWeight.bold, color: TWColors.accent)),
        for (final m in members)
          ListTile(
            leading: const Icon(Icons.person),
            title: Text(m['handle']),
            subtitle: Text('${m['role']} · XP ${m['experience']}'),
          ),
      ],
    );
  }

  Widget _buildBrowse(GameState gs) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Found a corporation', style: TextStyle(fontWeight: FontWeight.bold, color: TWColors.accent)),
                const SizedBox(height: 8),
                TextField(controller: _name, decoration: const InputDecoration(labelText: 'Name')),
                const SizedBox(height: 8),
                TextField(controller: _tag, decoration: const InputDecoration(labelText: 'Tag (2-8 chars)')),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () => _run(() async {
                    await gs.api.corpCreate(_name.text.trim(), _tag.text.trim());
                    await gs.refreshMe();
                  }),
                  child: const Text('Found corporation'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Text('Existing corporations', style: TextStyle(fontWeight: FontWeight.bold, color: TWColors.accent)),
        if (_list != null)
          for (final c in _list!)
            Card(
              child: ListTile(
                title: Text('${c.name} [${c.tag}]'),
                subtitle: Text('${c.memberCount} members · ${c.treasury} cr treasury'),
                trailing: ElevatedButton(
                  onPressed: () => _run(() async {
                    await gs.api.corpJoin(c.id);
                    await gs.refreshMe();
                  }),
                  child: const Text('Join'),
                ),
              ),
            ),
      ],
    );
  }
}
