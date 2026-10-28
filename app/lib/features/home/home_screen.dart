import '../../core/pref_keys.dart';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/mascot/mascot.dart';
import '../../core/motion/motion.dart';
import '../../core/theme/palettes.dart';
import '../../core/widgets/bank_card.dart';
import '../../core/widgets/categories.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/member_avatar.dart';
import '../../core/widgets/mood_face.dart';
import '../../core/widgets/nest_ui.dart';
import '../../data/models.dart';
import '../../data/payday_schedule.dart';
import '../../data/providers.dart';
import '../bills/bills.dart';
import '../goals/transfer.dart';
import '../paydays/paydays.dart';
import '../settle/settle_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboard = ref.watch(dashboardProvider);

    return Scaffold(
      body: NestBackground(
        child: SafeArea(
          child: RefreshIndicator(
            onRefresh: () {
              ref.invalidate(goalsProvider);
              ref.invalidate(plansProvider);
              ref.invalidate(feedProvider);
              return ref.refresh(dashboardProvider.future);
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              children: [
                const _Header(),
                const SizedBox(height: 14),
                AnimatedSwitcher(
                  duration: Motion.medium,
                  child: switch (dashboard) {
                    AsyncData(:final value) => _DashboardBody(value),
                    AsyncError(:final error) => ErrorRetry(error: error, onRetry: () => ref.invalidate(dashboardProvider)),
                    _ => const SkeletonList(cards: 2, padding: EdgeInsets.zero),
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends ConsumerWidget {
  const _Header();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(meProvider);
    final unseen = ref.watch(hasUnseenFeedProvider) || ref.watch(hasDueRemindersProvider);
    final budget = ref.watch(dashboardProvider).value?.budget;
    final budgetTight = budget != null && budget.total > 0 && budget.ratio >= 0.9;
    final p = context.pn;
    final text = Theme.of(context).textTheme;
    // Smaller perch on narrow phones so the names stay readable.
    final birds = MediaQuery.sizeOf(context).width < 380 ? 84.0 : 112.0;

    return SizedBox(
      height: 112,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const CoupleBadge(size: 56),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(greeting(), style: TextStyle(color: p.muted, fontSize: 13)),
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        me.coupleNames,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.headlineSmall?.copyWith(fontSize: 24),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(Icons.favorite_border_rounded, color: p.accent, size: 18),
                  ],
                ),
                Text('Better money. Happier together.', maxLines: 2, style: TextStyle(color: p.muted, fontSize: 12)),
              ],
            ),
          ),
          SizedBox(
            width: birds,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  right: -8,
                  bottom: 0,
                  child: MascotPair(
                    width: birds + 8,
                    branch: true,
                    animate: true,
                    controller: ref.watch(mascotControllerProvider),
                    // Near or over budget: a calm, thoughtful look.
                    mood: budgetTight ? MascotMood.thoughtful : MascotMood.idle,
                  ),
                ),
                Positioned(
                  top: -4,
                  right: -8,
                  child: IconButton(
                    tooltip: 'Notifications',
                    onPressed: () => _openFeed(context, ref),
                    icon: Badge(
                      isLabelVisible: unseen,
                      smallSize: 9,
                      backgroundColor: const Color(0xFFEF8A7A),
                      child: Icon(Icons.notifications_none_rounded, color: p.heading, size: 26),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _openFeed(BuildContext context, WidgetRef ref) {
    ref.read(feedSeenProvider.notifier).markSeen();
    showModalBottomSheet<void>(context: context, useRootNavigator: true, isScrollControlled: true, builder: (_) => const _FeedSheet());
  }
}

class _FeedSheet extends ConsumerWidget {
  const _FeedSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feed = ref.watch(feedProvider);
    final due = ref.watch(dueBillsProvider);
    final hide = ref.watch(hideAmountsProvider);
    final couple = ref.watch(meProvider).couple;
    final p = context.pn;
    final subheading = TextStyle(color: p.muted, fontSize: 12.5, fontWeight: FontWeight.w700, letterSpacing: 0.3);

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.7),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
            child: Text('Notifications', style: Theme.of(context).textTheme.titleLarge),
          ),
          if (due.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 4, 24, 0),
              child: Text('REMINDERS', style: subheading),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(children: [for (final b in due) _ReminderRow(b, hide: hide)]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 10, 24, 0),
              child: Text('FROM YOUR PARTNER', style: subheading),
            ),
          ],
          Flexible(
            child: switch (feed) {
              AsyncData(:final value) when value.isEmpty => Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  due.isNotEmpty ? 'Nothing new from your partner.' : 'Nothing new yet. Invite your partner from the Us tab!',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: p.muted),
                ),
              ),
              AsyncData(:final value) => ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                itemCount: value.length,
                separatorBuilder: (_, _) => const SizedBox(height: 4),
                itemBuilder: (context, i) {
                  final item = value[i];
                  final member = couple?.members.where((m) => m.name == item.userName).firstOrNull;
                  return FadeSlideIn(
                    index: i,
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                      leading: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          MemberAvatar(userId: member?.id ?? -1, name: item.userName, size: 40),
                          Positioned(right: -4, bottom: -4, child: _FeedTypeBadge(item.type)),
                        ],
                      ),
                      title: Text(item.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                      subtitle: Text(
                        [if (item.subtitle != null) item.subtitle!, relativeTime(item.at)].join(' · '),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: p.muted, fontSize: 12),
                      ),
                      trailing: item.amount == null
                          ? null
                          : Text(
                              peso(item.amount!),
                              style: TextStyle(fontWeight: FontWeight.w700, color: p.heading),
                            ),
                    ),
                  );
                },
              ),
              AsyncError(:final error) => ErrorRetry(error: error, onRetry: () => ref.invalidate(feedProvider)),
              _ => const SkeletonList(hero: false, cards: 1, padding: EdgeInsets.symmetric(vertical: 8)),
            },
          ),
        ],
      ),
    );
  }
}

