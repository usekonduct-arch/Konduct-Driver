import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:konduct_driver/auth/auth_repository.dart';
import 'package:konduct_driver/earnings/demo_driver_api.dart';
import 'package:konduct_driver/earnings/screens/home_screen.dart';
import 'package:konduct_driver/messages/messages_api.dart';
import 'package:konduct_driver/messages/messages_ui.dart';
import 'package:konduct_driver/messages/voice.dart';
import 'package:konduct_driver/theme/tokens.dart';

import 'auth_flow_test.dart' show loadFonts, phoneSize, settle;

Future<void> openHome(WidgetTester t, DemoMessagesApi messages) async {
  phoneSize(t);
  await t.pumpWidget(
    MaterialApp(
      theme: buildTheme(Palette.driver, dark: true),
      home: HomeScreen(
        api: DemoDriverApi(messages: messages),
        session: const Session(uid: 'd1', email: 'tunde@gmail.com', role: 'driver', pinSet: true, name: 'Tunde Adebayo'),
        onSignOut: () {},
      ),
    ),
  );
  await settle(t, 1500);
}

Future<void> done(WidgetTester t) async {
  await t.pumpWidget(const SizedBox());
  await settle(t, 1500);
}

void main() {
  setUpAll(loadFonts);

  test('money alerts are spoken with the amount', () {
    expect(Voice.sentenceFor('fare.received', {'amountKobo': '60000', 'riders': '3'}), 'Payment received. 600 naira, from 3 riders.');
    expect(Voice.sentenceFor('fare.received', {'amountKobo': '20000', 'riders': '1'}), 'Payment received. 200 naira.');
    expect(Voice.sentenceFor('fare.received', const {}), 'Payment received.');
    expect(Voice.sentenceFor('wallet.funded', {'amountKobo': '125050'}), 'Your wallet has been topped up with 1250 naira 50 kobo.');
    expect(Voice.sentenceFor('payout.paid', {'amountKobo': '340000'}), '3400 naira has been sent to your bank.');
    expect(Voice.sentenceFor('support.reply', const {}), isNull);
  });

  testWidgets('with no ads the carousel takes no space at all', (t) async {
    await openHome(t, DemoMessagesApi());
    expect(t.getSize(find.byType(AdCarousel)).height, 0);
    await done(t);
  });

  testWidgets('a carousel ad shows on the driver home', (t) async {
    await openHome(
      t,
      DemoMessagesApi(
        ads: const [Ad(id: 'ad1', placement: AdPlacement.carousel, imageUrl: 'https://example.com/a.jpg', title: 'Fuel discount this week')],
      ),
    );
    expect(find.text('Fuel discount this week'), findsOneWidget);
    await done(t);
  });

  testWidgets('a fare push while the app is open shows a banner', (t) async {
    final messages = DemoMessagesApi();
    await openHome(t, messages);
    messages.simulatePush(const PushEvent(title: '₦600 received', body: '3 riders · KD-7Q4M2P', kind: 'fare.received'));
    await settle(t, 600);
    expect(find.text('₦600 received'), findsOneWidget);
    await done(t);
  });

  testWidgets('a popup message opens once and the bell clears', (t) async {
    final messages = DemoMessagesApi(
      notices: [Notice(id: 'n1', title: 'Park closed', body: 'Shasha park is closed today.', at: DateTime.now(), personal: true, popup: true)],
    );
    await openHome(t, messages);
    await settle(t, 2500);
    expect(find.text('Park closed'), findsOneWidget);
    await t.tap(find.text('OK'));
    await settle(t, 3000);
    expect(find.text('Park closed'), findsNothing);
    expect(find.bySemanticsLabel('Notifications'), findsOneWidget);
    await done(t);
  });
}
