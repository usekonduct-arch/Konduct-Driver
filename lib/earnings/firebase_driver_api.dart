import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../app/app_info.dart';
import 'driver_api.dart';
import 'models.dart';

class FirebaseDriverApi implements DriverApi {
  FirebaseDriverApi() : _functions = FirebaseFunctions.instanceFor(region: AppConfig.functionsRegion);

  final _db = FirebaseFirestore.instance;
  final FirebaseFunctions _functions;

  String get _uid => FirebaseAuth.instance.currentUser!.uid;

  @override
  bool get isDemo => false;

  @override
  Stream<int?> balance() => _db.doc('wallets/driver_$_uid').snapshots().map((s) => (s.data()?['balanceKobo'] as num?)?.toInt());

  @override
  Stream<List<Payment>> payments({int limit = 50}) => _db
      .collection('driverFeed/$_uid/items')
      .orderBy('atMs', descending: true)
      .limit(limit)
      .snapshots()
      .map(
        (q) => q.docs.map((d) {
          final m = d.data();
          return Payment(
            id: d.id,
            amountKobo: (m['amountKobo'] as num?)?.toInt() ?? 0,
            riders: (m['riders'] as num?)?.toInt() ?? 1,
            reference: m['reference'] as String? ?? '',
            status: m['status'] as String? ?? 'paid',
            at: DateTime.fromMillisecondsSinceEpoch((m['atMs'] as num?)?.toInt() ?? 0),
          );
        }).toList(),
      );

  @override
  Stream<List<Payout>> payouts({int limit = 20}) => _db
      .collection('payouts')
      .where('uid', isEqualTo: _uid)
      .orderBy('createdAt', descending: true)
      .limit(limit)
      .snapshots()
      .map(
        (q) => q.docs.map((d) {
          final m = d.data();
          return Payout(
            id: d.id,
            amountKobo: (m['amountKobo'] as num?)?.toInt() ?? 0,
            status: m['status'] as String? ?? 'reserved',
            at: (m['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
            last4: m['accountLast4'] as String? ?? '',
            trigger: m['trigger'] as String? ?? 'daily',
          );
        }).toList(),
      );

  @override
  Stream<BankAccounts> bankAccounts() {
    // users/{uid} names the approved account and any pending one; follow both documents.
    late StreamController<BankAccounts> c;
    StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? userSub;
    final subs = <String, StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>>{};
    final docs = <String, BankAccount?>{};
    String? activeId, pendingId;
    void emit() => c.add(BankAccounts(active: activeId == null ? null : docs[activeId], pending: pendingId == null ? null : docs[pendingId]));

    void follow(String? id) {
      if (id == null || subs.containsKey(id)) return;
      subs[id] = _db.doc('payoutAccounts/$id').snapshots().listen((s) {
        docs[id] = s.exists ? _bankAccount(s.id, s.data()!) : null;
        emit();
      }, onError: (_) {});
    }

    c = StreamController<BankAccounts>(
      onListen: () {
        userSub = _db.doc('users/$_uid').snapshots().listen((u) {
          activeId = u.data()?['payoutAccountId'] as String?;
          pendingId = u.data()?['pendingPayoutAccountId'] as String?;
          follow(activeId);
          follow(pendingId);
          emit();
        }, onError: c.addError);
      },
      onCancel: () async {
        await userSub?.cancel();
        for (final s in subs.values) {
          await s.cancel();
        }
      },
    );
    return c.stream;
  }

  BankAccount _bankAccount(String id, Map<String, dynamic> m) {
    final hold = (m['holdUntilMs'] as num?)?.toInt();
    return BankAccount(
      id: id,
      bankCode: m['bankCode'] as String? ?? '',
      last4: m['accountLast4'] as String? ?? '',
      accountName: m['accountName'] as String? ?? '',
      status: m['status'] as String? ?? 'pending_approval',
      nameMatches: m['nameMatches'] == true,
      holdUntil: hold == null ? null : DateTime.fromMillisecondsSinceEpoch(hold),
    );
  }

  List<Bank>? _banks;

  @override
  Future<List<Bank>> banks() async {
    if (_banks != null) return _banks!;
    final data = await _call('payoutBanks', {});
    final list = (data['banks'] as List? ?? const []).whereType<Map>().map((b) => Bank('${b['code']}', '${b['name']}')).toList();
    if (list.isEmpty) throw const ApiException('banks_unavailable', "We couldn't load the list of banks. Try again in a moment.");
    return _banks = list;
  }

  @override
  Future<BankCheck> setBankAccount({required String bankCode, required String accountNumber, required String password, required String pin}) async {
    await _reauthenticate(password);
    final data = await _call('driverSetPayoutAccount', {'bankCode': bankCode, 'accountNumber': accountNumber, 'pin': pin});
    return BankCheck(accountName: data['accountName'] as String? ?? '', nameMatches: data['nameMatches'] == true);
  }

  @override
  Future<int> payOutNow({required String pin}) async => ((await _call('driverRequestPayout', {'pin': pin}))['amountKobo'] as num?)?.toInt() ?? 0;

  @override
  Future<void> changePin({required String oldPin, required String newPin}) => _call('changePin', {'oldPin': oldPin, 'newPin': newPin});

  @override
  Future<void> lockMyAccount() async {
    await _call('lockMyAccount', {});
    await FirebaseAuth.instance.currentUser?.getIdToken(true);
  }

  /// Confirms the password again, so the backend sees a sign-in from the last few minutes.
  Future<void> _reauthenticate(String password) async {
    final user = FirebaseAuth.instance.currentUser!;
    try {
      await user.reauthenticateWithCredential(EmailAuthProvider.credential(email: user.email!, password: password));
      await user.getIdToken(true);
    } on FirebaseAuthException catch (e) {
      throw ApiException('wrong_password', switch (e.code) {
        'wrong-password' || 'invalid-credential' => "That password isn't right.",
        'too-many-requests' => 'Too many tries. Wait a few minutes, then try again.',
        'network-request-failed' => 'No connection. Check your data and try again.',
        _ => e.message ?? "Couldn't confirm your password.",
      });
    }
  }

  Future<Map<String, dynamic>> _call(String name, Map<String, Object?> data) async {
    try {
      final callable = AppConfig.backendUrl.isEmpty ? _functions.httpsCallable(name) : _functions.httpsCallableFromUrl('${AppConfig.backendUrl}/$name');
      final res = (await callable.call<Object?>(data)).data;
      return res is Map ? Map<String, dynamic>.from(res) : const {};
    } on FirebaseFunctionsException catch (e) {
      final details = e.details is Map ? Map<String, dynamic>.from(e.details as Map) : <String, dynamic>{};
      final reason = details['reason'] as String? ?? e.code;
      final message = switch (e.code) {
        'unavailable' || 'deadline-exceeded' when details['reason'] == null => 'No connection to Konduct. Check your data and try again.',
        'internal' when details['reason'] == null => 'Something went wrong on our side. Try again.',
        _ => e.message ?? 'Something went wrong. Try again.',
      };
      throw ApiException(reason, message, details: details);
    }
  }
}
