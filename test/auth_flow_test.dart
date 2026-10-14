import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:konduct_driver/app/bootstrap.dart';
import 'package:konduct_driver/auth/auth_controller.dart';
import 'package:konduct_driver/auth/auth_repository.dart';
import 'package:konduct_driver/auth/demo_auth_repository.dart';
import 'package:konduct_driver/auth/screens/pin_screen.dart';
import 'package:konduct_driver/ui/kit.dart';

Future<void> settle(WidgetTester t, [int ms = 1200]) async {
  for (var i = 0; i < ms ~/ 100; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
}

Future<void> keypad(WidgetTester t, String digits) async {
  for (final d in digits.split('')) {
    await t.tap(find.descendant(of: find.byType(Keypad), matching: find.text(d)));
    await t.pump(const Duration(milliseconds: 60));
  }
}

/// Load the bundled fonts so text measures like it does on a phone (the test
/// default font draws every glyph as a 1em square).
Future<void> loadFonts() async {
  final families = {
    'Bricolage': ['BricolageGrotesque-500', 'BricolageGrotesque-700', 'BricolageGrotesque-800'],
    'Figtree': ['Figtree-400', 'Figtree-500', 'Figtree-600', 'Figtree-700', 'Figtree-800'],
    'JetBrainsMono': ['JetBrainsMono-500', 'JetBrainsMono-700'],
  };
  for (final e in families.entries) {
    final loader = FontLoader(e.key);
    for (final f in e.value) {
      loader.addFont(File('assets/fonts/$f.ttf').readAsBytes().then((b) => ByteData.view(b.buffer)));
    }
    await loader.load();
  }
}

void phoneSize(WidgetTester t) {
  t.view.physicalSize = const Size(1080, 2340);
  t.view.devicePixelRatio = 2.75;
  addTearDown(t.view.reset);
}

/// Welcome -> account screen (opens on "Sign in" for drivers) -> create the account.
Future<void> createAccount(WidgetTester t, String email, String password) async {
  await t.tap(find.text('Sign in'));
  await settle(t);
  await t.tap(find.text('Create account').first);
  await settle(t, 600);
  await t.enterText(find.byType(TextField).at(0), email);
  await t.enterText(find.byType(TextField).at(1), password);
  FocusManager.instance.primaryFocus?.unfocus();
  await settle(t, 400);
  await t.tap(find.text('Create account').last);
  await settle(t, 1600);
}

Future<void> enterCode(WidgetTester t, String code) async {
  await t.enterText(find.byType(TextField).first, code);
  FocusManager.instance.primaryFocus?.unfocus();
  await settle(t, 400);
  await t.tap(find.text('Link my vehicle'));
  await settle(t, 1800);
}

void main() {
  setUpAll(loadFonts);

  test('email shape check', () {
    expect(looksLikeEmail('tunde@gmail.com'), isTrue);
    for (final bad in ['tunde', 'tunde@', '@gmail.com', 'tunde@gmail', '']) {
      expect(looksLikeEmail(bad), isFalse, reason: bad);
    }
  });

  test('weak PINs are refused', () {
    for (final p in ['1111', '1234', '9876', '123456', '000000']) {
      expect(isWeakPin(p), isTrue, reason: p);
    }
    for (final p in ['2580', '1379', '204816']) {
      expect(isWeakPin(p), isFalse, reason: p);
    }
  });

  testWidgets('an onboarded driver links with the agent\'s code, sets a PIN and lands on ready', (t) async {
    phoneSize(t);
    final auth = AuthController(DemoAuthRepository());
    await t.pumpWidget(KonductApp(auth: auth));
    await settle(t, 2600);
    expect(auth.stage, Stage.signedOut);

    await createAccount(t, 'tunde@gmail.com', 'drive-safely-9');
    expect(auth.stage, Stage.driverClaim);
    expect(find.text('Enter your driver code.'), findsOneWidget);

    await enterCode(t, 'WRONG123');
    expect(auth.stage, Stage.driverClaim);
    expect(find.textContaining('doesn\'t match'), findsOneWidget);

    await enterCode(t, DemoAuthRepository.code.toLowerCase()); // typed in lowercase still works
    expect(auth.stage, Stage.pin);
    expect(find.text('Tunde Adebayo'), findsOneWidget);

    await keypad(t, '1379');
    await settle(t, 800);
    await keypad(t, '1379');
    await settle(t, 2400);
    expect(auth.stage, Stage.ready);
    expect(find.textContaining('Welcome,'), findsOneWidget);

    await t.pumpWidget(const SizedBox());
    await settle(t, 1500);
  });

  testWidgets('a driver no agent registered is told how to get onboarded', (t) async {
    phoneSize(t);
    final auth = AuthController(DemoAuthRepository());
    await t.pumpWidget(KonductApp(auth: auth));
    await settle(t, 2600);

    await createAccount(t, 'newdriver@gmail.com', 'drive-safely-9');
    await enterCode(t, DemoAuthRepository.code);
    expect(auth.stage, Stage.driverClaim);
    expect(find.text('We don\'t have you yet.'), findsOneWidget);
    expect(find.textContaining('newdriver@gmail.com'), findsWidgets);

    await t.pumpWidget(const SizedBox());
    await settle(t, 1500);
  });

  testWidgets('signing in with the wrong password is explained', (t) async {
    phoneSize(t);
    final auth = AuthController(DemoAuthRepository());
    await t.pumpWidget(KonductApp(auth: auth));
    await settle(t, 2600);
    await t.tap(find.text('Sign in'));
    await settle(t);
    await t.enterText(find.byType(TextField).at(0), 'tunde@gmail.com');
    await t.enterText(find.byType(TextField).at(1), 'not-my-password');
    FocusManager.instance.primaryFocus?.unfocus();
    await settle(t, 400);
    await t.tap(find.text('Sign in').last);
    await settle(t, 1600);
    expect(auth.stage, Stage.signedOut);
    expect(find.textContaining('don\'t match'), findsOneWidget);

    await t.pumpWidget(const SizedBox());
    await settle(t, 1500);
  });
}
