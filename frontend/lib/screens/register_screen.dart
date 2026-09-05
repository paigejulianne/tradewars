import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/game_state.dart';
import '../theme.dart';
import '../widgets/starfield_background.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _email = TextEditingController();
  final _handle = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  String? _successMessage;

  Future<void> _submit(GameState gs) async {
    setState(() => _busy = true);
    final ok = await gs.register(_email.text.trim(), _password.text, _handle.text.trim());
    setState(() => _busy = false);
    if (ok) {
      setState(() => _successMessage =
          'Account created! Check $_email\'s inbox for a verification link, then come back and log in.');
    } else if (mounted && gs.authError != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(gs.authError!)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final gs = context.watch<GameState>();
    return Scaffold(
      appBar: AppBar(title: const Text('New Pilot Registration')),
      body: StarfieldBackground(
        child: Center(
          child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Card(
                margin: const EdgeInsets.all(24),
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: _successMessage != null
                      ? Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.mark_email_read, size: 48, color: TWColors.accent2),
                            const SizedBox(height: 16),
                            Text(_successMessage!, textAlign: TextAlign.center),
                            const SizedBox(height: 20),
                            ElevatedButton(
                              onPressed: () => Navigator.of(context).pop(),
                              child: const Text('Back to login'),
                            ),
                          ],
                        )
                      : Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text('Every captain starts with a Merchant Cruiser, 5,000 credits, '
                                'and 1,000 turns at Stardock in Sector 1.',
                                style: TextStyle(color: TWColors.textDim)),
                            const SizedBox(height: 20),
                            TextField(
                              controller: _handle,
                              decoration: const InputDecoration(
                                  labelText: 'Callsign', helperText: '3-20 chars: letters, numbers, - or _'),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _email,
                              decoration: const InputDecoration(labelText: 'Email'),
                              keyboardType: TextInputType.emailAddress,
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _password,
                              decoration: const InputDecoration(
                                  labelText: 'Password', helperText: 'At least 8 characters'),
                              obscureText: true,
                            ),
                            const SizedBox(height: 20),
                            SizedBox(
                              height: 48,
                              child: ElevatedButton(
                                onPressed: _busy ? null : () => _submit(gs),
                                child: _busy
                                    ? const SizedBox(
                                        height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                                    : const Text('CREATE ACCOUNT', style: TextStyle(fontWeight: FontWeight.bold)),
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
