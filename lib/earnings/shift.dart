import 'package:flutter/material.dart' hide Text;
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/l10n.dart';
import '../l10n/text.dart';
import '../messages/voice.dart';
import '../theme/tokens.dart';
import '../ui/kit.dart';
import 'models.dart';

/// The driver's own target for a day's earnings, kept on this phone.
abstract final class DailyGoal {
  static const _key = 'konduct.dailyGoalKobo';

  /// Suggested targets, in kobo.
  static const choices = [500000, 1000000, 1500000, 2000000, 3000000];

  static Future<int?> load() async {
    try {
      final v = (await SharedPreferences.getInstance()).getInt(_key);
      return v == null || v <= 0 ? null : v;
    } catch (_) {
      return null;
    }
  }

  static Future<void> save(int? kobo) async {
    try {
      final p = await SharedPreferences.getInstance();
      kobo == null ? await p.remove(_key) : await p.setInt(_key, kobo);
    } catch (_) {}
  }
}

/// Picks a daily goal. Returns the goal in kobo, 0 to clear it, or null if dismissed.
Future<int?> pickGoal(BuildContext context, int? current) => showModalBottomSheet<int>(
  context: context,
  backgroundColor: Colors.transparent,
  builder: (context) {
    final p = Palette.of(context);
    return Container(
      decoration: BoxDecoration(color: p.bg, borderRadius: const BorderRadius.vertical(top: Radius.circular(28))),
      padding: EdgeInsets.fromLTRB(20, 12, 20, 16 + MediaQuery.paddingOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(child: Container(width: 44, height: 5, decoration: BoxDecoration(color: p.border, borderRadius: BorderRadius.circular(3)))),
          const SizedBox(height: 18),
          Text('Today\'s goal', style: KText.h3(p.text)),
          const SizedBox(height: 4),
          Text('How much do you want to make in a day? Only you see it.', style: KText.small(p.subtle)),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final k in DailyGoal.choices)
                ChoiceChip(
                  label: Text(naira(k)),
                  selected: k == current,
                  onSelected: (_) => Navigator.of(context).pop(k),
                  selectedColor: K.yellow,
                  labelStyle: KText.body(k == current ? K.ink : p.text).copyWith(fontWeight: FontWeight.w700),
                ),
            ],
          ),
          if (current != null) ...[
            const SizedBox(height: 10),
            TextButton(onPressed: () => Navigator.of(context).pop(0), child: Text('No goal', style: KText.body(p.subtle))),
          ],
        ],
      ),
    );
  },
);

/// Progress towards the daily goal, inside the Today card.
class GoalBar extends StatelessWidget {
  const GoalBar({super.key, required this.earned, required this.goal, required this.onTap});
  final int earned;
  final int? goal;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final g = goal;
    if (g == null) {
      return Pressable(
        onTap: onTap,
        child: Row(
          children: [
            const Icon(Icons.flag_rounded, color: K.yellow, size: 18),
            const SizedBox(width: 8),
            Text('Set a daily goal', style: KText.small(K.yellow).copyWith(decoration: TextDecoration.underline)),
          ],
        ),
      );
    }
    final share = (earned / g).clamp(0.0, 1.0);
    final done = earned >= g;
    return Semantics(
      button: true,
      label: tr('{earned} of your {goal} goal', {'earned': naira(earned), 'goal': naira(g)}),
      excludeSemantics: true,
      child: Pressable(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(done ? Icons.emoji_events_rounded : Icons.flag_rounded, color: done ? K.go : K.yellow, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    done ? 'Goal reached: ${naira(g)}' : '${naira(g - earned)} to your ${naira(g)} goal',
                    style: KText.small(K.paper).copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                Text('${(share * 100).round()}%', style: KText.mono(K.muteDark, size: 13)),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: share,
                minHeight: 8,
                backgroundColor: K.ink,
                valueColor: AlwaysStoppedAnimation(done ? K.go : K.yellow),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "End my shift": today's figures on one sheet, read out loud so the driver doesn't have to look.
Future<void> showShiftSummary(BuildContext context, DriverDay today, {int? goal}) {
  final best = today.byHour.entries.isEmpty ? null : today.byHour.entries.reduce((a, b) => b.value > a.value ? b : a);
  HapticFeedback.mediumImpact();
  Voice.saySentences([
    ('Shift summary.', null),
    ('You made {amount} today.', {'amount': Voice.amount(today.netKobo)}),
    if (today.trips > 0) today.trips == 1 ? ('1 trip.', null) : ('{n} trips.', {'n': today.trips}),
    if (today.riders > 0) today.riders == 1 ? ('1 rider.', null) : ('{n} riders.', {'n': today.riders}),
    if (goal != null)
      today.netKobo >= goal ? ('You reached your goal. Well done!', null) : ('{amount} short of your goal.', {'amount': Voice.amount(goal - today.netKobo)}),
    ('Drive safe.', null),
  ], clip: 'sounds/voice_payout_sent.wav');
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (context) {
      final p = Palette.of(context);
      Widget line(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Text(k, style: KText.body(p.subtle)),
            const Spacer(),
            Text(v, style: KText.body(p.text).copyWith(fontWeight: FontWeight.w800)),
          ],
        ),
      );
      return Container(
        decoration: BoxDecoration(color: p.bg, borderRadius: const BorderRadius.vertical(top: Radius.circular(28))),
        padding: EdgeInsets.fromLTRB(20, 12, 20, 16 + MediaQuery.paddingOf(context).bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(child: Container(width: 44, height: 5, decoration: BoxDecoration(color: p.border, borderRadius: BorderRadius.circular(3)))),
            const SizedBox(height: 18),
            Text('Shift summary', style: KText.h3(p.text)),
            const SizedBox(height: 12),
            Text(naira(today.netKobo), style: KText.hero(K.yellow)),
            Text('earned today', style: KText.small(p.subtle)),
            const SizedBox(height: 12),
            line('Trips', '${today.trips}'),
            line('Riders', '${today.riders}'),
            line('Payments', '${today.fares}'),
            if (today.refundsKobo > 0) line('Refunded', naira(today.refundsKobo)),
            if (best != null) line('Busiest hour', '${best.key.toString().padLeft(2, '0')}:00'),
            if (goal != null) line('Goal', today.netKobo >= goal ? tr('Reached') : tr('{amount} to go', {'amount': naira(goal - today.netKobo)})),
            const SizedBox(height: 14),
            KButton(label: 'Done', onTap: () => Navigator.of(context).pop()),
          ],
        ),
      );
    },
  );
}
