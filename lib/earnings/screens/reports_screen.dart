import 'dart:async';
import 'dart:io' show File;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart' hide Text;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../../l10n/l10n.dart';
import '../../l10n/text.dart';
import '../../messages/messages_api.dart';
import '../../theme/tokens.dart';
import '../../ui/kit.dart';
import '../../ui/share_card.dart';
import '../../ui/wrapped.dart';
import '../driver_api.dart';
import '../earnings_ui.dart';
import '../models.dart';
import '../shift.dart';

const _short = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

String _dayLabel(DateTime d) => '${_weekdays[d.weekday - 1]} ${d.day} ${_short[d.month - 1]}';
/// "07:00": a 24-hour clock reads the same in every language the app speaks.
String _hourLabel(int h) => '${h.toString().padLeft(2, '0')}:00';
DateTime _today() {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day);
}

/// Home: today's money, trips, riders and fares, and the way into the full reports.
class TodayCard extends StatelessWidget {
  const TodayCard({super.key, required this.days, required this.onOpen, this.goal, this.onGoal, this.onEndShift});
  final List<DriverDay> days;
  final VoidCallback onOpen;

  /// The driver's daily goal in kobo, if they set one; tapping the bar changes it.
  final int? goal;
  final VoidCallback? onGoal;

  /// "End my shift": today's summary, read out loud.
  final VoidCallback? onEndShift;

  @override
  Widget build(BuildContext context) {
    final t = days.where((d) => d.day == _today()).firstOrNull ?? DriverDay(day: _today());
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text('TODAY', style: KText.kicker(K.muteDark)),
              const Spacer(),
              Pressable(
                onTap: onOpen,
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Text('Reports & statements', style: KText.small(K.yellow).copyWith(decoration: TextDecoration.underline)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(naira(t.netKobo), style: KText.title(K.paper).copyWith(fontSize: 34)),
          Text(t.refundsKobo > 0 ? 'earned · ${naira(t.refundsKobo)} refunded' : 'earned so far', style: KText.small(K.muteDark)),
          const SizedBox(height: 14),
          Row(
            children: [
              _Stat(value: '${t.trips}', label: t.trips == 1 ? 'trip' : 'trips'),
              _Stat(value: '${t.riders}', label: t.riders == 1 ? 'rider' : 'riders'),
              _Stat(value: '${t.fares}', label: t.fares == 1 ? 'payment' : 'payments'),
            ],
          ),
          if (onGoal != null) ...[
            const SizedBox(height: 16),
            GoalBar(earned: t.netKobo, goal: goal, onTap: onGoal!),
          ],
          if (onEndShift != null) ...[
            const SizedBox(height: 14),
            Pressable(
              onTap: onEndShift,
              child: Container(
                height: 44,
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(22), border: Border.all(color: const Color(0xFF2A313C), width: 1.5)),
                alignment: Alignment.center,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.record_voice_over_rounded, color: K.paper, size: 18),
                    const SizedBox(width: 8),
                    Text('End my shift', style: KText.body(K.paper).copyWith(fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});
  final String value, label;
  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(color: K.ink, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFF2A313C))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: KText.h3(K.paper)),
          Text(label, style: KText.small(K.muteDark)),
        ],
      ),
    ),
  );
}