/// In a month's first week: "Your September recap is ready", until dismissed.
class _RecapNudge extends ConsumerStatefulWidget {
  const _RecapNudge();

  @override
  ConsumerState<_RecapNudge> createState() => _RecapNudgeState();
}

class _RecapNudgeState extends ConsumerState<_RecapNudge> {
  bool _dismissed = false;

  @override
  Widget build(BuildContext context) {
    final now = ref.watch(nowProvider)();
    final last = DateTime(now.year, now.month - 1);
    final key = PrefKeys.recapSeen(monthKey(last));
    final prefs = ref.watch(prefsProvider);
    if (now.day > 7 || _dismissed || (prefs.getBool(key) ?? false)) return const SizedBox.shrink();
    final p = context.pn;
    final tone = Pastel.lavender;
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Material(
        color: tone.background(p),
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => context.go('/home/recap?month=${monthKey(last)}'),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
            child: Row(
              children: [
                Icon(Icons.auto_awesome_outlined, size: 20, color: tone.foreground(p)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Your ${monthLabel(last).split(' ').first} recap is ready',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: tone.foreground(p)),
                  ),
                ),
                Icon(Icons.chevron_right_rounded, size: 18, color: tone.foreground(p)),
                IconButton(
                  tooltip: 'Dismiss recap',
                  visualDensity: VisualDensity.compact,
                  icon: Icon(Icons.close_rounded, size: 18, color: tone.foreground(p)),
                  onPressed: () {
                    prefs.setBool(key, true);
                    setState(() => _dismissed = true);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Bills that are overdue, due today or due tomorrow, right under the
/// balance; takes no space when nothing is due.
class _BillReminders extends ConsumerWidget {
  const _BillReminders();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final due = ref.watch(dueBillsProvider);
    if (due.isEmpty) return const SizedBox.shrink();
    final p = context.pn;
    final hide = ref.watch(hideAmountsProvider);
    final error = Theme.of(context).colorScheme.error;
    final overdue = due.any((b) => b.isOverdue());
    final tone = overdue ? error : Pastel.sky.foreground(p);

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: FadeSlideIn(
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 8, 8, 4),
          decoration: BoxDecoration(
            color: overdue ? Color.lerp(p.surface, error, 0.07) : Pastel.sky.background(p),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: tone.withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (due.length > 1)
                Row(
                  children: [
                    Icon(Icons.notifications_active_rounded, size: 18, color: tone),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '${due.length} bills need attention',
                        style: TextStyle(fontWeight: FontWeight.w700, color: tone),
                      ),
                    ),
                    TextButton(onPressed: () => context.go('/home/budgets'), child: const Text('See all')),
                  ],
                ),
              for (final b in due.take(3)) _ReminderRow(b, hide: hide),
            ],
          ),
        ),
      ),
    );
  }
}

