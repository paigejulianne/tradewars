import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/game_state.dart';
import '../theme.dart';
import '../widgets/starfield_background.dart';
import 'register_screen.dart';
import 'forgot_password_screen.dart';
import 'docs_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;

  Future<void> _submit(GameState gs) async {
    setState(() => _busy = true);
    final ok = await gs.login(_email.text.trim(), _password.text);
    setState(() => _busy = false);
    if (!ok && mounted && gs.authError != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(gs.authError!)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final gs = context.watch<GameState>();
    return Scaffold(
      body: StarfieldBackground(
        child: Center(
          child: SingleChildScrollView(
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
                      const Icon(Icons.rocket_launch, size: 48, color: TWColors.accent),
                      const SizedBox(height: 8),
                      Text('TRADEWARS',
                          textAlign: TextAlign.center,
                          style: Theme.of(context)
                              .textTheme
                              .headlineMedium
                              ?.copyWith(letterSpacing: 4, fontWeight: FontWeight.bold)),
                      const Text('GALACTIC FRONTIER',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: TWColors.textDim, letterSpacing: 3)),
                      const SizedBox(height: 24),
                      TextField(
                        controller: _email,
                        decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.email)),
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _password,
                        decoration: const InputDecoration(labelText: 'Password', prefixIcon: Icon(Icons.lock)),
                        obscureText: true,
                        onSubmitted: (_) => _busy ? null : _submit(gs),
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () => Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const ForgotPasswordScreen())),
                          child: const Text('Forgot password?'),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 48,
                        child: ElevatedButton(
                          onPressed: _busy ? null : () => _submit(gs),
                          child: _busy
                              ? const SizedBox(
                                  height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Text('LAUNCH', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        alignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          const Text("New pilot?", style: TextStyle(color: TWColors.textDim)),
                          TextButton(
                            onPressed: () => Navigator.of(context)
                                .push(MaterialPageRoute(builder: (_) => const RegisterScreen())),
                            child: const Text('Create an account'),
                          ),
                        ],
                      ),
                      TextButton.icon(
                        onPressed: () => Navigator.of(context)
                            .push(MaterialPageRoute(builder: (_) => const DocsScreen())),
                        icon: const Icon(Icons.menu_book, size: 18),
                        label: const Text('Read the manual'),
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
