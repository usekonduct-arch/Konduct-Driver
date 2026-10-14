import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
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

void main() {
  setUpAll(loadFonts);

  group('phone numbers', () {
    test('normalises Nigerian formats', () {
      expect(toE164('0803 123 4567'), '+2348031234567');
      expect(toE164('8031234567'), '+2348031234567');
      expect(toE164('+234 803 123 4567'), '+2348031234567');
      expect(toE164('2349031234567'), '+2349031234567');
    });
    test('rejects non-mobile numbers', () {
      expect(toE164('0123456789'), isNull);
      expect(toE164('080312345'), isNull);
    });
  });

  test('weak PINs are refused', () {
    for (final p in ['1111', '1234', '9876', '123456', '000000']) {
      expect(isWeakPin(p), isTrue, reason: p);
    }
    for (final p in ['2580', '1379', '204816']) {
      expect(isWeakPin(p), isFalse, reason: p);
    }
  });

  testWidgets('driver without an agent record is told how to get onboarded', (t) async {
    t.view.physicalSize = const Size(1080, 2340);
    t.view.devicePixelRatio = 2.75;
    addTearDown(t.view.reset);

    final repo = DemoAuthRepository();
    final auth = AuthController(repo);
    await t.pumpWidget(KonductApp(auth: auth));
    await settle(t, 2600);
    await t.runAsync(() async {
      await repo.sendCode('+2348030000000');
      await repo.verifyCode('123456');
    });
    await settle(t, 2500);
    expect(auth.stage, Stage.driverClaim);
    expect(find.text('We don\'t have you yet.'), findsOneWidget);

    await t.pumpWidget(const SizedBox());
    await settle(t, 1500);
  });

  testWidgets('an onboarded driver signs in, sets a PIN and lands on ready', (t) async {
    t.view.physicalSize = const Size(1080, 2340);
    t.view.devicePixelRatio = 2.75;
    addTearDown(t.view.reset);

    final repo = DemoAuthRepository();
    final auth = AuthController(repo);
    await t.pumpWidget(KonductApp(auth: auth));
    await settle(t, 2600);
    expect(auth.stage, Stage.signedOut);
    expect(find.text('Sign in'), findsOneWidget);

    await t.runAsync(() async {
      await repo.sendCode('+2348031234567');
      await repo.verifyCode('123456');
    });
    await settle(t, 2600);
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
}
