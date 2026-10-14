import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:konduct_driver/auth/auth_repository.dart';
import 'package:konduct_driver/earnings/demo_driver_api.dart';
import 'package:konduct_driver/earnings/screens/home_screen.dart';
import 'package:konduct_driver/theme/tokens.dart';

import 'auth_flow_test.dart' show keypad, loadFonts, phoneSize, settle;

Future<void> openHome(WidgetTester t) async {
  phoneSize(t);
  await t.pumpWidget(MaterialApp(
    theme: buildTheme(Palette.driver, dark: true),
    home: HomeScreen(api: DemoDriverApi(), session: const Session(uid: 'd1', email: 'tunde@gmail.com', role: 'driver', pinSet: true, name: 'Tunde Adebayo'), onSignOut: () {}),
  ));
  await settle(t, 1500);
}

void main() {
  setUpAll(loadFonts);

  testWidgets('a driver sees what they earned and what is waiting to be paid out', (t) async {
    await openHome(t);
    expect(find.text('₦3,400'), findsOneWidget);
    expect(find.text('Today: ₦3,400'), findsOneWidget); // the undone fare doesn't count
    expect(find.text('13 riders'), findsOneWidget);
    expect(find.textContaining('Undone by rider'), findsOneWidget);
    expect(find.text('Add a bank account to get paid.'), findsOneWidget);
    await t.pumpWidget(const SizedBox());
    await settle(t, 1500);
  });

  testWidgets('a driver adds a bank account, then pays out the whole balance', (t) async {
    await openHome(t);
    await t.tap(find.text('Add bank account'));
    await settle(t, 900);
    await t.tap(find.text('Add a bank account'));
    await settle(t, 900);

    await t.tap(find.text('Choose your bank'));
    await settle(t, 900);
    await t.tap(find.text('OPay'));
    await settle(t, 600);
    await t.enterText(find.byType(TextField), '8031234567');
    FocusManager.instance.primaryFocus?.unfocus();
    await settle(t, 300);
    await t.tap(find.text('Continue'));
    await settle(t, 900);
    await t.enterText(find.byType(TextField).last, 'drive-safely-9');
    await settle(t, 300);
    await t.tap(find.text('Confirm'));
    await settle(t, 900);
    await keypad(t, '1379');
    await t.tap(find.text('Confirm'));
    await settle(t, 1200);
    expect(find.textContaining('TUNDE ADEBAYO'), findsOneWidget);
    await t.tap(find.text('OK'));
    await settle(t, 900);

    await settle(t, 2500); // approved
    await t.tap(find.byIcon(Icons.arrow_back_rounded));
    await settle(t, 900);
    expect(find.text('Paid to ****4567 every evening at 9:30pm.'), findsOneWidget);

    await t.tap(find.text('Pay out now'));
    await settle(t, 900);
    await t.tap(find.text('Pay out ₦3,400'));
    await settle(t, 900);
    await keypad(t, '1379');
    await t.tap(find.text('Confirm'));
    await settle(t, 1500);
    expect(find.textContaining('₦3,400 is on its way to ****4567'), findsOneWidget);
    expect(find.text('₦0'), findsOneWidget);
    expect(find.text('To bank ****4567'), findsOneWidget);
    await t.pumpWidget(const SizedBox());
    await settle(t, 1500);
  });
}
