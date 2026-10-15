import '../messages/messages_api.dart';
import '../support/support_api.dart';
import 'models.dart';

/// Everything the earnings screens read and do. Reads are live Firestore streams the security
/// rules limit to this driver; every change goes through a backend callable.
abstract class DriverApi {
  bool get isDemo;

  /// Chat with Konduct staff.
  SupportApi get support;

  /// Notifications, ads and push.
  MessagesApi get messages;

  /// Changes the sign-in password after confirming the current one.
  Future<void> changePassword({required String current, required String next});

  /// Emails a password reset link to the signed-in address.
  Future<void> sendPasswordReset();

  /// Earnings waiting to be paid out, in kobo; null until the wallet loads.
  Stream<int?> balance();

  /// Fares paid to this driver, newest first.
  Stream<List<Payment>> payments({int limit = 50});

  /// Payouts to the bank, newest first.
  Stream<List<Payout>> payouts({int limit = 20});

  /// This driver's bus and the seats paid by scan on its current trip; null for a bike or before
  /// a vehicle is linked.
  Stream<BusLoad?> busLoad();

  /// The bus has emptied: clears the seats paid by scan so the next riders can pay.
  Future<void> newTrip();

  /// Places a trip can go between, by name.
  Stream<List<Landmark>> landmarks();

  /// Where the bus is going on this trip. With [newTrip] the seats paid by scan also clear.
  Future<TripRoute> setRoute({required String fromId, required String toId, required bool newTrip});

  /// Riders' average rating of this driver; count 0 before the first one.
  Stream<DriverRating> rating();

  /// Parks shown in the app and how many buses are there, by name.
  Stream<List<Park>> parks();

  /// Where payouts go: the approved account, and any new one waiting for a staff check.
  Stream<BankAccounts> bankAccounts();

  /// Nigerian banks for the picker.
  Future<List<Bank>> banks();

  /// Adds or changes the payout account. Confirms the password first (the backend wants a
  /// sign-in from the last few minutes), then the PIN. A staff member approves the account.
  Future<BankCheck> setBankAccount({required String bankCode, required String accountNumber, required String password, required String pin});

  /// Pays the whole balance out now instead of waiting for the evening run. Returns the amount.
  Future<int> payOutNow({required String pin});

  /// The ledger's proof for one of this driver's fares ([payout] false) or payouts.
  Future<ReceiptProof> receiptProof({required String id, bool payout = false});

  Future<void> changePin({required String oldPin, required String newPin});

  /// Puts the account on hold at once (stolen phone). Only an agent can lift it.
  Future<void> lockMyAccount();
}
