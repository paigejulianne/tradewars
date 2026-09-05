import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../state/game_state.dart';
import '../theme.dart';

class ChatPanel extends StatefulWidget {
  final String scope;
  const ChatPanel({super.key, required this.scope});

  @override
  State<ChatPanel> createState() => _ChatPanelState();
}

class _ChatPanelState extends State<ChatPanel> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();

  void _send(GameState gs) {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    if (gs.ws != null && gs.wsConnected) {
      gs.ws!.sendChat(widget.scope, text);
    } else {
      gs.api.chatSend(widget.scope, text).catchError((_) => <String, dynamic>{});
    }
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    final gs = context.watch<GameState>();
    final List<ChatMessage> messages = widget.scope == 'sector' ? gs.sectorChat : const <ChatMessage>[];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${widget.scope == 'sector' ? 'Sector' : 'Galaxy'} Comms',
                style: const TextStyle(fontWeight: FontWeight.bold, color: TWColors.accent)),
            const Divider(),
            SizedBox(
              height: 180,
              child: messages.isEmpty
                  ? const Center(child: Text('No chatter yet.', style: TextStyle(color: TWColors.textDim)))
                  : ListView.builder(
                      controller: _scroll,
                      itemCount: messages.length,
                      itemBuilder: (context, i) {
                        final m = messages[i];
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: RichText(
                            text: TextSpan(
                              style: const TextStyle(fontSize: 13, color: TWColors.text),
                              children: [
                                TextSpan(
                                    text: '${m.handle}: ',
                                    style: const TextStyle(color: TWColors.accent2, fontWeight: FontWeight.bold)),
                                TextSpan(text: m.message),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(isDense: true, hintText: 'Message...'),
                    onSubmitted: (_) => _send(gs),
                  ),
                ),
                IconButton(icon: const Icon(Icons.send, color: TWColors.accent), onPressed: () => _send(gs)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
