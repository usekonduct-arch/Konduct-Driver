import 'dart:async';

import 'auth_repository.dart';

/// Stand-in used without Firebase (`--dart-define=KONDUCT_DEMO=true`) so every screen can be
/// tried on a device. Any email signs up; `taken@konduct.com.ng` plays an email already in use.
/// Signing in needs the password the account was created with in this session.
/// Driver onboarding code: see [code].
class DemoAuthRepository implements AuthRepository {
  final _ctrl = StreamController<Session?>.broadcast();
  final _accounts = <String, String>{};
  Session? _session;

  @override
  bool get isDemo => true;

  @override
  Stream<Session?> sessions() async* {
    yield _session;
    yield* _ctrl.stream;
  }

  void _emit(Session? s) => _ctrl.add(_session = s);

  Future<void> _lag([int ms = 800]) => Future.delayed(Duration(milliseconds: ms));

  @override
  Future<void> signUp(String email, String password) async {
    await _lag();
    if (email == 'taken@konduct.com.ng' || _accounts.containsKey(email)) {
      throw const AuthException('email-already-in-use', 'There\'s already an account with this email. Sign in instead.');
    }
    _accounts[email] = password;
    _emit(Session(uid: 'demo-${email.hashCode}', email: email));
  }

  @override
  Future<void> signIn(String email, String password) async {
    await _lag();
    if (_accounts[email] != password) throw const AuthException('invalid-credential', 'That email and password don\'t match an account.');
    _emit(Session(uid: 'demo-${email.hashCode}', email: email));
  }

  @override
  Future<void> sendPasswordReset(String email) => _lag(500);

  /// Code `KD7F3Q2X` claims the demo driver; an email starting with `new` has no agent record.
  static const code = 'KD7F3Q2X';

  @override
  Future<DriverInvite?> claimDriver(String code) async {
    await _lag(1000);
    final s = _session!;
    if (s.email.startsWith('new')) return null;
    if (code != DemoAuthRepository.code) {
      throw const AuthException('permission-denied', 'That code doesn\'t match. Check it with the agent who signed you up.');
    }
    const invite = DriverInvite(fullName: 'Tunde Adebayo', plate: 'OS 452 KJA', vehicleType: 'Shuttle', route: 'Main Gate ⇄ Faculty');
    _emit(Session(uid: s.uid, email: s.email, role: 'driver', name: invite.fullName));
    return invite;
  }

  @override
  Future<void> setPin(String pin) async {
    await _lag();
    final s = _session!;
    _emit(Session(uid: s.uid, email: s.email, role: s.role, name: s.name, pinSet: true));
  }

  @override
  Future<void> signOut() async => _emit(null);
}