/// The month's report: what came in and went out, day by day, with a PDF statement and Wrapped.
class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key, required this.api, required this.driverName});
  final DriverApi api;
  final String driverName;
  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  late DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  late Stream<List<DriverDay>> _days = widget.api.days(_month);
  late Future<List<Payout>> _payouts = widget.api.payoutsIn(_month);
  bool _busy = false;

  bool get _isThisMonth => _month.year == DateTime.now().year && _month.month == DateTime.now().month;

  void _go(int by) => setState(() {
    _month = DateTime(_month.year, _month.month + by);
    _days = widget.api.days(_month);
    _payouts = widget.api.payoutsIn(_month);
  });

  Future<void> _statement(DriverMonth m) async {
    setState(() => _busy = true);
    try {
      final payouts = await _payouts;
      final bytes = await monthlyStatementPdf(m, payouts, driverName: widget.driverName);
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/konduct-statement-${m.month.year}-${m.month.month.toString().padLeft(2, '0')}.pdf');
      await file.writeAsBytes(bytes, flush: true);
      await SharePlus.instance.share(ShareParams(files: [XFile(file.path, mimeType: 'application/pdf')], subject: 'Konduct statement, ${monthName(m.month)}'));
    } catch (_) {
      if (mounted) showSnack(context, 'Couldn\'t make the statement. Try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PageFrame(
      kicker: 'Reports',
      title: 'Your money',
      child: StreamBuilder<List<DriverDay>>(
        stream: _days,
        builder: (_, s) {
          final m = DriverMonth(_month, s.data ?? const []);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  RoundIconButton(icon: Icons.chevron_left_rounded, tooltip: 'Previous month', onTap: () => _go(-1)),
                  Expanded(
                    child: Text(
                      '${monthName(_month)}${_isThisMonth ? ' so far' : ''}',
                      textAlign: TextAlign.center,
                      style: KText.h3(K.paper),
                    ),
                  ),
                  Opacity(
                    opacity: _isThisMonth ? 0.3 : 1,
                    child: RoundIconButton(icon: Icons.chevron_right_rounded, tooltip: 'Next month', onTap: _isThisMonth ? () {} : () => _go(1)),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (!s.hasData)
                const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator(color: K.yellow)))
              else if (m.worked.isEmpty)
                const _Note('No fares this month yet. When riders pay you, the month adds up here.')
              else ...[
                _MoneyCard(month: m, payouts: _payouts),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _Stat(value: '${m.worked.length}', label: 'days worked'),
                    _Stat(value: '${m.trips}', label: 'trips'),
                    _Stat(value: '${m.riders}', label: 'riders'),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _Stat(value: naira(m.averagePerDayKobo), label: 'a day on average'),
                    _Stat(value: m.bestDay == null ? '-' : naira(m.bestDay!.netKobo), label: m.bestDay == null ? 'best day' : 'best: ${_dayLabel(m.bestDay!.day)}'),
                  ],
                ),
                const SizedBox(height: 22),
                Text('EACH DAY', style: KText.kicker(K.muteDark)),
                const SizedBox(height: 10),
                _DayBars(month: m, onDay: (d) => pushScreen(context, DayScreen(api: widget.api, day: d))),
                const SizedBox(height: 22),
                if (m.busiestHour != null) ...[
                  Text('BUSIEST HOURS', style: KText.kicker(K.muteDark)),
                  const SizedBox(height: 10),
                  _HourBars(byHour: m.byHour),
                  const SizedBox(height: 6),
                  Text('Your best hour is ${_hourLabel(m.busiestHour!)}.', style: KText.small(K.muteDark)),
                  const SizedBox(height: 22),
                ],
                if (m.topRoutes.isNotEmpty) ...[
                  Text('TOP ROUTES', style: KText.kicker(K.muteDark)),
                  const SizedBox(height: 8),
                  for (final r in m.topRoutes.take(4))
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          const Icon(Icons.alt_route_rounded, color: K.yellow, size: 18),
                          const SizedBox(width: 10),
                          Expanded(child: Text(r.key, style: KText.body(K.paper))),
                          Text('${r.value} fares', style: KText.small(K.muteDark)),
                        ],
                      ),
                    ),
                  const SizedBox(height: 18),
                ],
                KButton(label: 'Download statement (PDF)', icon: Icons.picture_as_pdf_rounded, loading: _busy, onTap: _busy ? null : () => _statement(m)),
                const SizedBox(height: 10),
                Pressable(
                  onTap: () => openDriverWrapped(context, widget.api, _month, firstName: widget.driverName.split(' ').first),
                  child: Container(
                    height: 52,
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(26), border: Border.all(color: K.yellow, width: 1.5)),
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.auto_awesome_rounded, color: K.yellow, size: 20),
                        const SizedBox(width: 8),
                        Text('Play my ${monthName(_month)} Wrapped', style: KText.body(K.paper).copyWith(fontWeight: FontWeight.w800)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 26),
                Text('DAYS', style: KText.kicker(K.muteDark)),
                const SizedBox(height: 4),
                for (final d in m.worked.reversed)
                  Pressable(
                    onTap: () => pushScreen(context, DayScreen(api: widget.api, day: d)),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(d.day == _today() ? 'Today' : _dayLabel(d.day), style: KText.body(K.paper).copyWith(fontWeight: FontWeight.w700)),
                                Text('${d.trips} trips · ${d.riders} riders', style: KText.small(K.muteDark)),
                              ],
                            ),
                          ),
                          Text(naira(d.netKobo), style: KText.mono(K.go, size: 15)),
                          const SizedBox(width: 6),
                          const Icon(Icons.chevron_right_rounded, color: K.muteDark),
                        ],
                      ),
                    ),
                  ),
              ],
            ],
          );
        },
      ),
    );
  }
}

