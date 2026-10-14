import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../auth/auth_repository.dart';
import '../../theme/tokens.dart';
import '../../ui/flow_scaffold.dart';
import '../../ui/kit.dart';
import '../driver_api.dart';
import '../earnings_ui.dart';
import '../models.dart';
import 'bank_account_screen.dart';
import 'payout_screen.dart';
import 'settings_screen.dart';

/// The driver's home: money waiting to be paid out, where it goes, today's fares and payouts.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.api, required this.session, required this.onSignOut});
  final DriverApi api;
  final Session session;
  final VoidCallback onSignOut;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final _balance = widget.api.balance();
  late final _payments = widget.api.payments();
  // A second listener for the card's "Today" total (a stream can only be listened to once).
  late final _paymentsToday = widget.api.payments();
  late final _payouts = widget.api.payouts(limit: 5);
  late final _accounts = widget.api.bankAccounts();
  late final _bus = widget.api.busLoad();
  late final _landmarks = widget.api.landmarks();
  late final _rating = widget.api.rating();
  late final _parks = widget.api.parks();

  DriverApi get api => widget.api;

  @override
  Widget build(BuildContext context) {
    final name = widget.session.firstName.isEmpty ? 'driver' : widget.session.firstName;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: K.ink,
        body: SafeArea(
          bottom: false,
          // Not a lazy ListView: off-screen sections must keep their stream subscriptions.
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(20, 10, 20, 24 + MediaQuery.paddingOf(context).bottom),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const KMark(size: 40),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Hi, $name', style: KText.h3(K.paper)),
                          StreamBuilder<DriverRating>(
                            stream: _rating,
                            builder: (_, r) => Text(
                              (r.data?.count ?? 0) == 0
                                  ? 'Drive safe. Every fare lands here.'
                                  : '★ ${r.data!.average.toStringAsFixed(1)} from ${r.data!.count} ${r.data!.count == 1 ? 'rating' : 'ratings'}',
                              style: KText.small(K.muteDark),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (api.isDemo) const Padding(padding: EdgeInsets.only(right: 10), child: DemoBadge()),
                    RoundIconButton(
                      icon: Icons.person_rounded,
                      tooltip: 'Account',
                      onTap: () => pushScreen(context, SettingsScreen(api: api, session: widget.session, onSignOut: widget.onSignOut)),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Entrance(
                  child: StreamBuilder<int?>(
                    stream: _balance,
                    builder: (_, b) => StreamBuilder<BankAccounts>(
                      stream: _accounts,
                      builder: (_, a) => StreamBuilder<List<Payment>>(
                        stream: _paymentsToday,
                        builder: (_, p) => _EarningsCard(
                          balance: b.data,
                          today: _todayTotal(p.data ?? const []),
                          accounts: a.data,
                          onPayOut: () => pushScreen(context, PayoutScreen(api: api)),
                          onBank: () => pushScreen(context, BankAccountScreen(api: api)),
                        ),
                      ),
                    ),
                  ),
                ),
                StreamBuilder<BusLoad?>(
                  stream: _bus,
                  builder: (_, s) => s.data == null
                      ? const SizedBox.shrink()
                      : StreamBuilder<List<Landmark>>(
                          stream: _landmarks,
                          builder: (_, places) => Padding(
                            padding: const EdgeInsets.only(top: 14),
                            child: _SeatsCard(load: s.data!, api: api, landmarks: places.data ?? const []),
                          ),
                        ),
                ),
                StreamBuilder<List<Park>>(
                  stream: _parks,
                  builder: (_, s) => (s.data ?? const []).isEmpty
                      ? const SizedBox.shrink()
                      : Padding(
                          padding: const EdgeInsets.only(top: 26),
                          child: _Parks(parks: s.data!),
                        ),
                ),
                const SizedBox(height: 26),
                Text('PAYMENTS', style: KText.kicker(K.muteDark)),
                const SizedBox(height: 4),
                StreamBuilder<List<Payment>>(
                  stream: _payments,
                  builder: (_, s) {
                    if (s.hasError) {
                      return const _Note(icon: Icons.cloud_off_rounded, text: 'Couldn\'t load your payments. Check your connection and try again.');
                    }
                    if (!s.hasData) {
                      return const Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(child: CircularProgressIndicator(color: K.yellow)),
                      );
                    }
                    if (s.data!.isEmpty) {
                      return const _Note(icon: Icons.qr_code_2_rounded, text: 'No fares yet. When a student scans your sticker, the payment shows up here.');
                    }
                    return Column(children: [for (final p in s.data!.take(15)) _PaymentTile(p)]);
                  },
                ),
                const SizedBox(height: 20),
                StreamBuilder<List<Payout>>(
                  stream: _payouts,
                  builder: (_, s) {
                    final list = s.data ?? const [];
                    if (list.isEmpty) return const SizedBox.shrink();
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('PAYOUTS', style: KText.kicker(K.muteDark)),
                        const SizedBox(height: 4),
                        for (final p in list) _PayoutTile(p),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static int _todayTotal(List<Payment> list) {
    final n = DateTime.now();
    return list.where((p) => !p.undone && p.at.year == n.year && p.at.month == n.month && p.at.day == n.day).fold(0, (t, p) => t + p.amountKobo);
  }
}

class _EarningsCard extends StatelessWidget {
  const _EarningsCard({required this.balance, required this.today, required this.accounts, required this.onPayOut, required this.onBank});
  final int? balance;
  final int today;
  final BankAccounts? accounts;
  final VoidCallback onPayOut, onBank;

  @override
  Widget build(BuildContext context) {
    final active = accounts?.active;
    final String where;
    if (accounts == null) {
      where = '';
    } else if (active == null && accounts!.pending == null) {
      where = 'Add a bank account to get paid.';
    } else if (active == null) {
      where = 'Your bank account is being checked.';
    } else if (active.onHold) {
      where = 'First payout to ****${active.last4} from ${untilText(active.holdUntil!)}.';
    } else {
      where = 'Paid to ****${active.last4} every evening at 9:30pm.';
    }
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 20, 18, 18),
      decoration: BoxDecoration(color: K.yellow, borderRadius: BorderRadius.circular(28)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('TO BE PAID OUT', style: KText.kicker(K.ink.withValues(alpha: 0.6))),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(balance == null ? '₦ ···' : naira(balance!), style: KText.hero(K.ink).copyWith(fontSize: 46)),
          ),
          const SizedBox(height: 4),
          Text('Today: ${naira(today)}', style: KText.body(K.ink).copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          Pressable(
            onTap: active == null ? onBank : onPayOut,
            child: Container(
              height: 50,
              decoration: BoxDecoration(color: K.ink, borderRadius: BorderRadius.circular(25)),
              alignment: Alignment.center,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(active == null ? Icons.account_balance_rounded : Icons.north_east_rounded, color: K.yellow, size: 20),
                  const SizedBox(width: 8),
                  Text(active == null ? 'Add bank account' : 'Pay out now', style: KText.body(K.yellow).copyWith(fontWeight: FontWeight.w800)),
                ],
              ),
            ),
          ),
          if (where.isNotEmpty) ...[
            const SizedBox(height: 10),
            Pressable(
              onTap: onBank,
              child: Text(where, style: KText.small(K.ink.withValues(alpha: 0.75)).copyWith(decoration: TextDecoration.underline)),
            ),
          ],
        ],
      ),
    );
  }
}