/// The couple's wallets as small brand cards; a gentle prompt when there are none.
class _WalletsRow extends StatelessWidget {
  const _WalletsRow(this.wallets);

  final List<Wallet> wallets;

  @override
  Widget build(BuildContext context) {
    final p = context.pn;
    if (wallets.isEmpty) {
      return Material(
        color: p.surface,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => context.go('/home/wallets'),
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: p.border),
            ),
            child: Row(
              children: [
                PastelIcon(Icons.account_balance_wallet_outlined, tone: Pastel.sky, size: 36),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Add your wallets',
                        style: TextStyle(fontWeight: FontWeight.w700, color: p.heading),
                      ),
                      Text('GCash, Maya, bank cards…', style: TextStyle(color: p.muted, fontSize: 12.5)),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: p.muted),
              ],
            ),
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: Text('Wallets', style: Theme.of(context).textTheme.titleMedium)),
            TextButton(
              style: TextButton.styleFrom(visualDensity: VisualDensity.compact, foregroundColor: p.muted),
              onPressed: () => context.go('/home/wallets'),
              child: const Text('See all'),
            ),
          ],
        ),
        const SizedBox(height: 4),
        SizedBox(
          height: MiniWalletCard.size.height,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            itemCount: wallets.length + 1,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (_, i) => i < wallets.length
                ? MiniWalletCard(wallets[i], onTap: () => context.go('/home/wallets?id=${wallets[i].id}'))
                : Tooltip(
                    message: 'Add wallet',
                    child: InkWell(
                      onTap: () => context.go('/home/wallets'),
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        width: 64,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: p.border, width: 1.5),
                        ),
                        child: Icon(Icons.add_rounded, color: p.muted),
                      ),
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}

