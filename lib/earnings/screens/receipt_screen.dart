import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/app_info.dart';
import '../../theme/tokens.dart';
import '../../ui/kit.dart';
import '../../ui/receipt_printer.dart';
import '../../ui/web_screen.dart';
import '../driver_api.dart';
import '../earnings_ui.dart';
import '../models.dart';
import '../../support/support_screens.dart';

/// The full breakdown of one fare or payout, printed like a POS slip and checked against the
/// ledger. Give it a [payment] or a [payout].
class ReceiptScreen extends StatefulWidget {
  const ReceiptScreen({super.key, required this.api, this.payment, this.payout}) : assert((payment == null) != (payout == null));
  final DriverApi api;
  final Payment? payment;
  final Payout? payout;

  @override
  State<ReceiptScreen> createState() => _ReceiptScreenState();
}

class _ReceiptScreenState extends State<ReceiptScreen> {
  late final Future<Slip> _slip = _load();
  ReceiptProof? _proof;
  bool _printed = false;

  String get _id => widget.payment?.id ?? widget.payout!.id;
  String get _reference => widget.payment?.reference ?? _shortId(widget.payout!.id);

  Future<Slip> _load() async {
    ReceiptProof? proof;
    String? problem;
    try {
      proof = await widget.api.receiptProof(id: _id, payout: widget.payout != null).timeout(const Duration(seconds: 10));
    } on ApiException catch (e) {
      problem = e.message;
    } catch (_) {
      problem = 'No connection to Konduct, so this copy isn\'t verified yet.';
    }
    if (mounted) setState(() => _proof = proof);
    return widget.payment != null ? _fareSlip(widget.payment!, proof, problem) : _payoutSlip(widget.payout!, proof, problem);
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final url = _proof?.verifyUrl;
    return PageFrame(
      trailing: SupportButton(api: widget.api.support),
      kicker: 'Receipt',
      title: widget.payment != null ? 'Fare received' : 'Payout',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ReceiptPrinter(slip: _slip, fileName: 'konduct-receipt-$_reference', onPrinted: () => setState(() => _printed = true)),
          const SizedBox(height: 18),
          AnimatedOpacity(
            opacity: _printed ? 1 : 0,
            duration: const Duration(milliseconds: 400),
            child: IgnorePointer(
              ignoring: !_printed,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (url != null)
                    KButton(
                      label: 'Verify online',
                      icon: Icons.verified_rounded,
                      onTap: () => openWeb(context, url, title: 'Receipt check'),
                    ),
                  Center(
                    child: Pressable(
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: _reference));
                        showSnack(context, 'Reference copied');
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.copy_rounded, size: 16, color: p.subtle),
                            const SizedBox(width: 6),
                            Text('Copy reference $_reference', style: KText.small(p.subtle)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _shortId(String id) {
  final bare = id.replaceFirst(RegExp(r'^(po_|fare_)'), '');
  return (bare.length > 10 ? bare.substring(bare.length - 10) : bare).toUpperCase();
}

const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

/// "Wed 15 Oct 2026 · 14:05:09"
String receiptTime(DateTime t) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${_days[t.weekday - 1]} ${t.day} ${_months[t.month - 1]} ${t.year} · ${two(t.hour)}:${two(t.minute)}:${two(t.second)}';
}

SlipSeal _seal({required bool reversed, required bool pending, ReceiptProof? proof, String? problem}) {
  if (reversed) return SlipSeal.voided;
  if (proof?.verified == true) return SlipSeal.verified;
  if (pending) return SlipSeal.pending;
  if (problem != null) return SlipSeal.unverified;
  return SlipSeal.none;
}

const _place = '${AppConfig.campusName} · ${AppConfig.campusPlace}';

Slip _fareSlip(Payment p, ReceiptProof? proof, String? problem) => Slip(
  heading: 'Fare received',
  amount: naira(p.amountKobo),
  strikeAmount: p.undone,
  when: receiptTime(p.at),
  place: _place,
  lines: [
    SlipLine('Ref', p.reference.isEmpty ? _shortId(p.id) : p.reference, strong: true),
    SlipLine('Riders', p.riders == 1 ? '1 rider' : '${p.riders} riders'),
    SlipLine('Each', naira(p.riders <= 0 ? p.amountKobo : p.amountKobo ~/ p.riders)),
    const SlipLine('Paid by', 'Konduct wallet'),
  ],
  totals: [if (proof?.balanceAfterKobo != null && !p.undone) SlipLine('To be paid out', naira(proof!.balanceAfterKobo!))],
  status: p.undone ? 'Undone by rider' : 'Received',
  seal: _seal(reversed: p.undone, pending: false, proof: proof, problem: problem),
  verifyUrl: p.undone ? null : proof?.verifyUrl,
  fingerprint: proof?.fingerprint,
  note: problem,
  footer: 'Drive safe',
);

Slip _payoutSlip(Payout p, ReceiptProof? proof, String? problem) => Slip(
  heading: 'Payout to bank',
  amount: naira(p.amountKobo),
  strikeAmount: p.returned,
  when: receiptTime(p.at),
  place: _place,
  lines: [
    SlipLine('Ref', _shortId(p.id), strong: true),
    if (p.last4.isNotEmpty) SlipLine('To account', '****${p.last4}'),
    SlipLine('Sent by', p.trigger == 'daily' ? 'Evening payout run' : 'Pay out now'),
    const SlipLine('Processor', 'Bachs'),
  ],
  status: p.paid ? 'Paid to your bank' : (p.returned ? 'Returned to your balance' : 'On its way'),
  seal: _seal(reversed: p.returned, pending: p.onItsWay, proof: proof, problem: problem),
  verifyUrl: p.returned ? null : proof?.verifyUrl,
  fingerprint: proof?.fingerprint,
  note: problem,
  footer: 'Drive safe',
);
