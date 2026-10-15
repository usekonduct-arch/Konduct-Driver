/// Plain data the earnings screens show. Amounts are integer kobo, as on the backend (₦1 = 100 kobo).
library;

/// "₦1,250" or "₦1,250.50". Whole naira drop the kobo.
String naira(int kobo) {
  final negative = kobo < 0;
  final abs = kobo.abs();
  final whole = (abs ~/ 100).toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
  final rest = abs % 100;
  return '${negative ? '-' : ''}₦$whole${rest == 0 ? '' : '.${rest.toString().padLeft(2, '0')}'}';
}

/// One fare paid to this driver (driverFeed/{uid}/items/{txId}).
class Payment {
  const Payment({required this.id, required this.amountKobo, required this.riders, required this.reference, required this.status, required this.at});
  final String id, reference;
  final int amountKobo, riders;

  /// paid | undone
  final String status;
  final DateTime at;

  bool get undone => status != 'paid';
}

/// One payout to the driver's bank (payouts/{id}).
class Payout {
  const Payout({required this.id, required this.amountKobo, required this.status, required this.at, required this.last4, required this.trigger});
  final String id, status, last4, trigger;
  final int amountKobo;
  final DateTime at;

  bool get onItsWay => const ['reserved', 'transferred', 'submitted', 'unknown'].contains(status);
  bool get paid => status == 'paid';
  bool get returned => status == 'returned';
}

/// receiptProof's answer: the ledger's word on one fare or payout.
class ReceiptProof {
  const ReceiptProof({required this.verified, required this.posted, this.verifyUrl, this.hash, this.balanceAfterKobo, this.postedAt, this.reversed = false});

  /// The entry recomputes and sits in the account's hash chain.
  final bool verified;

  /// False while there is nothing on the ledger yet.
  final bool posted;

  /// The public receipt check (printed as a QR); null in demo mode.
  final String? verifyUrl;
  final String? hash;
  final int? balanceAfterKobo;
  final DateTime? postedAt;
  final bool reversed;

  /// What the receipt prints: the first 16 characters of the entry's hash.
  String? get fingerprint => hash == null || hash!.length < 16 ? hash : hash!.substring(0, 16);

  factory ReceiptProof.fromMap(Map<String, dynamic> m) => ReceiptProof(
    verified: m['verified'] == true,
    posted: m['posted'] == true,
    verifyUrl: m['verifyUrl'] as String?,
    hash: m['hash'] as String?,
    balanceAfterKobo: (m['balanceAfterKobo'] as num?)?.toInt(),
    postedAt: m['postedAtMs'] == null ? null : DateTime.fromMillisecondsSinceEpoch((m['postedAtMs'] as num).toInt()),
    reversed: m['reversed'] == true,
  );
}

/// A Nigerian bank from Bachs's list.
class Bank {
  const Bank(this.code, this.name);
  final String code, name;
}

/// payoutAccounts/{id}: where payouts go. The full account number stays at Bachs.
class BankAccount {
  const BankAccount({
    required this.id,
    required this.bankCode,
    required this.last4,
    required this.accountName,
    required this.status,
    required this.nameMatches,
    this.holdUntil,
  });

  final String id, bankCode, last4, accountName;

  /// pending_approval | active | replaced | rejected
  final String status;
  final bool nameMatches;
  final DateTime? holdUntil;

  bool get active => status == 'active';
  bool get waiting => status == 'pending_approval';
  bool get onHold => active && holdUntil != null && DateTime.now().isBefore(holdUntil!);
}

/// The approved account and, while a change is being checked, the new one.
class BankAccounts {
  const BankAccounts({this.active, this.pending});
  final BankAccount? active, pending;
}

/// driverSetPayoutAccount's answer: the name the bank has on the account.
class BankCheck {
  const BankCheck({required this.accountName, required this.nameMatches});
  final String accountName;
  final bool nameMatches;
}

/// Lowest payout (backend RULES.minPayoutKobo).
const minWithdrawKobo = 50000;

/// An error the backend explained. [reason] is its stable code (for example "below_minimum").
class ApiException implements Exception {
  const ApiException(this.reason, this.message, {this.details = const {}});
  final String reason;
  final String message;
  final Map<String, dynamic> details;
  @override
  String toString() => message;
}

/// Seats on every bus until an admin sets config/fleet (backend RULES.defaultBusSeats).
const defaultBusSeats = 7;

/// The driver's bus: seats paid by scan on the current trip (vehicles/{id}.load).
class BusLoad {
  const BusLoad({required this.plate, required this.capacity, required this.taken, this.tripEndsAt, this.route, this.parkId, this.parkName, this.parkUntil});
  final String plate;
  final int capacity, taken;

  /// The park the bus is checked in at (riders see it there), and when that lapses on its own.
  final String? parkId, parkName;
  final DateTime? parkUntil;

  /// Checked in at a park at [now].
  bool atParkAt(DateTime now) => parkId != null && parkUntil != null && now.isBefore(parkUntil!);

  /// Where the bus is going on this trip; null until the driver (or staff) sets it.
  final TripRoute? route;

  /// When the trip clears on its own if nobody scans again.
  final DateTime? tripEndsAt;

  /// Seats paid at [now]; a trip that has timed out counts as an empty bus.
  int takenAt(DateTime now) => tripEndsAt != null && now.isBefore(tripEndsAt!) ? taken : 0;
}

