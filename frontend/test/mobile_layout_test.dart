import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:tradewars_app/models/models.dart';
import 'package:tradewars_app/screens/docs_screen.dart';
import 'package:tradewars_app/screens/sector_screen.dart';
import 'package:tradewars_app/state/game_state.dart';
import 'package:tradewars_app/theme.dart';
import 'package:tradewars_app/widgets/hud.dart';

/// Regression coverage for a real bug: at phone widths the HUD's stat
/// cluster and SectorScreen's stacked-column layout both overflowed
/// (RenderFlex overflow / unbounded ListView height). These tests pump the
/// exact narrow-width tree and assert nothing throws.
GameState _populatedGameState() {
  final gs = GameState();
  gs.player = Player.fromJson({
    'id': 1,
    'user_id': 1,
    'handle': 'CaptainJP',
    'ship_type_id': 1,
    'ship_name': 'Merchant Cruiser',
    'sector_id': 1,
    'credits': 5000,
    'turns_remaining': 1000,
    'experience': 0,
    'alignment': 0,
    'fighters': 20,
    'shields': 100,
    'holds_total': 20,
    'fuel_ore': 0,
    'organics': 0,
    'equipment': 0,
    'colonists': 0,
    'is_alive': 1,
  });
  gs.sector = SectorInfo.fromJson({
    'id': 1,
    'name': 'Sol — Federation Space',
    'x': 0,
    'y': 0,
    'region': 'federation',
    'is_federation': 1,
    'has_port': 1,
    'hazard': 0,
  });
  gs.warpsOut = [2, 81, 217];
  gs.port = Port.fromJson({
    'id': 1,
    'sector_id': 1,
    'name': 'Stardock Prime',
    'class': 0,
    'fuel_ore_qty': 20000,
    'fuel_ore_price': 45.0,
    'fuel_ore_mode': 'sell',
    'organics_qty': 20000,
    'organics_price': 110.0,
    'organics_mode': 'sell',
    'equipment_qty': 20000,
    'equipment_price': 170.0,
    'equipment_mode': 'sell',
    'credits': 50000000,
  });
  return gs;
}

Widget _wrap(Widget child, {required Size size}) {
  return MediaQuery(
    data: MediaQueryData(size: size),
    child: MaterialApp(
      theme: buildTwTheme(),
      home: ChangeNotifierProvider.value(
        value: _populatedGameState(),
        child: Scaffold(appBar: const Hud(), body: child),
      ),
    ),
  );
}

void main() {
  const phone = Size(360, 800);

  testWidgets('Hud does not overflow at phone width', (tester) async {
    await tester.pumpWidget(_wrap(const SizedBox.shrink(), size: phone));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('SectorScreen does not overflow or throw at phone width', (tester) async {
    await tester.pumpWidget(_wrap(const SectorScreen(), size: phone));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text('Stardock Prime'), findsOneWidget);
  });

  testWidgets('DocsBody renders its single-column list at phone width', (tester) async {
    await tester.pumpWidget(_wrap(const DocsBody(), size: phone));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text('Getting Started'), findsOneWidget);
  });
}
