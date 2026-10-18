import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/mascot/mascot.dart';
import '../../core/theme/palettes.dart';
import '../../core/widgets/categories.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/member_avatar.dart';
import '../../core/widgets/mood_face.dart';
import '../../core/widgets/nest_ui.dart';
import '../../data/providers.dart';
import 'monthly_recap.dart';

/// A month in review: spending vs budget, top categories, savings, who paid
/// and check-ins, with the birds' take. The card can be shared as an image.
class RecapScreen extends ConsumerStatefulWidget {
  const RecapScreen({super.key, this.month});

  final DateTime? month;

  @override
  ConsumerState<RecapScreen> createState() => _RecapScreenState();
}

class _RecapScreenState extends ConsumerState<RecapScreen> {
  late DateTime _month = monthStart(widget.month ?? ref.read(nowProvider)());
  final _cardKey = GlobalKey();
  bool _sharing = false;

  void _shift(int delta) => setState(() => _month = DateTime(_month.year, _month.month + delta));

  Future<void> _share() async {
    final boundary = _cardKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return;
    setState(() => _sharing = true);
    try {
      // Let the card paint its solid background before capturing it.
      await WidgetsBinding.instance.endOfFrame;
      final image = await boundary.toImage(pixelRatio: 3);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) return;
      final name = 'pairnest-${_month.year}-${_month.month.toString().padLeft(2, '0')}.png';
      final shared = await ref.read(shareImageProvider)(data.buffer.asUint8List(), name);
      if (!shared && mounted) showSnack(context, 'Image saved');
    } catch (e) {
      if (mounted) showSnack(context, friendlyError(e));
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final recap = ref.watch(recapProvider(_month));
    final now = ref.watch(nowProvider)();
    final isFuture = _month.isAfter(monthStart(now));

    return Scaffold(
      body: NestBackground(
        child: SafeArea(
          child: Column(
            children: [
              PageHeader(
                '${monthName(_month)} recap',
                trailing: IconButton(
                  tooltip: 'Share recap',
                  onPressed: _sharing || recap.value == null || recap.value!.isEmpty ? null : _share,
                  icon: _sharing
                      ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.ios_share_rounded),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(tooltip: 'Previous month', icon: const Icon(Icons.chevron_left_rounded), onPressed: () => _shift(-1)),
                  Text(monthLabel(_month), style: const TextStyle(fontWeight: FontWeight.w700)),
                  IconButton(
                    tooltip: 'Next month',
                    icon: const Icon(Icons.chevron_right_rounded),
                    onPressed: isFuture || _month == monthStart(now) ? null : () => _shift(1),
                  ),
                ],
              ),
              Expanded(
                child: switch (recap) {
                  AsyncData(:final value) when value.isEmpty => EmptyState(
                    title: 'Nothing to recap for ${monthName(_month)} yet',
                    message: 'Log what you spend and check in on how you feel, and your recap fills itself in.',
                  ),
                  AsyncData(:final value) => ListView(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
                    children: [
                      RepaintBoundary(
                        key: _cardKey,
                        child: _RecapCard(value, solid: _sharing),
                      ),
                    ],
                  ),
                  AsyncError(:final error) => ErrorRetry(error: error, onRetry: () => ref.invalidate(recapProvider(_month))),
                  _ => const SkeletonList(cards: 3),
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String monthName(DateTime m) => monthLabel(m).split(' ').first;

/// Everything in the recap, on one background so it shares as one image.
class _RecapCard extends ConsumerWidget {
  const _RecapCard(this.r, {this.solid = false});

  /// Paint a solid background, so the shared image isn't transparent.
  final bool solid;

  final MonthlyRecap r;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.pn;
    final me = ref.watch(meProvider);
    final hide = ref.watch(hideAmountsProvider);
    String money(double v) => hide ? '₱••••' : peso(v);
    final under = r.verdict == RecapVerdict.underBudget;
    final over = r.verdict == RecapVerdict.overBudget;
    final line = switch (r.verdict) {
      RecapVerdict.underBudget => 'You stayed ${money(r.underBy)} under budget. Nicely done!',
      RecapVerdict.overBudget => '${money(r.overBy)} over this month. A gentle reset next month?',
      RecapVerdict.noBudget => 'You spent ${money(r.spent)} together.',
      RecapVerdict.quiet => 'A quiet month. Nothing logged yet.',
    };
    final title = TextStyle(fontWeight: FontWeight.w700, color: p.heading, fontSize: 15);
    final muted = TextStyle(color: p.muted, fontSize: 12.5);

    Widget section(IconData icon, String label, Widget child) => Padding(
      padding: const EdgeInsets.only(top: 14),
      child: PairnestCard(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: p.primaryDeep),
                const SizedBox(width: 8),
                Text(label, style: title),
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );

    return ColoredBox(
      color: solid ? p.background : Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            HeroCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${monthLabel(r.month)} · ${me.coupleNames}',
                    style: const TextStyle(color: Color(0xDDFFFFFF), fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${money(r.spent)} spent',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: Colors.white, fontSize: 30),
                  ),
                  if (r.budgetTotal > 0) ...[
                    const SizedBox(height: 4),
                    Text(
                      'of ${money(r.budgetTotal)} budget · ${(r.budgetRatio * 100).round()}%',
                      style: const TextStyle(color: Color(0xDDFFFFFF), fontSize: 13),
                    ),
                    const SizedBox(height: 12),
                    HeroProgress(r.budgetRatio),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 14),
            PairnestCard(
              padding: const EdgeInsets.fromLTRB(12, 12, 16, 12),
              child: Row(
                children: [
                  MascotPair(
                    width: 96,
                    leaves: false,
                    animate: true,
                    mood: over ? MascotMood.thoughtful : MascotMood.idle,
                    playOnMount: under ? MascotReaction.cheer : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      line,
                      style: TextStyle(fontWeight: FontWeight.w600, color: p.heading, height: 1.35),
                    ),
                  ),
                ],
              ),
            ),
            if (r.topCategories.isNotEmpty)
              section(
                Icons.pie_chart_outline_rounded,
                'Where it went',
                Column(
                  children: [
                    for (final (key, amount, share) in r.topCategories)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          children: [
                            CategoryIcon(key, size: 34),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(categoryStyle(key).label, style: const TextStyle(fontWeight: FontWeight.w600)),
                                      ),
                                      Text(money(amount), style: const TextStyle(fontWeight: FontWeight.w700)),
                                    ],
                                  ),
                                  const SizedBox(height: 5),
                                  SoftProgress(share, color: categoryStyle(key).color),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            if (r.savedNet > 0 || r.goalsCompleted.isNotEmpty)
              section(
                Icons.track_changes_rounded,
                'Saved together',
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (r.savedNet > 0) Text('${money(r.savedNet)} moved into goals', style: const TextStyle(fontWeight: FontWeight.w600)),
                    if (r.savedByGoal.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          for (final e in r.savedByGoal.entries)
                            Chip(label: Text('${e.key} · ${money(e.value)}'), visualDensity: VisualDensity.compact),
                        ],
                      ),
                    ],
                    for (final g in r.goalsCompleted) ...[
                      const SizedBox(height: 8),
                      Text(
                        '🎉 $g reached!',
                        style: TextStyle(fontWeight: FontWeight.w700, color: p.primaryDeep),
                      ),
                    ],
                  ],
                ),
              ),
            if (r.paidBy.length > 1 && r.spent > 0)
              section(
                Icons.people_alt_outlined,
                'Who paid',
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final s in r.paidBy)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            MemberAvatar(userId: s.member.id, name: s.member.name, size: 30),
                            const SizedBox(width: 10),
                            Expanded(child: Text(s.member.id == me.user.id ? '${s.member.name} (you)' : s.member.name)),
                            Text('${money(s.amount)} · ${(s.share * 100).round()}%', style: const TextStyle(fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ),
                    Text('${r.paidBy.first.member.name} covered ${(r.paidBy.first.share * 100).round()}% of spending.', style: muted),
                  ],
                ),
              ),
            section(
              Icons.favorite_outline_rounded,
              'Moments',
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (r.topMood != null) ...[MoodFace(r.topMood!, size: 30), const SizedBox(width: 10)],
                      Expanded(
                        child: Text(
                          r.checkIns == 0
                              ? 'No check-ins this month'
                              : '${r.checkIns} ${r.checkIns == 1 ? 'check-in' : 'check-ins'} · mostly ${moodStyle(r.topMood!).label.toLowerCase()}',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                  if (r.biggestExpense != null) ...[
                    const SizedBox(height: 10),
                    Text('Biggest expense: ${r.biggestExpense!.title} · ${money(r.biggestExpense!.amount)}', style: muted),
                  ],
                  if (r.changeVsLastMonth != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      '${r.changeVsLastMonth! > 0 ? '↑' : '↓'} ${(r.changeVsLastMonth!.abs() * 100).round()}% '
                      '${r.changeVsLastMonth! > 0 ? 'more' : 'less'} spending than ${monthName(DateTime(r.month.year, r.month.month - 1))}',
                      style: muted,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text('Made with Pairnest', textAlign: TextAlign.center, style: muted.copyWith(fontSize: 11.5)),
          ],
        ),
      ),
    );
  }
}