/// "Payday! Log your Salary" while one of my paydays is waiting to be logged.
class _PaydayReminder extends ConsumerWidget {
  const _PaydayReminder();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final due = ref.watch(duePaydaysProvider);
    if (due.isEmpty) return const SizedBox.shrink();
    final payday = due.first;
    final p = context.pn;
    final hide = ref.watch(hideAmountsProvider);
    final tone = Pastel.sky;
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: FadeSlideIn(
        child: Material(
          color: tone.background(p),
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => receivePayday(context, ref, payday),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 6, 6),
              child: Row(
                children: [
                  Icon(Icons.payments_rounded, size: 20, color: tone.foreground(p)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Payday! Log your ${payday.title}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: tone.foreground(p)),
                        ),
                        Text(
                          hide
                              ? '₱•••• · ${payday.whenLabel(ref.watch(nowProvider)())}'
                              : '${peso(payday.amount)} · ${payday.whenLabel(ref.watch(nowProvider)())}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12, color: tone.foreground(p)),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    style: TextButton.styleFrom(visualDensity: VisualDensity.compact, foregroundColor: tone.foreground(p)),
                    onPressed: () => receivePayday(context, ref, payday),
                    child: const Text('Log it'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A due bill with a "Mark paid" button.
class _ReminderRow extends ConsumerWidget {
  const _ReminderRow(this.bill, {required this.hide});

  final Bill bill;
  final bool hide;

  @override
  Widget build(BuildContext context, WidgetRef ref) => BillRow(
    bill,
    compact: true,
    hideAmount: hide,
    onTap: () => payBill(context, ref, bill),
    trailing: TextButton(
      style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
      onPressed: () => payBill(context, ref, bill),
      child: const Text('Mark paid'),
    ),
  );
}

/// "Sam owes you ₱415 · Settle up" under the balance, only while someone owes.
class _SettleNudge extends ConsumerWidget {
  const _SettleNudge({required this.hide});

  final bool hide;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final owes = ref.watch(balanceProvider).value?.owes;
    if (owes == null) return const SizedBox.shrink();
    final p = context.pn;
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Material(
        color: Pastel.peach.background(p),
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => context.go('/home/settle'),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
            child: Row(
              children: [
                Icon(Icons.handshake_outlined, size: 20, color: Pastel.peach.foreground(p)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    owesLabel(owes, ref.watch(meProvider).user.id, hideAmount: hide),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Pastel.peach.foreground(p)),
                  ),
                ),
                Text(
                  'Settle up',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Pastel.peach.foreground(p)),
                ),
                Icon(Icons.chevron_right_rounded, size: 18, color: Pastel.peach.foreground(p)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FeedTypeBadge extends StatelessWidget {
  const _FeedTypeBadge(this.type);

  final String type;

  @override
  Widget build(BuildContext context) {
    final (icon, tone) = switch (type) {
      'expense' => (Icons.receipt_long_rounded, Pastel.sage),
      'income' => (Icons.savings_rounded, Pastel.sky),
      'goal' => (Icons.track_changes_rounded, Pastel.lavender),
      'mood' => (Icons.favorite_rounded, Pastel.peach),
      'settle' => (Icons.handshake_rounded, Pastel.peach),
      'topup' => (Icons.account_balance_wallet_rounded, Pastel.sky),
      'device' => (Icons.phonelink_lock_rounded, Pastel.peach),
      _ => (Icons.chat_bubble_rounded, Pastel.lavender),
    };
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: context.pn.background, width: 2),
      ),
      child: PastelIcon(icon, tone: tone, size: 20),
    );
  }
}

class _DashboardBody extends ConsumerWidget {
  const _DashboardBody(this.data);

  final Dashboard data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hide = ref.watch(hideAmountsProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FadeSlideIn(child: _BalanceCard(data, hide: hide)),
        const _BillReminders(),
        const _PaydayReminder(),
        _SettleNudge(hide: hide),
        const _RecapNudge(),
        const SizedBox(height: 14),
        FadeSlideIn(
          index: 1,
          child: Row(
            children: [
              for (final (i, tile) in [
                ActionTile(
                  icon: Icons.account_balance_wallet_outlined,
                  label: 'Add Expense',
                  tone: Pastel.sage,
                  onTap: () => context.push('/add'),
                ),
                ActionTile(icon: Icons.swap_horiz_rounded, label: 'Transfer', tone: Pastel.sky, onTap: () => openTransfer(context, ref)),
                ActionTile(
                  icon: Icons.track_changes_rounded,
                  label: 'Set Goal',
                  tone: Pastel.lavender,
                  onTap: () => context.go('/goals?new=1'),
                ),
                ActionTile(icon: Icons.more_horiz_rounded, label: 'More', tone: Pastel.peach, onTap: () => _showMore(context)),
              ].indexed) ...[if (i > 0) const SizedBox(width: 10), Expanded(child: tile)],
            ],
          ),
        ),
        const SizedBox(height: 14),
        FadeSlideIn(
          index: 2,
          child: SectionCard(
            icon: Icons.bar_chart_rounded,
            title: "This Month's Spending",
            onAction: () => context.go('/activity'),
            child: SpendingDonut(spending: data.spending, hideAmounts: hide),
          ),
        ),
        const SizedBox(height: 14),
        // Money plans side by side, then the two of you.
        FadeSlideIn(
          index: 3,
          child: _TwoUp(
            left: const _GoalsPeek(),
            right: _UpcomingCard(data.upcomingBills, hide: hide),
          ),
        ),
        const SizedBox(height: 14),
        FadeSlideIn(
          index: 4,
          child: _TwoUp(left: const _FeelsCard(), right: const QuoteCard(), leftFlex: 3, rightFlex: 2),
        ),
        const SizedBox(height: 14),
        FadeSlideIn(index: 5, child: _WalletsRow(data.wallets)),
      ],
    );
  }

  void _showMore(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (icon, label, route, tone) in const [
              (Icons.chat_bubble_outline_rounded, 'Money Talks', '/us/talks', Pastel.lavender),
              (Icons.event_rounded, 'Date & Life Planner', '/us/planner', Pastel.peach),
              (Icons.pie_chart_outline_rounded, 'Budgets, Bills & Paydays', '/home/budgets', Pastel.sage),
              (Icons.handshake_outlined, 'Settle Up', '/home/settle', Pastel.peach),
              (Icons.account_balance_wallet_outlined, 'Wallets', '/home/wallets', Pastel.sky),
              (Icons.auto_awesome_outlined, 'Monthly recap', '/home/recap', Pastel.lavender),
              (Icons.palette_outlined, 'Personalize', '/us/personalize', Pastel.sky),
            ])
              ListTile(
                leading: PastelIcon(icon, tone: tone, size: 40),
                title: Text(label),
                onTap: () {
                  Navigator.pop(sheet);
                  context.go(route);
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

/// Two cards side by side, stacked on narrow phones.
class _TwoUp extends StatelessWidget {
  const _TwoUp({required this.left, required this.right, this.leftFlex = 1, this.rightFlex = 1});

  final Widget left;
  final Widget right;
  final int leftFlex;
  final int rightFlex;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) => c.maxWidth < 340
          ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [left, const SizedBox(height: 14), right])
          : _EqualHeightPair(leftFlex: leftFlex, rightFlex: rightFlex, gap: 12, children: [left, right]),
    );
  }
}

/// Two cards side by side, both as tall as the taller one. IntrinsicHeight
/// can't do this here: SectionCard's header uses a LayoutBuilder.
class _EqualHeightPair extends MultiChildRenderObjectWidget {
  const _EqualHeightPair({required this.leftFlex, required this.rightFlex, required this.gap, required super.children});

