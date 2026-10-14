import 'dart:async';

import 'driver_api.dart';
import 'models.dart';

/// Stand-in used without Firebase (`--dart-define=KONDUCT_DEMO=true`). Starts with ₦3,400 earned
/// from a few sample fares. Bank accounts: any 10-digit number resolves to the driver's own name
/// and is "approved" two seconds later, with no hold. Password `drive-safely-9`, PIN `1379`.
class DemoDriverApi implements DriverApi {
  DemoDriverApi({this.fullName = 'Tunde Adebayo'}) {
    final now = DateTime.now();
    _payments.addAll([
      Payment(id: 'fare_d1', amountKobo: 60000, riders: 3, reference: 'KD-7Q4M2P', status: 'paid', at: now.subtract(const Duration(minutes: 6))),
      Payment(id: 'fare_d2', amountKobo: 20000, riders: 1, reference: 'KD-3XH9TA', status: 'paid', at: now.subtract(const Duration(minutes: 41))),
      Payment(id: 'fare_d3', amountKobo: 20000, riders: 1, reference: 'KD-P2L7WE', status: 'undone', at: now.subtract(const Duration(hours: 2))),
      Payment(id: 'fare_d4', amountKobo: 260000, riders: 13, reference: 'KD-9VN4RC', status: 'paid', at: now.subtract(const Duration(hours: 3))),
    ]);
  }

  final String fullName;
  int _balance = 340000;
  final _payments = <Payment>[];
  final _payouts = <Payout>[];
  BankAccount? _active, _pending;
  final _changed = StreamController<void>.broadcast();
  var _n = 0;

  @override
  bool get isDemo => true;

  Future<void> _lag([int ms = 700]) => Future.delayed(Duration(milliseconds: ms));
  void _touch() => _changed.add(null);

  Stream<T> _live<T>(T Function() read) async* {
    yield read();
    yield* _changed.stream.map((_) => read());
  }

  @override
  Stream<int?> balance() => _live(() => _balance);

  @override
  Stream<List<Payment>> payments({int limit = 50}) => _live(() => _payments.take(limit).toList());

  @override
  Stream<List<Payout>> payouts({int limit = 20}) => _live(() => _payouts.take(limit).toList());

  @override
  Stream<BankAccounts> bankAccounts() => _live(() => BankAccounts(active: _active, pending: _pending));

  @override
  Future<List<Bank>> banks() async {
    await _lag(300);
    return const [
      Bank('044', 'Access Bank'),
      Bank('058', 'Guaranty Trust Bank'),
      Bank('50515', 'Moniepoint MFB'),
      Bank('999992', 'OPay'),
      Bank('100033', 'PalmPay'),
      Bank('033', 'United Bank for Africa'),
      Bank('057', 'Zenith Bank'),
    ];
  }

  @override
  Future<BankCheck> setBankAccount({required String bankCode, required String accountNumber, required String password, required String pin}) async {
    await _lag();
    if (password != 'drive-safely-9') throw const ApiException('wrong_password', "That password isn't right. (Demo: drive-safely-9)");
    if (pin != '1379') throw const ApiException('pin_wrong', 'Wrong PIN. (Demo PIN: 1379)');
    final name = fullName.toUpperCase();
    _pending = BankAccount(
      id: 'pa_demo${++_n}',
      bankCode: bankCode,
      last4: accountNumber.substring(6),
      accountName: name,
      status: 'pending_approval',
      nameMatches: true,
    );
    _touch();
    Future.delayed(const Duration(seconds: 2), () {
      final p = _pending;
      if (p == null) return;
      _active = BankAccount(id: p.id, bankCode: p.bankCode, last4: p.last4, accountName: p.accountName, status: 'active', nameMatches: true);
      _pending = null;
      _touch();
    });
    return BankCheck(accountName: name, nameMatches: true);
  }

  @override
  Future<int> payOutNow({required String pin}) async {
    await _lag();
    if (pin != '1379') throw const ApiException('pin_wrong', 'Wrong PIN. (Demo PIN: 1379)');
    if (_active == null) throw const ApiException('no_payout_account', 'Add a bank account first.');
    if (_balance < minWithdrawKobo) throw ApiException('below_minimum', 'Payouts start from ${naira(minWithdrawKobo)}.');
    final amount = _balance;
    _balance = 0;
    final id = 'po_demo${++_n}';
    _payouts.insert(0, Payout(id: id, amountKobo: amount, status: 'submitted', at: DateTime.now(), last4: _active!.last4, trigger: 'driver_request'));
    _touch();
    Future.delayed(const Duration(seconds: 2), () {
      final i = _payouts.indexWhere((p) => p.id == id);
      if (i < 0) return;
      final p = _payouts[i];
      _payouts[i] = Payout(id: p.id, amountKobo: p.amountKobo, status: 'paid', at: p.at, last4: p.last4, trigger: p.trigger);
      _touch();
    });
    return amount;
  }

  @override
  Future<void> changePin({required String oldPin, required String newPin}) async {
    await _lag();
    if (oldPin != '1379') throw const ApiException('pin_wrong', 'Wrong PIN. (Demo PIN: 1379)');
  }

  @override
  Future<void> lockMyAccount() => _lag();
}
