import 'package:flutter/material.dart';

import '../earnings/driver_api.dart';
import '../earnings/screens/home_screen.dart';
import '../theme/tokens.dart';
import 'auth_controller.dart';
import 'screens/driver_claim_screen.dart';
import 'screens/email_screen.dart';
import 'screens/pin_screen.dart';
import 'screens/ready_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/welcome_screen.dart';

/// Shows the screen for the current sign-up stage and animates between stages.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key, required this.auth, required this.api});
  final AuthController auth;
  final DriverApi api;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: auth,
      builder: (context, _) => AnimatedSwitcher(
        duration: const Duration(milliseconds: 650),
        switchInCurve: K.outExpo,
        switchOutCurve: Curves.easeIn,
        transitionBuilder: (child, a) => FadeTransition(
          opacity: a,
          child: ScaleTransition(scale: Tween(begin: 0.96, end: 1.0).animate(a), child: child),
        ),
        child: KeyedSubtree(key: ValueKey((auth.stage, auth.justJoined)), child: _screen(context)),
      ),
    );
  }

  Widget _screen(BuildContext context) {
    final demo = auth.repo.isDemo;
    // Account, onboarding code, PIN (the profile comes from the agent who onboarded the driver).
    double step(int n) => n / 3;

    switch (auth.stage) {
      case Stage.booting:
        return const SplashScreen();
      case Stage.signedOut:
        return _SignedOutFlow(auth: auth, progress: step);
      case Stage.driverClaim:
        return DriverClaimScreen(email: auth.session?.email ?? '', progress: step(2), demo: demo, onClaim: auth.claimDriver, onSignOut: auth.signOut);
      case Stage.pin:
        return PinScreen(
          progress: step(3),
          demo: demo,
          onSave: auth.setPin,
          onBack: auth.signOut,
          header: _DriverCard(auth: auth),
        );
      case Stage.ready:
        if (auth.justJoined) return ReadyScreen(session: auth.session!, demo: demo, onContinue: auth.enterHome);
        return HomeScreen(key: ValueKey(auth.session!.uid), api: api, session: auth.session!, onSignOut: auth.signOut);
      case Stage.wrongApp:
        return BlockedScreen(
          title: 'This is a student account.',
          message: 'Students pay with the Konduct app. If you also drive, ask an agent to register a separate email for your driver account.',
          onSignOut: auth.signOut,
        );
      case Stage.suspended:
        return BlockedScreen(
          title: 'Your account is on hold.',
          message: 'For your safety this account has been paused. Talk to a Konduct agent at the park or contact support to unlock it.',
          onSignOut: auth.signOut,
        );
    }
  }
}

enum _Step { welcome, account }

/// Welcome → email and password, with direction-aware slides and system back support.
class _SignedOutFlow extends StatefulWidget {
  const _SignedOutFlow({required this.auth, required this.progress});
  final AuthController auth;
  final double Function(int) progress;
  @override
  State<_SignedOutFlow> createState() => _SignedOutFlowState();
}

class _SignedOutFlowState extends State<_SignedOutFlow> {
  _Step _step = _Step.welcome;
  bool _forward = true;

  void _go(_Step s) => setState(() {
        _forward = s.index > _step.index;
        _step = s;
      });

  @override
  Widget build(BuildContext context) {
    final auth = widget.auth;
    final demo = auth.repo.isDemo;
    final child = switch (_step) {
      _Step.welcome => WelcomeScreen(demo: demo, onStart: () => _go(_Step.account)),
      _Step.account => EmailScreen(
          progress: widget.progress(1),
          demo: demo,
          signUpHint: 'Use the email the Konduct agent registered for you at the park.',
          initialMode: EmailMode.signIn,
          onBack: () => _go(_Step.welcome),
          onForgot: auth.sendPasswordReset,
          // On success the session changes and the gate moves on by itself.
          onSubmit: (email, password, mode) => mode == EmailMode.signUp ? auth.signUp(email, password) : auth.signIn(email, password),
        ),
    };

    return PopScope(
      canPop: _step == _Step.welcome,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _go(_Step.values[_step.index - 1]);
      },
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 520),
        switchInCurve: K.outExpo,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (c, a) {
          final incoming = c.key == ValueKey(_step);
          final dir = (_forward ? 1.0 : -1.0) * (incoming ? 1 : -1);
          return SlideTransition(
            position: Tween(begin: Offset(0.35 * dir, 0), end: Offset.zero).animate(a),
            child: FadeTransition(opacity: a, child: c),
          );
        },
        child: KeyedSubtree(key: ValueKey(_step), child: child),
      ),
    );
  }
}

/// "Is this you?" card above the driver's PIN, from the agent's record.
class _DriverCard extends StatelessWidget {
  const _DriverCard({required this.auth});
  final AuthController auth;

  @override
  Widget build(BuildContext context) {
    final inv = auth.invite;
    final name = inv?.fullName ?? auth.session?.name ?? 'Driver';
    final p = Palette.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: p.surface, borderRadius: BorderRadius.circular(22), border: Border.all(color: p.border)),
      child: Row(children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(color: K.yellow, borderRadius: BorderRadius.circular(15)),
          alignment: Alignment.center,
          child: Text(name.split(' ').map((w) => w.isEmpty ? '' : w[0]).take(2).join(), style: KText.h3(K.ink)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name, style: KText.h3(p.text)),
            Text(inv == null ? 'Verified driver' : '${inv.vehicleType} · ${inv.plate}', style: KText.mono(p.subtle, size: 12.5)),
          ]),
        ),
        const Icon(Icons.verified_rounded, color: K.go),
      ]),
    );
  }
}
