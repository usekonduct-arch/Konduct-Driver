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
          child: ListView(
            padding: EdgeInsets.fromLTRB(20, 10, 20, 24 + MediaQuery.paddingOf(context).bottom),
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
                        Text('Drive safe. Every fare lands here.', style: KText.small(K.muteDark)),
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
              const SizedBox(height: 26),
              Text('PAYMENTS', style: KText.kicker(K.muteDark)),
              const SizedBox(height: 4),
              StreamBuilder<List<Payment>>(
                stream: _payments,
                builder: (_, s) {
                  if (s.hasError) return const _Note(icon: Icons.cloud_off_rounded, text: 'Couldn\'t load your payments. Check your connection and try again.');
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