class _PaymentTile extends StatelessWidget {
  const _PaymentTile(this.p);
  final Payment p;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(color: (p.undone ? K.muteDark : K.go).withValues(alpha: 0.16), borderRadius: BorderRadius.circular(14)),
          child: Icon(p.undone ? Icons.undo_rounded : Icons.check_rounded, color: p.undone ? K.muteDark : K.go),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(p.riders == 1 ? '1 rider' : '${p.riders} riders', style: KText.body(K.paper).copyWith(fontWeight: FontWeight.w700)),
              Text(
                [whenText(p.at), p.reference, if (p.undone) 'Undone by rider'].join(' · '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: KText.small(K.muteDark),
              ),
            ],
          ),
        ),
        Text(
          '+${naira(p.amountKobo)}',
          style: KText.mono(p.undone ? K.muteDark : K.go, size: 15).copyWith(decoration: p.undone ? TextDecoration.lineThrough : null),
        ),
      ],
    ),
  );
}

class _PayoutTile extends StatelessWidget {
  const _PayoutTile(this.p);
  final Payout p;
  @override
  Widget build(BuildContext context) {
    final status = p.paid
        ? 'Paid'
        : p.returned
        ? 'Returned to your balance'
        : 'On its way';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: K.sky.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(14)),
            child: const Icon(Icons.account_balance_rounded, color: K.sky),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('To bank ****${p.last4}', style: KText.body(K.paper).copyWith(fontWeight: FontWeight.w700)),
                Text('${whenText(p.at)} · $status', style: KText.small(K.muteDark)),
              ],
            ),
          ),
          Text(
            naira(p.amountKobo),
            style: KText.mono(p.returned ? K.muteDark : K.paper, size: 15).copyWith(decoration: p.returned ? TextDecoration.lineThrough : null),
          ),
        ],
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({required this.icon, required this.text});
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) => Panel(
    child: Row(
      children: [
        Icon(icon, color: K.muteDark),
        const SizedBox(width: 12),
        Expanded(child: Text(text, style: KText.small(K.muteDark))),
      ],
    ),
  );
}

