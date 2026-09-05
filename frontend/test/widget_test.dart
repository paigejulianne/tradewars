import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:tradewars_app/main.dart';

void main() {
  testWidgets('App boots to the login screen when logged out', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const TradeWarsApp());
    // The starfield background repeats forever, so pumpAndSettle would never
    // return — pump a bounded number of frames instead.
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(find.text('TRADEWARS'), findsOneWidget);
    expect(find.text('GALACTIC FRONTIER'), findsOneWidget);
  });
}