/// Money in, refunds out, net, and what went to the bank this month.
class _MoneyCard extends StatelessWidget {
  const _MoneyCard({required this.month, required this.payouts});
  final DriverMonth month;
  final Future<List<Payout>> payouts;

  Widget _line(String k, String v, {Color color = K.paper}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        Expanded(child: Text(k, style: KText.body(K.muteDark))),
        Text(v, style: KText.mono(color, size: 15)),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(color: K.yellow, borderRadius: BorderRadius.circular(26)),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('YOU EARNED', style: KText.kicker(K.ink)),
        const SizedBox(height: 6),
        FittedBox(child: Text(naira(month.netKobo), style: KText.title(K.ink).copyWith(fontSize: 44))),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
          decoration: BoxDecoration(color: K.ink, borderRadius: BorderRadius.circular(16)),
          child: FutureBuilder<List<Payout>>(
            future: payouts,
            builder: (_, p) {
              final paid = (p.data ?? const <Payout>[]).where((x) => x.paid).fold(0, (t, x) => t + x.amountKobo);
              return Column(
                children: [
                  _line('Fares (${month.fares})', naira(month.grossKobo)),
                  if (month.refundsKobo > 0) _line('Refunds you covered', '-${naira(month.refundsKobo)}', color: K.coral),
                  _line('Paid to your bank', p.hasData ? naira(paid) : '…', color: K.go),
                ],
              );
            },
          ),
        ),
      ],
    ),
  );
}

/// One bar per day of the month; tap a bar to open the day.
class _DayBars extends StatelessWidget {
  const _DayBars({required this.month, required this.onDay});
  final DriverMonth month;
  final void Function(DriverDay) onDay;

