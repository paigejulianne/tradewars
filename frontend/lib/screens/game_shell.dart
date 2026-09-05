import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/game_state.dart';
import '../theme.dart';
import '../widgets/hud.dart';
import 'corp_screen.dart';
import 'docs_screen.dart';
import 'galaxy_map_screen.dart';
import 'leaderboard_screen.dart';
import 'planet_screen.dart';
import 'sector_screen.dart';
import 'shipyard_screen.dart';

class GameShell extends StatefulWidget {
  const GameShell({super.key});

  @override
  State<GameShell> createState() => _GameShellState();
}

class _GameShellState extends State<GameShell> {
  int _index = 0;
  late final GameState _gs;

  static const _destinations = [
    (icon: Icons.travel_explore, label: 'Sector'),
    (icon: Icons.map, label: 'Galaxy Map'),
    (icon: Icons.warehouse, label: 'Shipyard'),
    (icon: Icons.public, label: 'Planet'),
    (icon: Icons.groups, label: 'Corporation'),
    (icon: Icons.leaderboard, label: 'Leaderboard'),
    (icon: Icons.menu_book, label: 'Manual'),
  ];

  @override
  void initState() {
    super.initState();
    _gs = context.read<GameState>();
    _gs.eventToasts.listen((ev) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: TWColors.panelAlt,
          content: Row(
            children: [
              const Icon(Icons.bolt, color: TWColors.warning, size: 18),
              const SizedBox(width: 8),
              Expanded(child: Text('${ev.title}: ${ev.message}')),
            ],
          ),
          duration: const Duration(seconds: 5),
        ),
      );
    });
  }

  Widget _body() {
    switch (_index) {
      case 0:
        return const SectorScreen();
      case 1:
        return const GalaxyMapScreen();
      case 2:
        return const ShipyardScreen();
      case 3:
        return const PlanetScreen();
      case 4:
        return const CorpScreen();
      case 5:
        return const LeaderboardScreen();
      default:
        return const DocsBody();
    }
  }

  @override
  Widget build(BuildContext context) {
    final gs = context.watch<GameState>();
    final wide = MediaQuery.of(context).size.width > 900;

    return Scaffold(
      appBar: const Hud(),
      drawer: wide
          ? null
          : Drawer(
              child: ListView(
                children: [
                  const DrawerHeader(child: Text('TRADEWARS', style: TextStyle(color: TWColors.accent, fontSize: 22))),
                  for (var i = 0; i < _destinations.length; i++)
                    ListTile(
                      leading: Icon(_destinations[i].icon),
                      title: Text(_destinations[i].label),
                      selected: i == _index,
                      onTap: () {
                        setState(() => _index = i);
                        Navigator.pop(context);
                      },
                    ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.logout, color: TWColors.danger),
                    title: const Text('Log out'),
                    onTap: () => gs.logout(),
                  ),
                ],
              ),
            ),
      body: Row(
        children: [
          if (wide)
            NavigationRail(
              selectedIndex: _index,
              onDestinationSelected: (i) => setState(() => _index = i),
              labelType: NavigationRailLabelType.all,
              leading: const SizedBox(height: 8),
              trailing: Expanded(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: IconButton(
                      icon: const Icon(Icons.logout, color: TWColors.danger),
                      tooltip: 'Log out',
                      onPressed: () => gs.logout(),
                    ),
                  ),
                ),
              ),
              destinations: [
                for (final d in _destinations)
                  NavigationRailDestination(icon: Icon(d.icon), label: Text(d.label)),
              ],
            ),
          if (wide) const VerticalDivider(width: 1),
          Expanded(child: _body()),
        ],
      ),
    );
  }
}
