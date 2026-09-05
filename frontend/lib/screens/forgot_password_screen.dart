import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/api_client.dart';
import '../state/game_state.dart';
import '../widgets/starfield_background.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _email = TextEditingController();
  bool _busy = false;
  String? _message;

  Future<void> _submit(GameState gs) async {
    setState(() => _busy = true);
    try {
      final resp = await gs.api.forgotPassword(_email.text.trim());
      setState(() => _message = resp['message']?.toString() ?? 'If that email is registered, check your inbox.');
    } on ApiException catch (e) {
      setState(() => _message = e.message);
    } finally {
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final gs = context.read<GameState>();
    return Scaffold(
      appBar: AppBar(title: const Text('Reset Password')),
      body: StarfieldBackground(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Card(
              margin: const EdgeInsets.all(24),
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text("Enter your account email and we'll send a reset link."),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _email,
                      decoration: const InputDecoration(labelText: 'Email'),
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 16),
                    if (_message != null) Text(_message!),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _busy ? null : () => _submit(gs),
                      child: _busy
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('Send reset link'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
