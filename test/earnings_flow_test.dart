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
    await t.scrollUntilVisible(find.text('To bank ****4567'), 300, scrollable: find.byType(Scrollable).first);
    expect(find.text('To bank ****4567'), findsOneWidget);
    await t.pumpWidget(const SizedBox());
    await settle(t, 1500);
  });

  testWidgets('a driver sees their rating, sets the trip route, starts a new trip, and sees the parks', (t) async {
    await openHome(t);
    expect(find.text('★ 4.6 from 23 ratings'), findsOneWidget);
    expect(find.text('Shasha park → Main gate'), findsOneWidget);
    expect(find.text('SEATS PAID BY SCAN'), findsOneWidget);
    expect(find.text('of 7'), findsOneWidget);
    expect(find.text('About 4 free'), findsOneWidget);

    // Back the other way: the sheet offers the reverse route, and the seats clear.
    await t.tap(find.text('New trip · bus emptied'));
    await settle(t, 900);
    expect(find.text('Start a new trip'), findsOneWidget);
    await t.tap(find.text('Start trip'));
    await settle(t, 1200);
    expect(find.text('Main gate → Shasha park'), findsOneWidget);
    expect(find.text('About 7 free'), findsOneWidget);

    // A mid-trip correction keeps the seats.
    await t.tap(find.text('Change'));
    await settle(t, 900);
    await t.tap(find.text('Senate building').last);
    await settle(t, 300);
    await t.tap(find.text('Save route'));
    await settle(t, 1200);
    expect(find.text('Main gate → Senate building'), findsOneWidget);
    await t.scrollUntilVisible(find.text('Shasha park'), 200, scrollable: find.byType(Scrollable).first);
    expect(find.text('BUSES AT THE PARKS'), findsOneWidget);
    expect(find.text('Main Campus park'), findsOneWidget);
    await t.pumpWidget(const SizedBox());
    await settle(t, 1500);
  });

  testWidgets('a driver changes their password from settings', (t) async {
    await openHome(t);
    await t.tap(find.bySemanticsLabel('Account'));
    await settle(t, 900);
    await t.scrollUntilVisible(find.text('Change password'), 200, scrollable: find.byType(Scrollable).first);
    await t.tap(find.text('Change password'));
    await settle(t, 900);
    final fields = find.byType(TextField);
    await t.enterText(fields.at(0), 'drive-safely-9');
    await t.enterText(fields.at(1), 'a-new-password-4');
    await t.enterText(fields.at(2), 'a-new-password-4');
    await t.tap(find.text('Change password').last);
    await settle(t, 1200);
    expect(find.text('Password changed. Use the new one next time you sign in.'), findsOneWidget);
    await t.pumpWidget(const SizedBox());
    await settle(t, 1500);
  });

  testWidgets('a driver messages support from settings and sees the reply', (t) async {
    await openHome(t);
    await t.tap(find.bySemanticsLabel('Account'));
    await settle(t, 900);
    await t.scrollUntilVisible(find.text('Help & support'), 200, scrollable: find.byType(Scrollable).first);
    await t.tap(find.text('Help & support'));
    await settle(t, 900);
    await t.tap(find.text('New message'));
    await settle(t, 900);
    await t.tap(find.text('Payment or wallet'));
    await t.enterText(find.byType(TextField), 'My payout is late.');
    FocusManager.instance.primaryFocus?.unfocus();
    await settle(t, 300);
    await t.tap(find.text('Send'));
    await settle(t, 3500);
    expect(find.text('My payout is late.'), findsOneWidget);
    expect(find.text('Konduct support · Bisi'), findsOneWidget);
    await t.pumpWidget(const SizedBox());
    await settle(t, 1500);
  });
}