  final int leftFlex;
  final int rightFlex;
  final double gap;

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderEqualHeightPair(leftFlex, rightFlex, gap);

  @override
  void updateRenderObject(BuildContext context, _RenderEqualHeightPair renderObject) {
    renderObject
      ..leftFlex = leftFlex
      ..rightFlex = rightFlex
      ..gap = gap;
  }
}

class _PairParentData extends ContainerBoxParentData<RenderBox> {}

class _RenderEqualHeightPair extends RenderBox
    with ContainerRenderObjectMixin<RenderBox, _PairParentData>, RenderBoxContainerDefaultsMixin<RenderBox, _PairParentData> {
  _RenderEqualHeightPair(this._leftFlex, this._rightFlex, this._gap);

  int _leftFlex;
  set leftFlex(int v) {
    if (v != _leftFlex) {
      _leftFlex = v;
      markNeedsLayout();
    }
  }

  int _rightFlex;
  set rightFlex(int v) {
    if (v != _rightFlex) {
      _rightFlex = v;
      markNeedsLayout();
    }
  }

  double _gap;
  set gap(double v) {
    if (v != _gap) {
      _gap = v;
      markNeedsLayout();
    }
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _PairParentData) child.parentData = _PairParentData();
  }

  @override
  void performLayout() {
    final left = firstChild!, right = childAfter(left)!;
    final width = constraints.maxWidth;
    final leftWidth = (width - _gap) * _leftFlex / (_leftFlex + _rightFlex);
    final rightWidth = width - _gap - leftWidth;
    // Natural heights first, then both again at the taller one.
    left.layout(BoxConstraints.tightFor(width: leftWidth), parentUsesSize: true);
    right.layout(BoxConstraints.tightFor(width: rightWidth), parentUsesSize: true);
    final height = left.size.height > right.size.height ? left.size.height : right.size.height;
    // A minimum rather than a fixed height keeps them linked to this pair, so a
    // card that grows later (data arriving) lays the pair out again.
    left.layout(BoxConstraints(minWidth: leftWidth, maxWidth: leftWidth, minHeight: height), parentUsesSize: true);
    right.layout(BoxConstraints(minWidth: rightWidth, maxWidth: rightWidth, minHeight: height), parentUsesSize: true);
    final tallest = left.size.height > right.size.height ? left.size.height : right.size.height;
    (left.parentData! as _PairParentData).offset = Offset.zero;
    (right.parentData! as _PairParentData).offset = Offset(leftWidth + _gap, 0);
    size = constraints.constrain(Size(width, tallest));
  }

