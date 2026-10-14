/// What the app knows about the signed-in person. Everything except uid/email comes from
/// custom claims that only the backend can set (SRS FR-AUTH-05), so it is readable offline.
class Session {
  const Session({required this.uid, required this.email, this.role, this.pinSet = false, this.status = 'active', this.name});

  final String uid;
  final String email;
  final String? role; // 'rider' | 'driver' | staff roles; null until the backend assigns one
  final bool pinSet;
  final String status; // 'active' | 'suspended'
  final String? name;

  String get firstName => (name ?? '').trim().split(' ').first;
}

/// The driver record an agent created at the park before the driver ever opened the app.
class DriverInvite {
  const DriverInvite({required this.fullName, required this.plate, required this.vehicleType, required this.route});
  final String fullName, plate, vehicleType, route;
}

class AuthException implements Exception {
  const AuthException(this.code, this.message);
  final String code;
  final String message;
  @override
  String toString() => message;
}

abstract class AuthRepository {
  /// True when running without a Firebase project (UI preview).
  bool get isDemo;

  /// Emits the current session on sign-in, sign-out and every token refresh.
  Stream<Session?> sessions();

  Future<void> signIn(String email, String password);

  /// Creates the account and signs in. The email is not verified yet (planned for later).
  Future<void> signUp(String email, String password);

  Future<void> sendPasswordReset(String email);

  /// FR-AUTH-03: links this account to the record an agent created at the park, using the
  /// one-time onboarding code the agent handed over. Returns null when no agent has onboarded
  /// this email; throws when the code is wrong.
  Future<DriverInvite?> claimDriver(String code);

  Future<void> setPin(String pin);

  Future<void> signOut();
}

final _email = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$');

bool looksLikeEmail(String s) => _email.hasMatch(s.trim());
