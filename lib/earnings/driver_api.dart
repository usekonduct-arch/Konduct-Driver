import 'models.dart';

/// Everything the earnings screens read and do. Reads are live Firestore streams the security
/// rules limit to this driver; every change goes through a backend callable.
abstract class DriverApi {
  bool get isDemo;

  /// Earnings waiting to be paid out, in kobo; null until the wallet loads.
  Stream<int?> balance();

  /// Fares paid to this driver, newest first.
  Stream<List<Payment>> payments({int limit = 50});

  /// Payouts to the bank, newest first.
  Stream<List<Payout>> payouts({int limit = 20});

  /// Where payouts go: the approved account, and any new one waiting for a staff check.
  Stream<BankAccounts> bankAccounts();

  /// Nigerian banks for the picker.
  Future<List<Bank>> banks();

  /// Adds or changes the payout account. Confirms the password first (the backend wants a
  /// sign-in from the last few minutes), then the PIN. A staff member approves the account.
  Future<BankCheck> setBankAccount({required String bankCode, required String accountNumber, required String password, required String pin});

  /// Pays the whole balance out now instead of waiting for the evening run. Returns the amount.
  Future<int> payOutNow({required String pin});

  Future<void> changePin({required String oldPin, required String newPin});

  /// Puts the account on hold at once (stolen phone). Only an agent can lift it.
  Future<void> lockMyAccount();
}