/// parks/{id}: a park and how many buses staff last counted there.
class Park {
  const Park({required this.id, required this.name, required this.location, required this.busCount, this.updatedAt});
  final String id, name, location;
  final int busCount;

  /// When staff last updated the count; null if they never have.
  final DateTime? updatedAt;

  /// A count this old may no longer be true.
  bool staleAt(DateTime now) => updatedAt == null || now.difference(updatedAt!) > const Duration(hours: 2);
}

/// landmarks/{id}: a place a trip can start or end.
class Landmark {
  const Landmark(this.id, this.name);
  final String id, name;
}

/// vehicles/{id}.currentRoute: from one landmark to another, with the estimated minutes.
class TripRoute {
  const TripRoute({required this.fromId, required this.fromName, required this.toId, required this.toName, required this.etaMin, this.setByStaff = false});
  final String fromId, fromName, toId, toName;
  final int etaMin;

  /// Staff changed it for the driver.
  final bool setByStaff;

  String get label => '$fromName → $toName';

  static TripRoute? fromMap(Object? m) {
    if (m is! Map || m['fromId'] == null || m['toId'] == null) return null;
    return TripRoute(
      fromId: '${m['fromId']}',
      fromName: '${m['fromName'] ?? ''}',
      toId: '${m['toId']}',
      toName: '${m['toName'] ?? ''}',
      etaMin: (m['etaMin'] as num?)?.toInt() ?? 0,
      setByStaff: m['setByStaff'] == true,
    );
  }
}

/// The driver's average from riders' ratings (users/{uid}.ratingSum / ratingCount).
class DriverRating {
  const DriverRating({required this.sum, required this.count});
  final int sum, count;
  double get average => count == 0 ? 0 : sum / count;
}

/// driverDays/{uid}_{day}: one day's figures, kept by the server with every fare and refund.
class DriverDay {
  const DriverDay({
    required this.day,
    this.fares = 0,
    this.riders = 0,
    this.trips = 0,
    this.grossKobo = 0,
    this.refundsKobo = 0,
    this.byHour = const {},
    this.routes = const {},
  });

  /// Midnight of the day, local time.
  final DateTime day;
  final int fares, riders, trips, grossKobo, refundsKobo;

  /// Money in by hour of the day (0-23).
  final Map<int, int> byHour;

  /// Fares by trip route.
  final Map<String, int> routes;

  /// What the driver keeps: fares less refunds they covered.
  int get netKobo => grossKobo - refundsKobo;

  factory DriverDay.fromMap(Map<String, dynamic> m) {
    final d = DateTime.tryParse('${m['day']}') ?? DateTime(1970);
    Map<String, int> ints(Object? v) => v is Map ? v.map((k, x) => MapEntry('$k', (x as num?)?.toInt() ?? 0)) : const {};
    return DriverDay(
      day: DateTime(d.year, d.month, d.day),
      fares: (m['fares'] as num?)?.toInt() ?? 0,
      riders: (m['riders'] as num?)?.toInt() ?? 0,
      trips: (m['trips'] as num?)?.toInt() ?? 0,
      grossKobo: (m['grossKobo'] as num?)?.toInt() ?? 0,
      refundsKobo: (m['refundsKobo'] as num?)?.toInt() ?? 0,
      byHour: ints(m['byHour']).map((k, v) => MapEntry(int.tryParse(k) ?? 0, v)),
      routes: ints(m['routes']),
    );
  }
}

/// A month of [DriverDay]s added up, for the report, the statement and Wrapped.
class DriverMonth {
  DriverMonth(this.month, List<DriverDay> days) : days = [...days]..sort((a, b) => a.day.compareTo(b.day));
  final DateTime month;
  final List<DriverDay> days;

  int _sum(int Function(DriverDay) f) => days.fold(0, (t, d) => t + f(d));
  int get grossKobo => _sum((d) => d.grossKobo);
  int get refundsKobo => _sum((d) => d.refundsKobo);
  int get netKobo => grossKobo - refundsKobo;
  int get fares => _sum((d) => d.fares);
  int get riders => _sum((d) => d.riders);
  int get trips => _sum((d) => d.trips);

  /// Days with at least one fare.
  List<DriverDay> get worked => days.where((d) => d.fares > 0).toList();
  DriverDay? get bestDay => worked.isEmpty ? null : worked.reduce((a, b) => b.netKobo > a.netKobo ? b : a);
  /// Rounded to whole naira.
  int get averagePerDayKobo => worked.isEmpty ? 0 : (netKobo / worked.length / 100).round() * 100;

  Map<int, int> get byHour {
    final out = <int, int>{};
    for (final d in days) {
      d.byHour.forEach((h, k) => out[h] = (out[h] ?? 0) + k);
    }
    return out;
  }

  /// The hour that brought in the most money, if any.
  int? get busiestHour => byHour.isEmpty ? null : byHour.entries.reduce((a, b) => b.value > a.value ? b : a).key;

  /// Routes by fares, most first.
  List<MapEntry<String, int>> get topRoutes {
    final out = <String, int>{};
    for (final d in days) {
      d.routes.forEach((r, n) => out[r] = (out[r] ?? 0) + n);
    }
    return out.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
  }
}

