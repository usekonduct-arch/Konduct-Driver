import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/l10n.dart';

/// The Konduct Driver home-screen widget (android/app/src/main/kotlin/.../KonductWidget.kt): an
/// "Earnings" button and, if the driver turns it on, what they've made today as of the last time
/// the app was open. Hidden unless asked for, since anyone can see a home screen.
abstract final class HomeWidgetSync {
  static const _showKey = 'konduct.widgetShowsEarnings';
  static const _android = 'KonductWidget';

  /// The figure last written, so turning the setting on can show it straight away.
  static String? _last;

  /// Writes the widget again, for example in a new language.
  static Future<void> refresh() => update(balanceText: _last);

  static Future<bool> showsBalance() async {
    try {
      return (await SharedPreferences.getInstance()).getBool(_showKey) ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> setShowsBalance(bool on, {String? balanceText}) async {
    try {
      await (await SharedPreferences.getInstance()).setBool(_showKey, on);
    } catch (_) {}
    await update(balanceText: balanceText ?? _last);
  }

  /// [balanceText]: today's earnings like "₦4,250"; null when signed out or not loaded.
  static Future<void> update({String? balanceText}) async {
    _last = balanceText;
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      final show = await showsBalance();
      await HomeWidget.saveWidgetData<String>('title', 'Konduct Driver');
      await HomeWidget.saveWidgetData<String>('value', show && balanceText != null ? balanceText : '');
      await HomeWidget.saveWidgetData<String>('subtitle', show && balanceText != null ? tr("Today's earnings") : tr('Tap to see your earnings'));
      await HomeWidget.saveWidgetData<String>('button', tr('Earnings'));
      await HomeWidget.saveWidgetData<String>('buttonLink', 'konduct-widget://reports');
      await HomeWidget.updateWidget(androidName: _android);
    } catch (e) {
      debugPrint('home widget update failed: $e');
    }
  }
}