/// The trip route, the seats paid by scan on this trip, and "New trip" for when the bus has emptied.
class _SeatsCard extends StatefulWidget {
  const _SeatsCard({required this.load, required this.api, required this.landmarks});
  final BusLoad load;
  final DriverApi api;
  final List<Landmark> landmarks;

  @override
  State<_SeatsCard> createState() => _SeatsCardState();
}

class _SeatsCardState extends State<_SeatsCard> {
  // A trip times out on its own; re-check the clock now and then.
  late final Timer _tick = Timer.periodic(const Duration(seconds: 30), (_) => setState(() {}));
  bool _busy = false;

  @override
  void dispose() {
    _tick.cancel();
    super.dispose();
  }

  /// New trip: pick the route (the last one reversed, for the way back) and clear the seats.
  /// Change: fix the route mid-trip; riders on board stay counted.
  Future<void> _route({required bool newTrip}) async {
    if (widget.landmarks.length < 2) {
      if (newTrip) return _plainNewTrip();
      return showSnack(context, 'Ask a Konduct admin to add the places buses go.');
    }
    final r = widget.load.route;
    final choice = await showModalBottomSheet<(String, String)>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _RouteSheet(landmarks: widget.landmarks, newTrip: newTrip, from: newTrip ? r?.toId : r?.fromId, to: newTrip ? r?.fromId : r?.toId),
    );
    if (choice == null || !mounted) return;
    await _run(() async {
      final set = await widget.api.setRoute(fromId: choice.$1, toId: choice.$2, newTrip: newTrip);
      return newTrip ? 'New trip: ${set.label}, about ${set.etaMin} min.' : 'Route: ${set.label}, about ${set.etaMin} min.';
    });
  }

  /// Without landmarks there's no route to pick: just clear the seats.
  Future<void> _plainNewTrip() async {
    final go = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: K.ink2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text('Start a new trip?', style: KText.h3(K.paper)),
        content: Text('Seats paid by scan go back to 0. Do this when your riders have got off.', style: KText.body(K.muteDark)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Not yet', style: KText.body(K.paper).copyWith(fontWeight: FontWeight.w700)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('New trip', style: KText.body(K.yellow).copyWith(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
    if (go != true || !mounted) return;
    await _run(() async {
      await widget.api.newTrip();
      return 'New trip. All seats are free.';
    });
  }

  Future<void> _run(Future<String> Function() action) async {
    setState(() => _busy = true);
    try {
      final message = await action();
      if (mounted) showSnack(context, message);
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = widget.load;
    final taken = l.takenAt(DateTime.now()).clamp(0, l.capacity);
    final free = l.capacity - taken;
    final full = free == 0;
    final route = l.route;
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('THIS TRIP', style: KText.kicker(K.muteDark)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: K.yellow, borderRadius: BorderRadius.circular(6)),
                child: Text(l.plate, style: KText.mono(K.ink, size: 12)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.place_rounded, color: K.yellow, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: route == null
                    ? Text('No route set', style: KText.body(K.muteDark).copyWith(fontWeight: FontWeight.w700))
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(route.label, style: KText.body(K.paper).copyWith(fontWeight: FontWeight.w800)),
                          Text('About ${route.etaMin} min${route.setByStaff ? ' · set by Konduct staff' : ''}', style: KText.small(K.muteDark)),
                        ],
                      ),
              ),
              Pressable(
                onTap: _busy ? null : () => _route(newTrip: false),
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: Text(route == null ? 'Set' : 'Change', style: KText.small(K.yellow).copyWith(decoration: TextDecoration.underline)),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Divider(height: 1, color: const Color(0xFF2A313C)),
          ),
          Text('SEATS PAID BY SCAN', style: KText.kicker(K.muteDark)),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('$taken', style: KText.title(full ? K.coral : K.paper).copyWith(fontSize: 38)),
              Padding(
                padding: const EdgeInsets.only(left: 6, bottom: 5),
                child: Text('of ${l.capacity}', style: KText.body(K.muteDark).copyWith(fontWeight: FontWeight.w700)),
              ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Text(full ? 'Full on Konduct' : 'About $free free', style: KText.body(full ? K.coral : K.go).copyWith(fontWeight: FontWeight.w800)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ExcludeSemantics(
            child: Row(
              children: [
                for (var i = 0; i < l.capacity; i++) ...[
                  if (i > 0) const SizedBox(width: 4),
                  Expanded(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 260),
                      height: 10,
                      decoration: BoxDecoration(
                        color: i < taken ? (full ? K.coral : K.yellow) : Colors.transparent,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: i < taken ? Colors.transparent : const Color(0xFF2A313C), width: 1.5),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            full
                ? 'Riders can\'t pay by scan until you start a new trip. Cash riders aren\'t counted.'
                : 'Cash riders aren\'t counted. Clears on its own 15 minutes after the last scan.',
            style: KText.small(K.muteDark),
          ),
          const SizedBox(height: 14),
          Pressable(
            onTap: _busy ? null : () => _route(newTrip: true),
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: full ? K.yellow : Colors.transparent,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: full ? K.yellow : const Color(0xFF2A313C), width: 1.5),
              ),
              alignment: Alignment.center,
              child: _busy
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.4, color: K.yellow))
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.restart_alt_rounded, size: 20, color: full ? K.ink : K.paper),
                        const SizedBox(width: 8),
                        Text('New trip · bus emptied', style: KText.body(full ? K.ink : K.paper).copyWith(fontWeight: FontWeight.w800)),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Pick where this trip goes from and to. Returns (fromId, toId).
class _RouteSheet extends StatefulWidget {
  const _RouteSheet({required this.landmarks, required this.newTrip, this.from, this.to});
  final List<Landmark> landmarks;
  final bool newTrip;
  final String? from, to;
  @override
  State<_RouteSheet> createState() => _RouteSheetState();
}

class _RouteSheetState extends State<_RouteSheet> {
  late String? _from = _known(widget.from);
  late String? _to = _known(widget.to);

  String? _known(String? id) => widget.landmarks.any((l) => l.id == id) ? id : null;

  Widget _pick(String title, String? value, String? other, ValueChanged<String> onPick) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title, style: KText.kicker(K.muteDark)),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final l in widget.landmarks)
            Semantics(
              button: true,
              selected: value == l.id,
              child: Pressable(
                scale: 0.95,
                onTap: l.id == other ? null : () => onPick(l.id),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: value == l.id ? K.yellow : Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: value == l.id ? K.yellow : const Color(0xFF2A313C), width: 1.5),
                  ),
                  child: Text(
                    l.name,
                    style: KText.small(value == l.id ? K.ink : (l.id == other ? K.muteDark.withValues(alpha: 0.4) : K.paper)).copyWith(fontSize: 14),
                  ),
                ),
              ),
            ),
        ],
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final ready = _from != null && _to != null && _from != _to;
    return Container(
      decoration: const BoxDecoration(
        color: K.ink2,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(20, 12, 20, 16 + MediaQuery.paddingOf(context).bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(color: const Color(0xFF2A313C), borderRadius: BorderRadius.circular(3)),
              ),
            ),
            const SizedBox(height: 18),
            Text(widget.newTrip ? 'Start a new trip' : 'Change this trip\'s route', style: KText.h3(K.paper)),
            const SizedBox(height: 4),
            Text(
              widget.newTrip
                  ? 'Seats paid by scan go back to 0. Riders see where you\'re going and about how long it takes.'
                  : 'Riders already on board stay counted.',
              style: KText.small(K.muteDark),
            ),
            const SizedBox(height: 18),
            _pick('FROM', _from, _to, (id) => setState(() => _from = id)),
            const SizedBox(height: 18),
            _pick('TO', _to, _from, (id) => setState(() => _to = id)),
            const SizedBox(height: 22),
            KButton(label: widget.newTrip ? 'Start trip' : 'Save route', onTap: ready ? () => Navigator.of(context).pop((_from!, _to!)) : null),
          ],
        ),
      ),
    );
  }
}

/// How many buses staff last counted at each park.
class _Parks extends StatelessWidget {
  const _Parks({required this.parks});
  final List<Park> parks;

  static String _lower(String s) => s.isEmpty ? s : s[0].toLowerCase() + s.substring(1);

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('BUSES AT THE PARKS', style: KText.kicker(K.muteDark)),
        const SizedBox(height: 4),
        for (final park in parks)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Semantics(
              label: '${park.name}, ${park.busCount} ${park.busCount == 1 ? 'bus' : 'buses'}',
              excludeSemantics: true,
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(color: K.yellow.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(14)),
                    alignment: Alignment.center,
                    child: Text('${park.busCount}', style: KText.mono(K.yellow, size: 17)),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          park.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: KText.body(K.paper).copyWith(fontWeight: FontWeight.w700),
                        ),
                        Text(
                          [park.location, park.updatedAt == null ? 'not counted yet' : 'updated ${_lower(whenText(park.updatedAt!, now: now))}'].join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: KText.small(park.staleAt(now) ? K.coral : K.muteDark),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
