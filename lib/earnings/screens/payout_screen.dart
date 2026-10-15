import 'package:flutter/material.dart' hide Text;
import 'package:flutter/services.dart';

import '../../l10n/text.dart';
import '../../security/biometric.dart';
import '../../theme/tokens.dart';
import '../../ui/flow_scaffold.dart';
import '../../ui/kit.dart';
import '../driver_api.dart';
import '../earnings_ui.dart';
import '../models.dart';
import 'bank_account_screen.dart';
import '../../support/support_screens.dart';

/// Pays the whole balance to the driver's bank now, instead of waiting for the 9:30pm run.
class PayoutScreen extends StatefulWidget {
  const PayoutScreen({super.key, required this.api});
  final DriverApi api;
  @override
  State<PayoutScreen> createState() => _PayoutScreenState();
}

class _PayoutScreenState extends State<PayoutScreen> {
  late final _balance = widget.api.balance();
  late final _accounts = widget.api.bankAccounts();
  bool _busy = false;
  String? _error;

  Future<void> _go(BankAccount to) async {
    final pin = await askPin(context, title: 'Enter your PIN', message: 'To pay out to ****${to.last4}.', biometric: true);
    if (pin == null || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final amount = await widget.api.payOutNow(pin: pin);
      if (!mounted) return;
      HapticFeedback.heavyImpact();
      Navigator.of(context).pop();
      showSnack(context, '${naira(amount)} is on its way to ****${to.last4}. Banks usually take a few minutes.');
    } on ApiException catch (e) {
      final stale = await BiometricPin.instance.rejected(e.reason);
      if (mounted) setState(() => _error = stale ? "Your saved PIN didn't work, so fingerprint payments are off. Try again and type your PIN." : e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return StreamBuilder<BankAccounts>(
      stream: _accounts,
      builder: (context, acc) => StreamBuilder<int?>(
        stream: _balance,
        builder: (context, bal) {
          final balance = bal.data ?? 0;
          final to = acc.data?.active;
          final enough = balance >= minWithdrawKobo;
          final ready = to != null && !to.onHold;
          return PageFrame(
            trailing: SupportButton(api: widget.api.support),
            kicker: 'Pay out',
            title: ready ? 'Get paid now' : 'Not ready yet',
            bottom: ready
                ? KButton(label: enough ? 'Pay out ${naira(balance)}' : 'Pay out', loading: _busy, onTap: enough ? () => _go(to) : null)
                : to == null && acc.data?.pending == null
                ? KButton(
                    label: 'Add a bank account',
                    icon: Icons.account_balance_rounded,
                    onTap: () => pushScreen(context, AddBankScreen(api: widget.api)),
                  )
                : null,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Panel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('YOUR BALANCE', style: KText.kicker(p.subtle)),
                      const SizedBox(height: 6),
                      Text(naira(balance), style: KText.title(p.text)),
                      if (to != null) ...[const SizedBox(height: 14), Text('To ${to.accountName} · ****${to.last4}', style: KText.small(p.text))],
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  !acc.hasData
                      ? ''
                      : to == null
                      ? (acc.data!.pending != null
                            ? 'A Konduct team member is checking your bank account. Payouts start once it\'s approved and 24 hours have passed.'
                            : 'Add a bank account in your own name to get paid.')
                      : to.onHold
                      ? 'Your new bank account can receive its first payout ${untilText(to.holdUntil!)}. This wait protects you if someone else got into your account.'
                      : !enough
                      ? 'Payouts start from ${naira(minWithdrawKobo)}. Your balance is also paid out automatically every evening at 9:30pm.'
                      : 'The whole balance goes to your bank. Konduct pays the bank fee. You\'re also paid automatically every evening at 9:30pm.',
                  style: KText.body(p.subtle),
                ),
                ErrorLine(_error),
              ],
            ),
          );
        },
      ),
    );
  }
}
