import 'package:flutter/material.dart' hide Text;
import 'package:flutter/services.dart';

import '../../l10n/text.dart';
import '../../theme/tokens.dart';
import '../../ui/field.dart';
import '../../ui/flow_scaffold.dart';
import '../../ui/kit.dart';
import '../auth_repository.dart';

/// FR-AUTH-03: drivers can't self-register. The agent who onboarded the driver at the park
/// registered their email and handed them a one-time 8-character code. The code is what proves
/// this account belongs to that driver, since email addresses aren't verified yet.
class DriverClaimScreen extends StatefulWidget {
  const DriverClaimScreen({super.key, required this.email, required this.onClaim, required this.onSignOut, required this.progress, this.demo = false});
  final String email;
  final Future<DriverInvite?> Function(String code) onClaim;
  final VoidCallback onSignOut;
  final double progress;
  final bool demo;

  @override
  State<DriverClaimScreen> createState() => _DriverClaimScreenState();
}

class _DriverClaimScreenState extends State<DriverClaimScreen> {
  static const _len = 8;
  final _code = TextEditingController();
  final _shake = GlobalKey<ShakeState>();
  bool _busy = false;
  bool _notFound = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _code.addListener(() => setState(() => _error = null));
  }

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  String get _clean => _code.text.toUpperCase().replaceAll(RegExp(r'[^0-9A-Z]'), '');

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final invite = await widget.onClaim(_clean);
      if (invite == null && mounted) setState(() => _notFound = true);
      // On success the session gains the driver role and the gate moves on by itself.
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
      _shake.currentState?.shake();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    if (_notFound) {
      return FlowScaffold(
        kicker: 'Driver sign-in',
        title: 'We don\'t have you yet.',
        subtitle: Text('No agent has registered ${widget.email} as a driver. Drivers are signed up in person at the park, after the agent checks your ID, vehicle and payout details.'),
        progress: widget.progress,
        demo: widget.demo,
        bottom: Column(
          children: [
            KButton(label: 'Try the code again', icon: Icons.refresh_rounded, onTap: () => setState(() => _notFound = false)),
            const SizedBox(height: 10),
            Pressable(
              onTap: widget.onSignOut,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text('Use a different email', style: KText.body(p.text).copyWith(fontWeight: FontWeight.w700, decoration: TextDecoration.underline)),
              ),
            ),
          ],
        ),
        child: Center(child: _HowToJoin(email: widget.email)),
      );
    }

    return FlowScaffold(
      kicker: 'One last check',
      title: 'Enter your driver code.',
      subtitle: const Text('The Konduct agent who signed you up gave you an 8-character code. It links this account to your vehicle.'),
      progress: widget.progress,
      onBack: _busy ? null : widget.onSignOut,
      demo: widget.demo,
      bottom: KButton(label: 'Link my vehicle', icon: Icons.directions_bus_rounded, loading: _busy, onTap: _clean.length == _len ? _submit : null),
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(top: 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Entrance(
              delay: const Duration(milliseconds: 160),
              child: Shake(
                key: _shake,
                child: KField(
                  controller: _code,
                  label: 'Driver code',
                  hint: 'e.g. KD7F3Q2X',
                  icon: Icons.key_rounded,
                  mono: true,
                  enabled: !_busy,
                  error: _error != null,
                  capitalization: TextCapitalization.characters,
                  formatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9A-Za-z]')), LengthLimitingTextInputFormatter(_len)],
                  action: TextInputAction.done,
                  onSubmitted: (_) => _clean.length == _len ? _submit() : null,
                ),
              ),
            ),
            ErrorLine(_error),
            const SizedBox(height: 18),
            Entrance(
              delay: const Duration(milliseconds: 240),
              child: Row(children: [
                Icon(Icons.shield_rounded, size: 18, color: p.subtle),
                const SizedBox(width: 8),
                Expanded(child: Text('Never share this code. Konduct staff will never ask you for it.', style: KText.small(p.subtle))),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

class _HowToJoin extends StatelessWidget {
  const _HowToJoin({required this.email});
  final String email;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final steps = [
      ('Find a Konduct agent at the park', Icons.storefront_rounded),
      ('Bring your ID, vehicle papers and bank details', Icons.badge_rounded),
      ('Ask them to register $email', Icons.alternate_email_rounded),
    ];
    return Entrance(
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(color: p.surface, borderRadius: BorderRadius.circular(26), border: Border.all(color: p.border)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (i, (text, icon)) in steps.indexed)
              Entrance(
                delay: Duration(milliseconds: 120 * i),
                child: Padding(
                  padding: EdgeInsets.only(bottom: i == steps.length - 1 ? 0 : 14),
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(color: K.yellow, borderRadius: BorderRadius.circular(13)),
                        child: Icon(icon, color: K.ink, size: 22),
                      ),
                      const SizedBox(width: 14),
                      Expanded(child: Text(text, style: KText.body(p.text).copyWith(fontWeight: FontWeight.w600))),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
