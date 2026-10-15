import 'package:flutter/material.dart' hide Text;
import 'package:flutter/widgets.dart' as w show Text;
import 'package:flutter_test/flutter_test.dart';
import 'package:konduct_driver/app/intents.dart';
import 'package:konduct_driver/app/version_check.dart';
import 'package:konduct_driver/l10n/l10n.dart';
import 'package:konduct_driver/l10n/strings_ha.dart';
import 'package:konduct_driver/l10n/strings_pcm.dart';
import 'package:konduct_driver/l10n/strings_yo.dart';
import 'package:konduct_driver/earnings/shift.dart';
import 'package:konduct_driver/l10n/text.dart';

final _slot = RegExp(r'\{([a-zA-Z0-9_]+)\}');
List<String> _slots(String s) => _slot.allMatches(s).map((m) => m.group(1)!).toList()..sort();

void main() {
  tearDown(() => L10n.instance.debugSet(Lang.en));

  group('translation tables', () {
    for (final (name, table) in [('Pidgin', pcmStrings), ('Yoruba', yoStrings), ('Hausa', haStrings)]) {
      test('$name keeps every placeholder and never repeats one', () {
        for (final e in table.entries) {
          final keys = _slots(e.key);
          expect(keys.toSet().length, keys.length, reason: 'repeated placeholder in "${e.key}"');
          expect(_slots(e.value), keys, reason: '"${e.key}" → "${e.value}"');
          expect(e.value.trim(), isNotEmpty, reason: e.key);
        }
      });
    }

    test('every language translates the same English', () {
      expect(yoStrings.keys.toSet(), pcmStrings.keys.toSet());
      expect(haStrings.keys.toSet(), pcmStrings.keys.toSet());
    });
  });

  group('tr', () {
    test('English, and text without a translation, come back unchanged', () {
      expect(tr('Scan to pay'), 'Scan to pay');
      L10n.instance.debugSet(Lang.yo);
      expect(tr('OS 452 KJA'), 'OS 452 KJA');
      expect(tr('Adaeze'), 'Adaeze');
    });

    test('exact text, in each language', () {
      L10n.instance.debugSet(Lang.yo);
      expect(tr('Scan to pay'), 'Sikáànù kí o sanwó');
      L10n.instance.debugSet(Lang.ha);
      expect(tr('Top up'), 'Ƙara kuɗi');
      L10n.instance.debugSet(Lang.pcm);
      expect(tr('Sign out'), 'Sign out');
    });

    test('templates carry amounts, names and plates across', () {
      L10n.instance.debugSet(Lang.yo);
      expect(tr('Pay ₦600'), 'San ₦600');
      expect(tr('Hi, Ada'), 'Báwo ni, Ada');
      L10n.instance.debugSet(Lang.ha);
      expect(tr('You have ₦100. Top up at least ₦100 to pay this fare.'), 'Kuna da ₦100. Ku ƙara aƙalla ₦100 don biyan wannan kuɗin mota.');
      expect(tr('Me + 2 friends'), 'Ni + abokai 2');
    });

    test('a value that is itself app text is translated too', () {
      L10n.instance.debugSet(Lang.pcm);
      // A server message inside the scan screen's own sentence.
      expect(
        tr('Not enough in your wallet. Top up and scan again. Scan again to pay for 2.'),
        'Money no reach for your wallet. Top up and scan again. Scan again make you pay for 2.',
      );
    });

    test('parts joined with " · " are translated one by one', () {
      L10n.instance.debugSet(Lang.yo);
      expect(tr('Today, 14:05 · 2 riders · Refunded'), 'Òní, 14:05 · Èrò 2 · A ti dá a padà');
    });

    test('with values, the text is a template', () {
      L10n.instance.debugSet(Lang.ha);
      expect(tr('Code added. You get {amount} after your first ride.', {'amount': '₦100'}), 'An ƙara lambar. Za ku samu ₦100 bayan hawanku na farko.');
      L10n.instance.debugSet(Lang.en);
      expect(tr('Code added. You get {amount} after your first ride.', {'amount': '₦100'}), 'Code added. You get ₦100 after your first ride.');
    });

    test('month names follow the language', () {
      L10n.instance.debugSet(Lang.yo);
      expect(monthShort(10), 'Ọ̀wà');
      L10n.instance.debugSet(Lang.ha);
      expect(monthShort(1), 'Jan');
    });
  });

  testWidgets('every Text on screen changes language at once, const ones too', (t) async {
    await t.pumpWidget(
      L10nScope(
        child: const MaterialApp(home: Scaffold(body: Column(children: [Text('Scan to pay'), Text('Top up')]))),
      ),
    );
    expect(find.text('Scan to pay'), findsOneWidget);
    L10n.instance.debugSet(Lang.yo);
    await t.pump();
    expect(find.text('Sikáànù kí o sanwó'), findsOneWidget);
    expect(find.text('Fi owó kún'), findsOneWidget);
    L10n.instance.debugSet(Lang.en);
    await t.pump();
    expect(find.text('Top up'), findsOneWidget);
  });

  testWidgets('text people typed is never translated', (t) async {
    L10n.instance.debugSet(Lang.yo);
    await t.pumpWidget(L10nScope(child: const MaterialApp(home: Text('Top up', translate: false))));
    expect(t.widget<w.Text>(find.byType(w.Text)).data, 'Top up');
  });

  group('links into the app', () {
    test('konductdriver:// links and widget taps become in-app screens', () {
      expect(AppIntents.linkFor(Uri.parse('konductdriver://payout')), 'app:payout');
      expect(AppIntents.linkFor(Uri.parse('konduct-widget://reports')), 'app:reports');
      expect(AppIntents.linkFor(Uri.parse('konductdriver://shift')), 'app:shift');
    });

    test("the student app's links and anything else only open the app", () {
      expect(AppIntents.linkFor(Uri.parse('konduct://pay?code=AB12CD')), isNull);
      expect(AppIntents.linkFor(Uri.parse('https://konduct.app/pay/AB12CD')), isNull);
      // Dots can't climb anywhere: the path is normalised and only a plain argument is left.
      expect(AppIntents.linkFor(Uri.parse('konductdriver://bank/../../x')), 'app:bank/x');
      expect(AppIntents.linkFor(Uri.parse('konductdriver://unknown')), isNull);
    });
  });

  testWidgets('the daily goal bar says how far there is to go, in the language', (t) async {
    await t.pumpWidget(L10nScope(child: MaterialApp(home: Scaffold(body: GoalBar(earned: 400000, goal: 1000000, onTap: () {})))));
    expect(find.text('₦6,000 to your ₦10,000 goal'), findsOneWidget);
    L10n.instance.debugSet(Lang.ha);
    await t.pump();
    expect(find.text('Saura ₦6,000 zuwa burinku na ₦10,000'), findsOneWidget);
    L10n.instance.debugSet(Lang.en);
    await t.pumpWidget(L10nScope(child: MaterialApp(home: Scaffold(body: GoalBar(earned: 1200000, goal: 1000000, onTap: () {})))));
    expect(find.text('Goal reached: ₦10,000'), findsOneWidget);
  });

  group('version check', () {
    test('below the minimum must update; below the latest may', () {
      final v = VersionCheck.instance..build = 5;
      v.apply({'minBuild': 6, 'latestBuild': 8, 'updateUrl': 'https://konduct.app/get'});
      expect(v.mustUpdate, isTrue);
      v.apply({'minBuild': 3, 'latestBuild': 8, 'updateUrl': 'https://konduct.app/get'});
      expect((v.mustUpdate, v.canUpdate, v.updateUrl), (false, true, 'https://konduct.app/get'));
      v.apply({'minBuild': 3, 'latestBuild': 5, 'updateUrl': 'http://insecure.example'});
      expect((v.mustUpdate, v.canUpdate, v.updateUrl), (false, false, null));
      v.apply(null);
      expect((v.mustUpdate, v.canUpdate), (false, false));
    });
  });
}
