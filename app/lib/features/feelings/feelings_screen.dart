import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets/nest_ui.dart';
import '../../core/motion/motion.dart';
import '../../core/format.dart';
import '../../core/mascot/mascot.dart';
import '../../core/theme/palettes.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/member_avatar.dart';
import '../../core/widgets/member_colors.dart';
import '../../core/widgets/mood_face.dart';
import '../../data/models.dart';
import '../../data/providers.dart';

/// "Our Feelings" — shared mood history.
class FeelingsScreen extends ConsumerStatefulWidget {
  const FeelingsScreen({super.key});

  @override
  ConsumerState<FeelingsScreen> createState() => _FeelingsScreenState();
}

class _FeelingsScreenState extends ConsumerState<FeelingsScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final moods = ref.watch(moodsProvider);
    return Scaffold(
      body: NestBackground(
        child: SafeArea(
          child: Column(
            children: [
              PageHeader(
                'Our Feelings',
                showBack: false,
                trailing: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(minimumSize: const Size(0, 40), padding: const EdgeInsets.symmetric(horizontal: 16)),
                    onPressed: () => context.push('/feelings/check-in'),
                    icon: const Icon(Icons.favorite_rounded, size: 18),
                    label: const Text('Check in'),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: PillTabs(labels: const ['Recent', 'Both', 'Trends'], index: _tab, onChanged: (i) => setState(() => _tab = i)),
              ),
              Expanded(
                child: switch (moods) {
                  AsyncData(:final value) => RefreshIndicator(
                    onRefresh: () => ref.refresh(moodsProvider.future),
                    child: switch (_tab) {
                      0 => _Recent(value),
                      1 => _Both(value),
                      _ => _Trends(value),
                    },
                  ),
                  AsyncError(:final error) => ErrorRetry(error: error, onRetry: () => ref.invalidate(moodsProvider)),
                  _ => const SkeletonList(hero: false),
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConnectionBanner extends StatelessWidget {
  const _ConnectionBanner();

  @override
  Widget build(BuildContext context) {
    final p = context.pn;
    return PairnestCard(
      color: Color.lerp(p.surface, Pastel.lavender.light, p.isDark ? 0.08 : 0.55),
      child: Row(
        children: [
          const MascotPair(width: 70, leaves: false),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Small check-ins.\nBig connection.',
              style: TextStyle(fontWeight: FontWeight.w700, color: p.text, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

class _Recent extends ConsumerWidget {
  const _Recent(this.moods);

  final List<Mood> moods;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.pn;
    final recent = moods.take(30).toList();
    if (recent.isEmpty) {
      return EmptyState(
        title: 'How are you feeling?',
        message: 'Check in with a mood and a note. Keep it private or share it with your partner.',
        actionLabel: 'Check in',
        onAction: () => context.push('/feelings/check-in'),
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      children: [
        for (final (i, m) in recent.indexed) ...[
          FadeSlideIn(
            index: i,
            child: PairnestCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      MemberAvatar(userId: m.userId, name: m.userName, size: 40),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(m.userName, style: const TextStyle(fontWeight: FontWeight.w600)),
                            Text('${longDate(m.createdAt)} · ${timeLabel(m.createdAt)}', style: TextStyle(color: p.muted, fontSize: 12)),
                          ],
                        ),
                      ),
                      if (m.isPrivate)
                        Tooltip(
                          message: 'Only you can see this',
                          child: Icon(Icons.lock_rounded, size: 18, color: p.muted),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      MoodFace(m.mood, size: 26),
                      const SizedBox(width: 8),
                      Text(
                        moodStyle(m.mood).label,
                        style: TextStyle(fontWeight: FontWeight.w700, color: p.primaryDeep),
                      ),
                    ],
                  ),
                  if (m.note.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(m.note, style: TextStyle(color: p.text.withValues(alpha: 0.85), height: 1.4)),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        const _ConnectionBanner(),
      ],
    );
  }
}

class _Both extends ConsumerWidget {
  const _Both(this.moods);

  final List<Mood> moods;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(meProvider);
    final p = context.pn;
    final weekAgo = DateTime.now().subtract(const Duration(days: 7));
    final members = me.couple?.members ?? [me.user];

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final member in members) ...[
              Expanded(
                child: Builder(
                  builder: (context) {
                    final theirs = moods.where((m) => m.userId == member.id).toList();
                    final latest = theirs.firstOrNull;
                    final thisWeek = theirs.where((m) => m.createdAt.isAfter(weekAgo)).length;
                    return PairnestCard(
                      child: Column(
                        children: [
                          MemberAvatar(userId: member.id, name: member.name, size: 44),
                          const SizedBox(height: 8),
                          Text(member.id == me.user.id ? 'You' : member.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                          const SizedBox(height: 14),
                          if (latest == null)
                            Text('No check-in yet', style: TextStyle(color: p.muted, fontSize: 12))
                          else ...[
                            MoodFace(latest.mood, size: 52),
                            const SizedBox(height: 6),
                            Text(
                              moodStyle(latest.mood).label,
                              style: TextStyle(fontWeight: FontWeight.w700, color: p.primaryDeep),
                            ),
                            Text(shortDate(latest.createdAt), style: TextStyle(color: p.muted, fontSize: 12)),
                          ],
                          const SizedBox(height: 12),
                          Text('$thisWeek check-ins this week', style: TextStyle(color: p.muted, fontSize: 12)),
                        ],
                      ),
                    );
                  },
                ),
              ),
              if (member != members.last) const SizedBox(width: 12),
            ],
          ],
        ),
        const SizedBox(height: 16),
        if (members.length < 2)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(
              'Invite your partner from the Us tab to see their check-ins here.',
              textAlign: TextAlign.center,
              style: TextStyle(color: p.muted),
            ),
          ),
        const _ConnectionBanner(),
      ],
    );
  }
}

class _Trends extends ConsumerWidget {
  const _Trends(this.moods);

  final List<Mood> moods;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(meProvider);
    final p = context.pn;
    final members = me.couple?.members ?? [me.user];
    final since = DateTime.now().subtract(const Duration(days: 30));
    final recent = moods.where((m) => m.createdAt.isAfter(since)).toList();

    int count(int userId, String mood) => recent.where((m) => m.userId == userId && m.mood == mood).length;
    final maxY = [
      for (final s in moodStyles)
        for (final m in members) count(m.id, s.key),
    ].fold<int>(1, (a, b) => b > a ? b : a);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      children: [
        PairnestCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Last 30 days', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              Wrap(
                spacing: 14,
                children: [
                  for (final m in members)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircleAvatar(radius: 5, backgroundColor: memberColor(context, me.couple, m.id)),
                        const SizedBox(width: 6),
                        Text(m.name, style: TextStyle(fontSize: 12, color: p.muted)),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: 200,
                child: BarChart(
                  BarChartData(
                    maxY: maxY + 1,
                    gridData: const FlGridData(show: false),
                    borderData: FlBorderData(show: false),
                    titlesData: FlTitlesData(
                      leftTitles: const AxisTitles(),
                      rightTitles: const AxisTitles(),
                      topTitles: const AxisTitles(),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 52,
                          getTitlesWidget: (value, meta) {
                            final style = moodStyles[value.toInt()];
                            return Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Column(
                                children: [
                                  MoodFace(style.key, size: 22),
                                  const SizedBox(height: 2),
                                  Text(style.label, style: TextStyle(fontSize: 10, color: p.muted)),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    barGroups: [
                      for (var i = 0; i < moodStyles.length; i++)
                        BarChartGroupData(
                          x: i,
                          barsSpace: 4,
                          barRods: [
                            for (final m in members)
                              BarChartRodData(
                                toY: count(m.id, moodStyles[i].key).toDouble(),
                                color: memberColor(context, me.couple, m.id),
                                width: 12,
                                borderRadius: BorderRadius.circular(6),
                              ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Private check-ins only count toward your own bars.',
          textAlign: TextAlign.center,
          style: TextStyle(color: p.muted, fontSize: 12),
        ),
      ],
    );
  }
}