  @override
  Widget build(BuildContext context) {
    final count = DateTime(month.month.year, month.month.month + 1, 0).day;
    final byDay = {for (final d in month.days) d.day.day: d};
    final top = month.days.fold(1, (t, d) => d.netKobo > t ? d.netKobo : t);
    final best = month.bestDay?.day.day;
    return SizedBox(
      height: 120,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 1; i <= count; i++)
            Expanded(
              child: Semantics(
                button: byDay[i] != null,
                label: byDay[i] == null ? null : tr('${_dayLabel(byDay[i]!.day)}: ${naira(byDay[i]!.netKobo)}'),
                child: GestureDetector(
                  onTap: byDay[i] == null ? null : () => onDay(byDay[i]!),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 1.2),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Container(
                          height: 4 + 84 * ((byDay[i]?.netKobo ?? 0).clamp(0, top) / top),
                          decoration: BoxDecoration(
                            color: byDay[i] == null ? const Color(0xFF2A313C) : (i == best ? K.yellow : K.go),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(i == 1 || i % 5 == 0 ? '$i' : '', maxLines: 1, softWrap: false, overflow: TextOverflow.visible, style: KText.small(K.muteDark).copyWith(fontSize: 9)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Money by hour of day, 5 am to 11 pm.
class _HourBars extends StatelessWidget {
  const _HourBars({required this.byHour});
  final Map<int, int> byHour;

  @override
  Widget build(BuildContext context) {
    final top = byHour.values.fold(1, (t, v) => v > t ? v : t);
    final peak = byHour.isEmpty ? null : byHour.entries.reduce((a, b) => b.value > a.value ? b : a).key;
    return SizedBox(
      height: 84,
      child: ExcludeSemantics(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (var h = 5; h <= 23; h++)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 1.5),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Container(
                        height: 3 + 60 * ((byHour[h] ?? 0) / top),
                        decoration: BoxDecoration(color: h == peak ? K.yellow : const Color(0xFF3A4350), borderRadius: BorderRadius.circular(3)),
                      ),
                      const SizedBox(height: 4),
                      Text(h % 3 == 0 ? (h < 12 ? '$h' : '${h == 12 ? 12 : h - 12}${h < 12 ? 'a' : 'p'}') : '', style: KText.small(K.muteDark).copyWith(fontSize: 9)),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// One day: its totals, hours and every fare.
class DayScreen extends StatelessWidget {
  const DayScreen({super.key, required this.api, required this.day});
  final DriverApi api;
  final DriverDay day;

  @override
  Widget build(BuildContext context) => PageFrame(
    kicker: 'Day report',
    title: day.day == _today() ? 'Today' : _dayLabel(day.day),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(naira(day.netKobo), style: KText.title(K.paper).copyWith(fontSize: 40)),
        Text(day.refundsKobo > 0 ? 'earned · ${naira(day.grossKobo)} in fares, ${naira(day.refundsKobo)} refunded' : 'earned', style: KText.small(K.muteDark)),
        const SizedBox(height: 14),
        Row(
          children: [
            _Stat(value: '${day.trips}', label: 'trips'),
            _Stat(value: '${day.riders}', label: 'riders'),
            _Stat(value: '${day.fares}', label: 'payments'),
          ],
        ),
        if (day.byHour.isNotEmpty) ...[
          const SizedBox(height: 22),
          Text('BY HOUR', style: KText.kicker(K.muteDark)),
          const SizedBox(height: 10),
          _HourBars(byHour: day.byHour),
        ],
        const SizedBox(height: 22),
        Text('FARES', style: KText.kicker(K.muteDark)),
        const SizedBox(height: 4),
        FutureBuilder<List<Payment>>(
          future: api.paymentsOn(day.day),
          builder: (_, s) {
            if (!s.hasData) return const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator(color: K.yellow)));
            if (s.data!.isEmpty) return const _Note('No fares on this day.');
            return Column(
              children: [
                for (final p in s.data!)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 52,
                          child: Text('${p.at.hour.toString().padLeft(2, '0')}:${p.at.minute.toString().padLeft(2, '0')}', style: KText.mono(K.muteDark, size: 13)),
                        ),
                        Expanded(
                          child: Text(
                            [p.reference, p.riders == 1 ? '1 rider' : '${p.riders} riders', if (p.undone) 'undone'].join(' · '),
                            style: KText.body(p.undone ? K.muteDark : K.paper),
                          ),
                        ),
                        Text(
                          naira(p.amountKobo),
                          style: KText.mono(p.undone ? K.muteDark : K.go, size: 14).copyWith(decoration: p.undone ? TextDecoration.lineThrough : null),
                        ),
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    ),
  );
}

class _Note extends StatelessWidget {
  const _Note(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Panel(
    child: Row(
      children: [
        const Icon(Icons.insights_rounded, color: K.muteDark),
        const SizedBox(width: 12),
        Expanded(child: Text(text, style: KText.small(K.paper))),
      ],
    ),
  );
}

/// The month as a printable statement. Amounts say NGN: the PDF's built-in font has no naira sign.
Future<List<int>> monthlyStatementPdf(DriverMonth m, List<Payout> payouts, {required String driverName}) {
  String ngn(int kobo) => 'NGN ${naira(kobo).replaceAll('₦', '')}';
  final paid = payouts.where((p) => p.paid).fold(0, (t, p) => t + p.amountKobo);
  final doc = pw.Document(title: 'Konduct statement, ${monthName(m.month)}', author: 'Konduct');
  final now = DateTime.now();
  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(40),
      header: (_) => pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text('KONDUCT', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, letterSpacing: 4)),
          pw.Text('Driver statement', style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700)),
        ],
      ),
      footer: (c) => pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text('Made ${now.day} ${_short[now.month - 1]} ${now.year} from Konduct\'s ledger.', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
          pw.Text('Page ${c.pageNumber} of ${c.pagesCount}', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
        ],
      ),
      build: (_) => [
        pw.SizedBox(height: 18),
        pw.Text(monthName(m.month), style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
        pw.Text(driverName, style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey800)),
        pw.SizedBox(height: 18),
        pw.TableHelper.fromTextArray(
          headers: ['Summary', ''],
          data: [
            ['Fares received (${m.fares})', ngn(m.grossKobo)],
            ['Refunds you covered', ngn(m.refundsKobo)],
            ['You earned', ngn(m.netKobo)],
            ['Paid to your bank', ngn(paid)],
            ['Days worked', '${m.worked.length}'],
            ['Trips', '${m.trips}'],
            ['Riders carried', '${m.riders}'],
            ['Average a day', ngn(m.averagePerDayKobo)],
          ],
          cellAlignments: {1: pw.Alignment.centerRight},
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          cellStyle: const pw.TextStyle(fontSize: 10),
        ),
        pw.SizedBox(height: 20),
        pw.Text('Day by day', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 8),
        pw.TableHelper.fromTextArray(
          headers: ['Day', 'Trips', 'Riders', 'Fares', 'Refunds', 'Earned'],
          data: [
            for (final d in m.worked) [_dayLabel(d.day), '${d.trips}', '${d.riders}', ngn(d.grossKobo), d.refundsKobo == 0 ? '-' : ngn(d.refundsKobo), ngn(d.netKobo)],
          ],
          cellAlignments: {for (var i = 1; i < 6; i++) i: pw.Alignment.centerRight},
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
          cellStyle: const pw.TextStyle(fontSize: 9),
        ),
        if (payouts.isNotEmpty) ...[
          pw.SizedBox(height: 20),
          pw.Text('Payouts', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          pw.TableHelper.fromTextArray(
            headers: ['Date', 'To account', 'Status', 'Amount'],
            data: [
              for (final p in payouts) ['${p.at.day} ${_short[p.at.month - 1]}', p.last4.isEmpty ? '-' : '****${p.last4}', p.status, ngn(p.amountKobo)],
            ],
            cellAlignments: {3: pw.Alignment.centerRight},
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
            cellStyle: const pw.TextStyle(fontSize: 9),
          ),
        ],
      ],
    ),
  );
  return doc.save();
}

/// A driver's month as Wrapped slides and a summary card.
({List<WrappedSlide> slides, List<(String, String)> stats}) driverWrapped(DriverMonth m, String firstName) {
  final slides = <WrappedSlide>[];
  var c = 0;
  WrappedSlide slide({required String kicker, required String big, required String headline, String? sub, IconData? icon}) {
    final (bg, fg) = wrappedColors[c++ % wrappedColors.length];
    return WrappedSlide(kicker: kicker, big: big, headline: headline, sub: sub, background: bg, foreground: fg, icon: icon);
  }

  slides.add(slide(kicker: 'Konduct Wrapped', big: monthName(m.month), headline: firstName.isEmpty ? 'Your month behind the wheel.' : 'Your month behind the wheel, $firstName.', sub: 'Tap to see it.', icon: Icons.auto_awesome_rounded));
  slides.add(slide(kicker: 'You earned', big: naira(m.netKobo), headline: 'through Konduct', sub: '${naira(m.averagePerDayKobo)} a day on the ${m.worked.length} days you drove.', icon: Icons.payments_rounded));
  slides.add(slide(kicker: 'You carried', big: '${m.riders}', headline: 'riders', sub: 'Over ${m.trips} trips. That\'s a lot of students on time.', icon: Icons.groups_rounded));
  final best = m.bestDay;
  if (best != null) slides.add(slide(kicker: 'Your best day', big: _dayLabel(best.day), headline: '${naira(best.netKobo)} in one day', sub: '${best.trips} trips and ${best.riders} riders.', icon: Icons.emoji_events_rounded));
  final hour = m.busiestHour;
  if (hour != null) slides.add(slide(kicker: 'Your golden hour', big: _hourLabel(hour), headline: 'is when the money flows', sub: 'Plan your day around it.', icon: Icons.schedule_rounded));
  if (m.topRoutes.isNotEmpty) {
    final r = m.topRoutes.first;
    slides.add(slide(kicker: 'Your road', big: '${r.value}×', headline: r.key, sub: 'Your most-driven route.', icon: Icons.alt_route_rounded));
  }
  return (
    slides: slides,
    stats: [
      ('Earned', naira(m.netKobo)),
      ('Riders', '${m.riders}'),
      ('Trips', '${m.trips}'),
      ('Days driven', '${m.worked.length}'),
      if (best != null) ('Best day', _dayLabel(best.day)),
      if (hour != null) ('Golden hour', _hourLabel(hour)),
    ],
  );
}

/// Loads [month] and plays the driver's Wrapped.
Future<void> openDriverWrapped(BuildContext context, DriverApi api, DateTime month, {required String firstName}) async {
  final navigator = Navigator.of(context);
  final messenger = ScaffoldMessenger.of(context);
  try {
    final days = await api.days(month).first.timeout(const Duration(seconds: 8));
    final brand = await api.messages.brand().first.timeout(const Duration(seconds: 4), onTimeout: () => const Brand());
    final sponsor = await api.messages.wrappedSponsor(month).timeout(const Duration(seconds: 4), onTimeout: () => null);
    // The share card is drawn off-screen into a picture: its logo has to be loaded first.
    if (sponsor != null && sponsor.logoUrl.isNotEmpty && navigator.mounted) {
      await precacheImage(CachedNetworkImageProvider(sponsor.logoUrl), navigator.context).catchError((_) {});
    }
    final m = DriverMonth(month, days);
    if (m.worked.isEmpty) {
      messenger.showSnackBar(SnackBar(content: Text('No fares in ${monthName(month)}, so no Wrapped yet.')));
      return;
    }
    final w = driverWrapped(m, firstName);
    navigator.push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => WrappedStory(
          slides: w.slides,
          sponsor: sponsor,
          tracker: api.messages.tracker,
          card: StoryCard(
            kicker: 'My ${monthName(month)} driving with Konduct',
            headline: 'Konduct\nWrapped',
            stats: w.stats,
            tags: brand.cardTags,
            style: StoryStyle.driver,
            sponsorName: sponsor?.name ?? '',
            sponsorLogoUrl: sponsor?.logoUrl ?? '',
          ),
          caption: brand.caption('My ${monthName(month)} driving with Konduct: ${m.riders} riders, ${m.trips} trips, all cashless.'),
          fileName: 'konduct-wrapped-${month.year}-${month.month}',
        ),
      ),
    );
  } catch (_) {
    messenger.showSnackBar(const SnackBar(content: Text('Couldn\'t load your Wrapped. Check your connection and try again.')));
  }
}
