import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/tokens.dart';
import '../../ui/flow_scaffold.dart';
import '../../ui/kit.dart';
import '../../ui/scene/scenes.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key, required this.onStart, this.demo = false});
  final VoidCallback onStart;
  final bool demo;

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.sizeOf(context).height;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: K.ink,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: h * 0.5,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  const DriveScene(),
                  const Align(alignment: Alignment(0, -0.1), child: _DriverAlert()),
                  SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const KMark(size: 34),
                          const SizedBox(width: 9),
                          Text('konduct driver', style: KText.h3(K.paper).copyWith(fontWeight: FontWeight.w800, fontSize: 22)),
                          const Spacer(),
                          if (demo) const DemoBadge(),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(22, 26, 22, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Entrance(
                        child: Text('FOR SHUTTLE AND BIKE DRIVERS', style: KText.kicker(K.muteDark)),
                      ),
                      const SizedBox(height: 12),
                      Entrance(
                        delay: const Duration(milliseconds: 80),
                        child: Text.rich(
                          TextSpan(children: [
                            TextSpan(text: 'Every trip counted.\n'),
                            TextSpan(text: 'Every naira paid.', style: const TextStyle(color: K.yellow)),
                          ]),
                          style: KText.hero(K.paper),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Entrance(delay: const Duration(milliseconds: 160), child: _Ticker(items: _driverPoints)),
                      const Spacer(),
                      Entrance(
                        delay: const Duration(milliseconds: 240),
                        child: KButton(label: 'Sign in', icon: Icons.arrow_forward_rounded, onTap: onStart),
                      ),
                      const SizedBox(height: 14),
                      Center(
                        child: Text(
                          'New driver? A Konduct agent signs you up at the park.',
                          textAlign: TextAlign.center,
                          style: KText.small(K.muteDark),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

const _driverPoints = ['A loud alert on every payment', 'Paid to your bank every day', 'Works even when the park has no data', 'Your code, tied to your vehicle'];

/// Cycles one benefit at a time with a rolling transition.
class _Ticker extends StatefulWidget {
  const _Ticker({required this.items});
  final List<String> items;
  @override
  State<_Ticker> createState() => _TickerState();
}

class _TickerState extends State<_Ticker> {
  int _i = 0;
  late final Timer _t;

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(milliseconds: 2400), (_) => setState(() => _i = (_i + 1) % widget.items.length));
  }

  @override
  void dispose() {
    _t.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 28,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 520),
        switchInCurve: K.outExpo,
        transitionBuilder: (child, a) => ClipRect(
          child: SlideTransition(
            position: Tween(begin: const Offset(0, 1), end: Offset.zero).animate(a),
            child: FadeTransition(opacity: a, child: child),
          ),
        ),
        layoutBuilder: (cur, prev) => Stack(alignment: Alignment.centerLeft, children: [...prev, ?cur]),
        child: Row(
          key: ValueKey(_i),
          children: [
            Container(width: 20, height: 20, decoration: BoxDecoration(color: K.go.withValues(alpha: 0.2), shape: BoxShape.circle), child: const Icon(Icons.check_rounded, size: 14, color: K.go)),
            const SizedBox(width: 10),
            Flexible(
              child: Text(widget.items[_i], maxLines: 1, overflow: TextOverflow.ellipsis, style: KText.body(const Color(0xFFD5D9DE)).copyWith(fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }
}

/// The glanceable alert a driver hears on every payment, with live-feeling amounts.
class _DriverAlert extends StatefulWidget {
  const _DriverAlert();
  @override
  State<_DriverAlert> createState() => _DriverAlertState();
}

class _DriverAlertState extends State<_DriverAlert> {
  static const _amounts = [('₦200', '1 rider'), ('₦600', '3 riders'), ('₦200', '1 rider'), ('₦400', '2 riders')];
  int _i = 0;
  late final Timer _t;

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(milliseconds: 2600), (_) => setState(() => _i = (_i + 1) % _amounts.length));
  }

  @override
  void dispose() {
    _t.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final (amount, riders) = _amounts[_i];
    return SoundRings(
      child: Container(
        width: 250,
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
        decoration: BoxDecoration(color: K.paper, borderRadius: BorderRadius.circular(28), boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 30, offset: Offset(0, 16))]),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(children: [
              Container(width: 9, height: 9, decoration: const BoxDecoration(color: K.go, shape: BoxShape.circle)),
              const SizedBox(width: 7),
              Text('PAYMENT · NOW', style: KText.kicker(K.mute).copyWith(fontSize: 10.5)),
              const Spacer(),
              const Icon(Icons.volume_up_rounded, size: 20, color: K.ink),
            ]),
            const SizedBox(height: 6),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 420),
              transitionBuilder: (c, a) => ScaleTransition(scale: CurvedAnimation(parent: a, curve: K.springy), child: FadeTransition(opacity: a, child: c)),
              child: Text('$amount received', key: ValueKey(_i), style: KText.title(K.ink).copyWith(fontSize: 30)),
            ),
            Text('$riders · Ref KD-48Q2', style: KText.small(K.mute)),
          ],
        ),
      ),
    );
  }
}
