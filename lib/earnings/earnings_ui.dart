import 'package:flutter/material.dart' hide Text;
import 'package:flutter/services.dart';

import '../l10n/l10n.dart';
import '../l10n/text.dart';
import '../security/biometric.dart';
import '../theme/tokens.dart';
import '../ui/flow_scaffold.dart';
import '../ui/kit.dart';

/// Slides the next screen in from the right, fading, like the sign-up steps.
Future<T?> pushScreen<T>(BuildContext context, Widget screen) => Navigator.of(context).push<T>(
  PageRouteBuilder<T>(
    transitionDuration: const Duration(milliseconds: 480),
    reverseTransitionDuration: const Duration(milliseconds: 320),
    pageBuilder: (_, _, _) => screen,
    transitionsBuilder: (_, a, _, child) {
      final c = CurvedAnimation(parent: a, curve: K.outExpo, reverseCurve: Curves.easeInCubic);
      return SlideTransition(
        position: Tween(begin: const Offset(0.25, 0), end: Offset.zero).animate(c),
        child: FadeTransition(opacity: c, child: child),
      );
    },
  ),
);

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

String _hm(DateTime t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

/// "Just now", "4 min ago", "Today, 14:05", "Yesterday, 09:12", "12 Oct, 09:12".
String whenText(DateTime t, {DateTime? now}) {
  final n = now ?? DateTime.now();
  final d = n.difference(t);
  if (d.inSeconds < 60) return 'Just now';
  if (d.inMinutes < 60) return '${d.inMinutes} min ago';
  final today = DateTime(n.year, n.month, n.day);
  final day = DateTime(t.year, t.month, t.day);
  if (day == today) return 'Today, ${_hm(t)}';
  if (day == today.subtract(const Duration(days: 1))) return 'Yesterday, ${_hm(t)}';
  return '${t.day} ${tr(_months[t.month - 1])}${t.year == n.year ? '' : ' ${t.year}'}, ${_hm(t)}';
}

/// A future moment: "today at 14:05", "tomorrow at 09:00", "12 Oct at 09:00".
String untilText(DateTime t, {DateTime? now}) {
  final n = now ?? DateTime.now();
  final today = DateTime(n.year, n.month, n.day);
  final day = DateTime(t.year, t.month, t.day);
  if (day == today) return 'today at ${_hm(t)}';
  if (day == today.add(const Duration(days: 1))) return 'tomorrow at ${_hm(t)}';
  return '${t.day} ${tr(_months[t.month - 1])} at ${_hm(t)}';
}

/// Plain screen frame for everything after sign-up: round back button, title, scrolling body.
/// With [onRefresh] the body can be pulled down to refresh.
class PageFrame extends StatelessWidget {
  const PageFrame({super.key, required this.title, required this.child, this.kicker, this.bottom, this.trailing, this.scroll = true, this.onRefresh});
  final String title;
  final String? kicker;
  final Widget child;
  final Widget? bottom;
  final Widget? trailing;
  final bool scroll;
  final Future<void> Function()? onRefresh;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final body = Padding(padding: const EdgeInsets.fromLTRB(20, 0, 20, 16), child: child);
    final scrolling = onRefresh == null
        ? SingleChildScrollView(child: body)
        : RefreshIndicator(
            onRefresh: onRefresh!,
            color: K.ink,
            backgroundColor: K.yellow,
            child: SingleChildScrollView(physics: const AlwaysScrollableScrollPhysics(), child: body),
          );
    final dark = Theme.of(context).brightness == Brightness.dark;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: p.bg,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: SizedBox(
                  height: 48,
                  child: Row(
                    children: [
                      RoundIconButton(icon: Icons.arrow_back_rounded, onTap: () => Navigator.of(context).maybePop()),
                      const Spacer(),
                      ?trailing,
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (kicker != null) ...[Entrance(child: Text(kicker!.toUpperCase(), style: KText.kicker(p.subtle))), const SizedBox(height: 10)],
                    Entrance(
                      delay: const Duration(milliseconds: 60),
                      child: Text(title, style: KText.title(p.text)),
                    ),
                  ],
                ),
              ),
              Expanded(child: scroll ? scrolling : body),
              if (bottom != null) Padding(padding: const EdgeInsets.fromLTRB(20, 0, 20, 16), child: bottom),
            ],
          ),
        ),
      ),
    );
  }
}