  @override
  void paint(PaintingContext context, Offset offset) => defaultPaint(context, offset);

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) => defaultHitTestChildren(result, position: position);
}

class _BalanceCard extends ConsumerWidget {
  const _BalanceCard(this.data, {required this.hide});

  final Dashboard data;
  final bool hide;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final b = data.budget;
    final me = ref.watch(meProvider);
    final change = data.changeVsLastMonth;
    final big = Theme.of(context).textTheme.headlineMedium?.copyWith(color: Colors.white, fontSize: 30, height: 1.1);
    const soft = TextStyle(color: Color(0xDDFFFFFF), fontSize: 12.5);
    // What's actually in the shared wallets, beside what the plan says is left.
    final shared = [
      for (final w in data.wallets)
        if (w.isShared && w.balance != null) w.balance!,
    ];
    final pot = shared.isEmpty ? null : shared.fold(0.0, (a, v) => a + v);
    final noBudget = b.total <= 0;

    return WalletCard(
      // A little shorter than a real card, so Home shows more below it.
      cardRatio: 1.85,
      cardMinHeight: 204,
      dense: true,
      corner: pot == null || noBudget ? null : _SharedPot(pot, hide: hide, low: b.remaining > 0 && pot < b.remaining),
      holder: me.coupleNames.toUpperCase(),
      number: (me.couple?.id ?? 0).toString().padLeft(4, '0'),
      onTap: () => context.push('/home/budgets'),
      trailing: FittedBox(
        fit: BoxFit.scaleDown,
        child: HeroPill(icon: Icons.calendar_today_rounded, label: monthShort(b.month), onTap: () => context.push('/home/budgets')),
      ),
      strip: _WalletStats(data, hide: hide),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Text(
                noBudget && pot != null ? 'In shared wallets' : 'Left to spend',
                style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
              ),
              const SizedBox(width: 2),
              Tooltip(
                message: hide ? 'Show amounts' : 'Hide amounts',
                child: InkResponse(
                  onTap: ref.read(hideAmountsProvider.notifier).toggle,
                  radius: 18,
                  child: Padding(
                    padding: const EdgeInsets.all(2),
                    child: Icon(hide ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 17, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
          if (noBudget && pot != null) ...[
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: hide ? Text('₱ ••••••', style: big) : AnimatedAmount(pot, style: big),
            ),
            const SizedBox(height: 2),
            const Text('Set your shared budget ›', style: soft),
          ] else if (noBudget) ...[
            Text('Set your shared budget', style: big?.copyWith(fontSize: 22)),
          ] else ...[
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: hide
                  ? Text('₱ ••••••', style: big)
                  : AnimatedAmount(b.remaining.abs(), style: big, prefix: b.remaining < 0 ? '-' : ''),
            ),
            if (change != null) ...[
              Row(
                children: [
                  Icon(change > 0 ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded, size: 14, color: const Color(0xDDFFFFFF)),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      '${(change.abs() * 100).round()}% ${change > 0 ? 'more' : 'less'} spending vs. last month',
                      style: soft,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ],
      ),
    );
  }
}

/// "In shared wallets ₱6,000 ›" in the card's corner; nudges a top-up when
/// the shared wallets hold less than what's left to spend.
class _SharedPot extends StatelessWidget {
  const _SharedPot(this.amount, {required this.hide, required this.low});

  final double amount;
  final bool hide;
  final bool low;

  @override
  Widget build(BuildContext context) {
    final money = hide ? '₱••••' : (amount < 0 ? '-${peso(-amount)}' : peso(amount));
    // Its own node, so screen readers can reach it apart from the card.
    return Semantics(
      container: true,
      button: true,
      label: 'In shared wallets, $money${low ? ', top up?' : ''}',
      excludeSemantics: true,
      child: Material(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => context.go('/home/wallets?filter=ours'),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 3, 2, 3),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.favorite_rounded, size: 11, color: Color(0xDDFFFFFF)),
                const SizedBox(width: 4),
                const Text('Shared ', style: TextStyle(color: Color(0xDDFFFFFF), fontSize: 11)),
                Text(
                  money,
                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700),
                ),
                if (low) const Text(' · top up?', style: TextStyle(color: Color(0xDDFFFFFF), fontSize: 11)),
                const Icon(Icons.chevron_right_rounded, size: 16, color: Colors.white),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Budget progress, spent/left and this month's savings, tucked under the card.
class _WalletStats extends StatelessWidget {
  const _WalletStats(this.data, {required this.hide});

  final Dashboard data;
  final bool hide;

  @override
  Widget build(BuildContext context) {
    final p = context.pn;
    final b = data.budget;
    final over = b.remaining < 0;
    final label = TextStyle(color: p.muted, fontSize: 12.5);
    const value = TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5);
    String money(double v) => hide ? '₱••••' : peso(v);

    if (b.total <= 0) {
      return InkWell(
        onTap: () => context.push('/home/budgets'),
        borderRadius: BorderRadius.circular(12),
        child: Row(
          children: [
            Expanded(
              child: Text(
                'Plan this month together',
                style: TextStyle(fontWeight: FontWeight.w600, color: p.heading),
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: p.heading),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: Text('Budget used', style: label)),
            Text('${(b.ratio * 100).round()}%', style: value.copyWith(color: over ? Theme.of(context).colorScheme.error : p.heading)),
          ],
        ),
        const SizedBox(height: 8),
        SoftProgress(b.ratio.clamp(0.0, 1.0), color: over ? Theme.of(context).colorScheme.error : p.primary),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(text: money(b.spent), style: value),
                    TextSpan(text: ' spent', style: label),
                  ],
                ),
              ),
            ),
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: money(b.remaining.abs()), style: value),
                  TextSpan(text: over ? ' over' : ' remaining', style: label),
                ],
              ),
            ),
          ],
        ),
        _PaydayLine(remaining: b.remaining, hide: hide),
        if (data.savedThisMonth > 0) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(savingsCategory.icon, size: 16, color: savingsCategory.color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '${money(data.savedThisMonth)} saved toward goals this month',
                  style: TextStyle(fontSize: 12.5, color: p.text, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

/// "Payday in 3 days       ₱1,050 a day", under the budget figures. Hidden
/// while the Payday strip below is asking to log it.
class _PaydayLine extends ConsumerWidget {
  const _PaydayLine({required this.remaining, required this.hide});

  final double remaining;
  final bool hide;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final payday = ref.watch(nextPaydayProvider);
    if (payday == null || ref.watch(duePaydaysProvider).isNotEmpty) return const SizedBox.shrink();
    final p = context.pn;
    final now = ref.watch(nowProvider)();
    final daily = payday.daysUntil(now) == 0 ? null : dailyAllowance(remaining: remaining, today: now, payday: payday.nextOn);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Icon(Icons.payments_outlined, size: 16, color: Pastel.sky.foreground(p)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              payday.whenLabel(now),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12.5, color: p.text, fontWeight: FontWeight.w500),
            ),
          ),
          if (daily != null)
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: hide ? '₱••••' : peso(daily),
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: p.heading),
                  ),
                  TextSpan(
                    text: ' a day',
                    style: TextStyle(color: p.muted, fontSize: 12.5),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _GoalsPeek extends ConsumerWidget {
  const _GoalsPeek();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goals = ref.watch(activeGoalsProvider).value;
    final p = context.pn;
    final top = [...?goals]..sort((a, b) => b.ratio.compareTo(a.ratio));

    return SectionCard(
      icon: Icons.track_changes_rounded,
      title: 'Savings Goals',
      onAction: () => context.go('/goals'),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      child: goals == null
          ? const SizedBox(height: 80)
          : top.isEmpty
          ? TextButton(onPressed: () => context.go('/goals?new=1'), child: const Text('Start your first goal'))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SceneBanner(kind: top.first.icon, height: 58, radius: 14),
                for (final g in top.take(2)) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      PastelIcon(goalIcons[g.icon] ?? Icons.star_rounded, tone: Pastel.sage, size: 34),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              g.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                            ),
                            Text(
                              '${peso(g.saved)} / ${peso(g.target)}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 11, color: p.muted),
                            ),
                            const SizedBox(height: 4),
                            SoftProgress(g.ratio, height: 5),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
    );
  }
}

