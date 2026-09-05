import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'screens/game_shell.dart';
import 'screens/login_screen.dart';
import 'screens/reset_password_screen.dart';
import 'state/game_state.dart';
import 'theme.dart';

void main() {
  runApp(const TradeWarsApp());
}

class TradeWarsApp extends StatefulWidget {
  const TradeWarsApp({super.key});

  @override
  State<TradeWarsApp> createState() => _TradeWarsAppState();
}

class _TradeWarsAppState extends State<TradeWarsApp> {
  late final GameState _gs;
  String? _resetToken;

  @override
  void initState() {
    super.initState();
    _gs = GameState();

    final uri = Uri.base;
    if (uri.path.contains('reset-password') && uri.queryParameters['token'] != null) {
      _resetToken = uri.queryParameters['token'];
    } else {
      _gs.bootstrap();
    }
  }

  @override
  void dispose() {
    _gs.ws?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _gs,
      child: MaterialApp(
        title: 'TradeWars: Galactic Frontier',
        debugShowCheckedModeBanner: false,
        theme: buildTwTheme(),
        home: _resetToken != null
            ? ResetPasswordScreen(
                token: _resetToken!,
                api: _gs.api,
                onDone: () => setState(() {
                  _resetToken = null;
                  _gs.bootstrap();
                }),
              )
            : const _RootRouter(),
      ),
    );
  }
}

class _RootRouter extends StatelessWidget {
  const _RootRouter();

  @override
  Widget build(BuildContext context) {
    final gs = context.watch<GameState>();
    switch (gs.authStatus) {
      case AuthStatus.unknown:
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      case AuthStatus.loggedIn:
        return const GameShell();
      case AuthStatus.loggedOut:
      case AuthStatus.needsVerification:
        return const LoginScreen();
    }
  }
}