class RoundIconButton extends StatelessWidget {
  const RoundIconButton({super.key, required this.icon, this.onTap, this.dark = false, this.tooltip});
  final IconData icon;
  final VoidCallback? onTap;
  final bool dark;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final button = Pressable(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: dark ? Colors.white.withValues(alpha: 0.12) : p.surface,
          shape: BoxShape.circle,
          border: Border.all(color: dark ? Colors.white.withValues(alpha: 0.16) : p.border),
        ),
        child: Icon(icon, color: dark ? Colors.white : p.text, size: 22),
      ),
    );
    return Semantics(button: true, label: tooltip == null ? null : tr(tooltip!), child: button);
  }
}

/// White rounded card.
class Panel extends StatelessWidget {
  const Panel({super.key, required this.child, this.padding = const EdgeInsets.all(18), this.color});
  final Widget child;
  final EdgeInsets padding;
  final Color? color;
  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? p.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: p.border),
      ),
      child: child,
    );
  }
}

/// Bottom sheet asking for the transaction PIN. Returns the PIN, or null if dismissed.
/// The app doesn't know if the PIN is 4 or 6 digits, so Confirm works at either length.
///
/// With [biometric], someone who turned on fingerprint payments is asked for their fingerprint or
/// face first, and the sheet only opens if they cancel it (with a button to try again). Not for
/// changing the PIN, where the person must type it.
Future<String?> askPin(BuildContext context, {required String title, String? message, String? error, bool biometric = false}) async {
  final bio = BiometricPin.instance;
  bio.lastWasSaved = false;
  final useBio = biometric && await bio.enabled();
  if (useBio && error == null) {
    final saved = await bio.unlock(tr(title));
    if (saved != null) {
      bio.lastWasSaved = true;
      return saved;
    }
  }
  if (!context.mounted) return null;
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _PinSheet(title: title, message: message, error: error, biometric: useBio),
  );
}

class _PinSheet extends StatefulWidget {
  const _PinSheet({required this.title, this.message, this.error, this.biometric = false});
  final String title;
  final String? message, error;
  final bool biometric;
  @override
  State<_PinSheet> createState() => _PinSheetState();
}

class _PinSheetState extends State<_PinSheet> {
  String _pin = '';

  void _type(String d) {
    if (_pin.length >= 6) return;
    setState(() => _pin += d);
  }

  Future<void> _useBiometric() async {
    final saved = await BiometricPin.instance.unlock(tr(widget.title));
    if (saved == null || !mounted) return;
    BiometricPin.instance.lastWasSaved = true;
    Navigator.of(context).pop(saved);
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final ok = _pin.length == 4 || _pin.length == 6;
    return Container(
      decoration: BoxDecoration(
        color: p.bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(20, 12, 20, 16 + MediaQuery.paddingOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44,
            height: 5,
            decoration: BoxDecoration(color: p.border, borderRadius: BorderRadius.circular(3)),
          ),
          const SizedBox(height: 18),
          Text(widget.title, style: KText.h3(p.text), textAlign: TextAlign.center),
          if (widget.message != null) ...[const SizedBox(height: 6), Text(widget.message!, style: KText.small(p.subtle), textAlign: TextAlign.center)],
          const SizedBox(height: 22),
          SizedBox(
            height: 26,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < (_pin.length > 4 ? 6 : 4); i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 260),
                    curve: K.springy,
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    width: i < _pin.length ? 20 : 16,
                    height: i < _pin.length ? 20 : 16,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: i < _pin.length ? K.yellow : Colors.transparent,
                      border: Border.all(color: i < _pin.length ? K.yellow : p.subtle, width: 2.2),
                    ),
                  ),
              ],
            ),
          ),
          ErrorLine(widget.error),
          const SizedBox(height: 16),
          Keypad(onDigit: _type, onBackspace: () => setState(() => _pin = _pin.isEmpty ? '' : _pin.substring(0, _pin.length - 1))),
          const SizedBox(height: 12),
          KButton(label: 'Confirm', onTap: ok ? () => Navigator.of(context).pop(_pin) : null),
          if (widget.biometric) ...[
            const SizedBox(height: 4),
            TextButton.icon(
              onPressed: _useBiometric,
              icon: Icon(Icons.fingerprint_rounded, color: p.text),
              label: Text('Use fingerprint or face', style: KText.body(p.text).copyWith(fontWeight: FontWeight.w700)),
            ),
          ],
        ],
      ),
    );
  }
}

/// Small rounded label.
class Tag extends StatelessWidget {
  const Tag(this.text, {super.key, this.color = K.yellow, this.icon});
  final String text;
  final Color color;
  final IconData? icon;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(color: color.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(999)),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[Icon(icon, size: 14, color: color == K.yellow ? K.ink : color), const SizedBox(width: 5)],
        Text(text, style: KText.small(color == K.yellow ? K.ink : color).copyWith(fontSize: 12)),
      ],
    ),
  );
}

void showSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}
