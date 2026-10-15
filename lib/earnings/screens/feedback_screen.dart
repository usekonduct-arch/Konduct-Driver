import 'package:flutter/material.dart' hide Text;

import '../../l10n/l10n.dart';
import '../../l10n/text.dart';
import '../../theme/tokens.dart';
import '../driver_api.dart';
import '../earnings_ui.dart';
import '../models.dart';

/// What riders said: the average, how the latest ratings split, and their comments by day. Riders
/// are never named, and there are no times or routes, so a comment can't be traced to one trip.
class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({super.key, required this.api});
  final DriverApi api;

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  late Future<RatingFeedback> _fb = widget.api.ratingFeedback();

  Future<void> _refresh() async {
    setState(() => _fb = widget.api.ratingFeedback());
    await _fb.catchError((_) => const RatingFeedback(average: null, count: 0, recentStars: [0, 0, 0, 0, 0], recent: []));
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return PageFrame(
      kicker: 'Your ratings',
      title: 'What riders say',
      onRefresh: _refresh,
      child: FutureBuilder<RatingFeedback>(
        future: _fb,
        builder: (context, snap) {
          if (snap.hasError) {
            return Panel(child: Text(snap.error is ApiException ? (snap.error as ApiException).message : 'Couldn\'t load your ratings. Pull down to try again.', style: KText.body(p.subtle)));
          }
          if (!snap.hasData) return const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator(color: K.yellow)));
          final f = snap.data!;
          if (f.count == 0) {
            return Panel(child: Text('No ratings yet. Riders can rate you after each trip.', style: KText.body(p.subtle)));
          }
          final total = f.recentStars.fold(0, (a, b) => a + b);
          final comments = f.recent.where((r) => r.comment.trim().isNotEmpty).toList();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Panel(
                child: Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('★ ${f.average?.toStringAsFixed(1) ?? '–'}', style: KText.title(K.yellow)),
                        Text(f.count == 1 ? 'from 1 rating' : 'from ${f.count} ratings', style: KText.small(p.subtle)),
                      ],
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        children: [
                          for (var star = 5; star >= 1; star--)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: Semantics(
                                label: tr('{n} stars: {count}', {'n': star, 'count': f.recentStars[star - 1]}),
                                excludeSemantics: true,
                                child: Row(
                                  children: [
                                    SizedBox(width: 14, child: Text('$star', style: KText.mono(p.subtle, size: 12))),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(4),
                                        child: LinearProgressIndicator(
                                          value: total == 0 ? 0 : f.recentStars[star - 1] / total,
                                          minHeight: 7,
                                          backgroundColor: K.ink,
                                          valueColor: const AlwaysStoppedAnimation(K.yellow),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text('Bars show your latest ${f.recent.length} ratings.', style: KText.small(p.subtle)),
              const SizedBox(height: 22),
              Text('COMMENTS', style: KText.kicker(p.subtle)),
              const SizedBox(height: 8),
              if (comments.isEmpty)
                Panel(child: Text('No comments yet. Riders can add one when they rate you.', style: KText.body(p.subtle)))
              else
                for (final c in comments)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Panel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text('★' * c.stars, semanticsLabel: tr('{n} stars', {'n': c.stars}), style: KText.body(K.yellow)),
                              const Spacer(),
                              Text(_day(c.day), style: KText.small(p.subtle)),
                            ],
                          ),
                          const SizedBox(height: 6),
                          // What the rider wrote, as they wrote it.
                          Text(c.comment, translate: false, style: KText.body(p.text)),
                        ],
                      ),
                    ),
                  ),
              const SizedBox(height: 8),
              Text('Riders\' names are never shown, and comments only show the day.', style: KText.small(p.subtle)),
            ],
          );
        },
      ),
    );
  }

  static String _day(DateTime d) {
    final n = DateTime.now();
    final today = DateTime(n.year, n.month, n.day);
    if (d == today) return tr('Today');
    if (d == today.subtract(const Duration(days: 1))) return tr('Yesterday');
    return '${d.day} ${monthShort(d.month)}';
  }
}