class _FeelsCard extends StatelessWidget {
  const _FeelsCard();

  @override
  Widget build(BuildContext context) {
    final p = context.pn;
    final lavender = Pastel.lavender;
    return SectionCard(
      icon: Icons.favorite_rounded,
      title: 'Pairnest Feels',
      action: 'View history',
      actionIcon: Icons.history_rounded,
      onAction: () => context.go('/feelings'),
      color: Color.lerp(p.surface, lavender.light, p.isDark ? 0.08 : 0.45),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('How are you feeling today?', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
          const SizedBox(height: 10),
          Row(
            children: [
              for (final mood in const ['happy', 'calm', 'stressed'])
                Expanded(
                  child: _MoodChoice(
                    label: moodStyle(mood).label,
                    onTap: () => context.push('/feelings/check-in?mood=$mood'),
                    child: MoodFace(mood, size: 32),
                  ),
                ),
              Expanded(
                child: _MoodChoice(
                  label: 'Talk',
                  onTap: () => context.go('/us/talks'),
                  child: PastelIcon(Icons.chat_bubble_outline_rounded, tone: lavender, size: 32),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MoodChoice extends StatelessWidget {
  const _MoodChoice({required this.label, required this.onTap, required this.child});

  final String label;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return PressScale(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(2),
          child: Column(
            children: [
              child,
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(label, style: const TextStyle(fontSize: 10)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UpcomingCard extends ConsumerWidget {
  const _UpcomingCard(this.bills, {required this.hide});

  final List<Bill> bills;
  final bool hide;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plans = ref.watch(plansProvider).value;
    final p = context.pn;
    final now = DateTime.now();
    final nextPlan = plans?.where((pl) => pl.scheduledAt != null && pl.scheduledAt!.isAfter(now)).firstOrNull;

    // Soonest first: due bills by date, then the next plan in its place.
    final items = <(DateTime, Widget)>[
      for (final b in bills) (b.nextDueOn, BillRow(b, compact: true, hideAmount: hide, onTap: () => payBill(context, ref, b))),
      if (nextPlan != null) (nextPlan.scheduledAt!, _PlanRow(nextPlan)),
    ]..sort((a, b) => a.$1.compareTo(b.$1));
    final shown = items.take(2).map((e) => e.$2).toList();

    return SectionCard(
      icon: Icons.calendar_month_rounded,
      title: 'Upcoming',
      action: bills.isEmpty ? 'Calendar' : 'Bills',
      onAction: () => context.go(bills.isEmpty ? '/us/planner' : '/home/budgets'),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      child: shown.isEmpty
          ? Text('Nothing coming up. Plan a date or add a bill!', style: TextStyle(color: p.muted, fontSize: 12))
          : Column(
              children: [
                for (final (i, row) in shown.indexed) ...[if (i > 0) Divider(height: 10, color: p.border), row],
              ],
            ),
    );
  }
}

class _PlanRow extends StatelessWidget {
  const _PlanRow(this.plan);

  final Plan plan;

  @override
  Widget build(BuildContext context) {
    final p = context.pn;
    return InkWell(
      onTap: () => context.go('/us/planner'),
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            SizedBox(width: 56, child: SceneBanner(kind: plan.isDate ? 'date' : (plan.goal?.icon ?? 'star'), height: 46, radius: 12)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(plan.isDate ? Icons.favorite_rounded : Icons.flag_rounded, size: 13, color: p.heading),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          plan.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(longDate(plan.scheduledAt!), style: TextStyle(color: p.muted, fontSize: 11.5)),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: Pastel.sage.background(p), borderRadius: BorderRadius.circular(20)),
                    child: Text(
                      timeLabel(plan.scheduledAt!),
                      style: TextStyle(fontSize: 10.5, color: Pastel.sage.foreground(p), fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
