import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../widgets/starfield_background.dart';

class ResetPasswordScreen extends StatefulWidget {
  final String token;
  final ApiClient api;
  final VoidCallback onDone;
  const ResetPasswordScreen({super.key, required this.token, required this.api, required this.onDone});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _password = TextEditingController();
  bool _busy = false;
  String? _message;
  bool _success = false;

  Future<void> _submit() async {
    setState(() => _busy = true);
    try {
      final resp = await widget.api.resetPassword(widget.token, _password.text);
      setState(() {
        _success = true;
        _message = resp['message']?.toString() ?? 'Password updated.';
      });
    } on ApiException catch (e) {
      setState(() => _message = e.message);
    } finally {
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Set a New Password')),
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
                  children: _success
                      ? [
                          Text(_message ?? 'Password updated.'),
                          const SizedBox(height: 16),
                          ElevatedButton(onPressed: widget.onDone, child: const Text('Back to login')),
                        ]
                      : [
                          TextField(
                            controller: _password,
                            decoration: const InputDecoration(labelText: 'New password'),
                            obscureText: true,
                          ),
                          const SizedBox(height: 16),
                          if (_message != null) Text(_message!),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _busy ? null : _submit,
                            child: _busy
                                ? const SizedBox(
                                    height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                                : const Text('Update password'),
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
