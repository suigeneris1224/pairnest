import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/motion/motion.dart';
import '../../core/format.dart';
import '../../core/theme/palettes.dart';
import '../../core/widgets/categories.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/member_colors.dart';
import '../../core/widgets/nest_ui.dart';
import '../../data/models.dart';
import '../../data/providers.dart';
import 'transfer.dart';

class GoalsScreen extends ConsumerStatefulWidget {
  const GoalsScreen({super.key, this.openNew = false});

  /// Open the new-goal sheet on arrival (Home's "Set Goal" tile).
  final bool openNew;

  @override
  ConsumerState<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends ConsumerState<GoalsScreen> {
  @override
  void initState() {
    super.initState();
    if (widget.openNew) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        GoRouter.of(context).go('/goals');
        _openSheet(const _GoalEditor());
      });
    }
  }

  Future<void> _openSheet(Widget sheet) async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      builder: (_) => sheet,
    );
    if (changed == true) {
      ref.invalidate(goalsProvider);
      ref.invalidate(plansProvider);
    }
  }

  /// Cancels after a check; the savings are released and Undo restores it.
  Future<void> _cancel(Goal goal) async {
    final ok = await confirmDialog(
      context,
      title: 'Cancel ${goal.name}?',
      message: goal.saved > 0
          ? 'The ${peso(goal.saved)} you saved will be released back to you. You can restore this goal anytime.'
          : 'It will move to Cancelled goals. You can restore it anytime.',
      keepLabel: 'Keep goal',
      confirmLabel: 'Cancel goal',
    );
    if (!ok || !mounted) return;
    final repo = ref.read(repositoryProvider);
    final messenger = ScaffoldMessenger.of(context);
    final container = ProviderScope.containerOf(context, listen: false);
    try {
      await repo.cancelGoal(goal.id);
      invalidateMoney(ref);
      showSnackOn(
        messenger,
        '${goal.name} cancelled',
        actionLabel: 'Undo',
        onAction: () => repo
            .restoreGoal(goal.id)
            .then((_) => invalidateMoneyIn(container), onError: (Object e) => showSnackOn(messenger, friendlyError(e))),
      );
    } catch (e) {
      showSnackOn(messenger, friendlyError(e));
    }
  }

  Future<void> _restore(Goal goal) async {
    try {
      await ref.read(repositoryProvider).restoreGoal(goal.id);
      invalidateMoney(ref);
      if (mounted) showSnack(context, '${goal.name} is back');
    } catch (e) {
      if (mounted) showSnack(context, friendlyError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final goals = ref.watch(goalsProvider);
    final all = goals.value ?? const <Goal>[];
    final active = [
      for (final g in all)
        if (!g.cancelled) g,
    ];
    final cancelled = [
      for (final g in all)
        if (g.cancelled) g,
    ];

    return Scaffold(
      body: NestBackground(
        child: SafeArea(
          child: Column(
            children: [
              PageHeader(
                'Our Goals',
                showBack: false,
                trailing: IconButton(
                  tooltip: 'New goal',
                  icon: const Icon(Icons.add_rounded),
                  onPressed: () => _openSheet(const _GoalEditor()),
                ),
              ),
              Expanded(
                child: switch (goals) {
                  AsyncData(:final value) =>
                    value.isEmpty
                        ? RefreshIndicator(
                            onRefresh: () => ref.refresh(goalsProvider.future),
                            child: EmptyState(
                              title: 'Dream something together',
                              message: 'A trip, a home, a rainy-day fund. Start a goal and save for it side by side.',
                              actionLabel: 'Add a goal',
                              onAction: () => _openSheet(const _GoalEditor()),
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: () => ref.refresh(goalsProvider.future),
                            child: ListView(
                              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                              children: [
                                if (active.isNotEmpty) ...[
                                  FadeSlideIn(child: _SavedTogether(active)),
                                  const SizedBox(height: 16),
                                ] else
                                  PairnestCard(
                                    child: Text(
                                      'No goals in progress. Start a new one, or restore one below.',
                                      style: TextStyle(color: context.pn.muted, height: 1.4),
                                    ),
                                  ),
                                for (final (i, goal) in active.indexed) ...[
                                  FadeSlideIn(
                                    index: i + 1,
                                    child: _GoalCard(
                                      goal,
                                      onTap: () => openTransfer(context, ref, goal: goal),
                                      onEdit: () => _openSheet(_GoalEditor(existing: goal)),
                                      onCancel: () => _cancel(goal),
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                ],
                                if (cancelled.isNotEmpty) _CancelledGoals(cancelled, onRestore: _restore),
                              ],
                            ),
                          ),
                  AsyncError(:final error) => ErrorRetry(error: error, onRetry: () => ref.invalidate(goalsProvider)),
                  _ => const SkeletonList(cards: 2),
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Cancelled goals, folded away at the bottom with a Restore button each.
class _CancelledGoals extends StatefulWidget {
  const _CancelledGoals(this.goals, {required this.onRestore});

  final List<Goal> goals;
  final ValueChanged<Goal> onRestore;

  @override
  State<_CancelledGoals> createState() => _CancelledGoalsState();
}

class _CancelledGoalsState extends State<_CancelledGoals> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final p = context.pn;
    return PairnestCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _open = !_open),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                children: [
                  Icon(Icons.inventory_2_outlined, size: 20, color: p.muted),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text('Cancelled goals (${widget.goals.length})', style: const TextStyle(fontWeight: FontWeight.w600)),
                  ),
                  AnimatedRotation(
                    turns: _open ? 0.5 : 0,
                    duration: Motion.fast,
                    child: Icon(Icons.expand_more_rounded, color: p.muted),
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: Motion.medium,
            curve: Motion.curve,
            alignment: Alignment.topCenter,
            child: _open
                ? Column(
                    children: [
                      for (final g in widget.goals) ...[
                        Divider(height: 1, color: p.border),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            children: [
                              Opacity(opacity: 0.6, child: GoalArt(g.icon, size: 36)),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      g.name,
                                      style: TextStyle(fontWeight: FontWeight.w600, color: p.muted),
                                    ),
                                    Text(
                                      [
                                        if (g.saved > 0) '${peso(g.saved)} released',
                                        if (g.cancelledAt != null) shortDate(g.cancelledAt!),
                                      ].join(' · '),
                                      style: TextStyle(color: p.muted, fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                              TextButton(onPressed: () => widget.onRestore(g), child: const Text('Restore')),
                            ],
                          ),
                        ),
                      ],
                    ],
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}

/// Hero summary across all goals.
class _SavedTogether extends StatelessWidget {
  const _SavedTogether(this.goals);

  final List<Goal> goals;

  @override
  Widget build(BuildContext context) {
    final saved = goals.fold<double>(0, (a, g) => a + g.saved);
    final target = goals.fold<double>(0, (a, g) => a + g.target);
    final ratio = target <= 0 ? 0.0 : saved / target;
    const soft = TextStyle(color: Color(0xDDFFFFFF), fontSize: 13);
    return HeroCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Saved together',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ),
              HeroPill(label: '${goals.length} ${goals.length == 1 ? 'goal' : 'goals'}', trailing: null, icon: Icons.track_changes_rounded),
            ],
          ),
          const SizedBox(height: 6),
          AnimatedAmount(saved, style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: Colors.white, fontSize: 32)),
          const SizedBox(height: 14),
          HeroProgress(ratio),
          const SizedBox(height: 8),
          Text('${(ratio * 100).round()}% of ${peso(target)} across all goals', style: soft),
        ],
      ),
    );
  }
}

class GoalArt extends StatelessWidget {
  const GoalArt(this.icon, {super.key, this.size = 84});

  final String icon;
  final double size;

  @override
  Widget build(BuildContext context) {
    final tint = goalTints[icon] ?? goalTints['star']!;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.24),
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: tint),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -size * 0.12,
            bottom: -size * 0.12,
            child: Icon(goalIcons[icon] ?? Icons.star_rounded, size: size * 0.7, color: Colors.white.withValues(alpha: 0.25)),
          ),
          Center(
            child: Icon(goalIcons[icon] ?? Icons.star_rounded, size: size * 0.42, color: Colors.white),
          ),
        ],
      ),
    );
  }
}

class _GoalCard extends ConsumerWidget {
  const _GoalCard(this.goal, {required this.onTap, required this.onEdit, required this.onCancel});

  final Goal goal;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.pn;
    final couple = ref.watch(meProvider).couple;
    final contributors = [
      for (final m in couple?.members ?? const <Member>[])
        if (goal.contributorIds.contains(m.id)) m,
    ];

    return PairnestCard(
      onTap: onTap,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SceneBanner(kind: goal.icon, height: 84),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PastelIcon(goalIcons[goal.icon] ?? Icons.star_rounded, tone: _toneFor(goal.icon), size: 44),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(goal.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                        ),
                        PopupMenuButton<VoidCallback>(
                          tooltip: 'Options for ${goal.name}',
                          icon: Icon(Icons.more_horiz_rounded, color: p.muted),
                          padding: EdgeInsets.zero,
                          onSelected: (action) => action(),
                          itemBuilder: (_) => [
                            PopupMenuItem(
                              value: onEdit,
                              child: const ListTile(leading: Icon(Icons.edit_outlined), title: Text('Edit goal'), dense: true),
                            ),
                            PopupMenuItem(
                              value: onCancel,
                              child: const ListTile(leading: Icon(Icons.cancel_outlined), title: Text('Cancel goal'), dense: true),
                            ),
                          ],
                        ),
                      ],
                    ),
                    if (goal.subtitle.isNotEmpty) Text(goal.subtitle, style: TextStyle(color: p.muted, fontSize: 12)),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Flexible(
                          child: Text(
                            peso(goal.saved),
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: p.primaryDeep),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            ' / ${peso(goal.target)}',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: p.muted, fontSize: 12),
                          ),
                        ),
                        Text(
                          '${(goal.ratio * 100).round()}%',
                          style: TextStyle(color: p.muted, fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    SoftProgress(goal.ratio),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        if (goal.targetDate != null) ...[
                          Icon(Icons.flag_rounded, size: 14, color: p.muted),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              'Target ${monthLabel(goal.targetDate!)}',
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: p.muted, fontSize: 12),
                            ),
                          ),
                        ] else
                          const Spacer(),
                        if (contributors.isNotEmpty)
                          CoupleAvatars(
                            names: [for (final m in contributors) m.name],
                            userIds: [for (final m in contributors) m.id],
                            colors: [for (final m in contributors) memberColor(context, couple, m.id)],
                            size: 26,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

Pastel _toneFor(String icon) => switch (icon) {
  'travel' || 'business' => Pastel.sky,
  'home' || 'retire' => Pastel.peach,
  'ring' || 'baby' => Pastel.lavender,
  _ => Pastel.sage,
};

class _GoalEditor extends ConsumerStatefulWidget {
  const _GoalEditor({this.existing});

  /// Edit this goal instead of creating one (e.g. a starter goal's target).
  final Goal? existing;

  @override
  ConsumerState<_GoalEditor> createState() => _GoalEditorState();
}

class _GoalEditorState extends ConsumerState<_GoalEditor> {
  late final Goal? _existing = widget.existing;
  late final _name = TextEditingController(text: _existing?.name ?? '');
  late final _subtitle = TextEditingController(text: _existing?.subtitle ?? '');
  late final _target = TextEditingController(text: _existing == null ? '' : _existing.target.toStringAsFixed(0));
  late String _icon = _existing?.icon ?? 'travel';
  late DateTime? _date = _existing?.targetDate;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _subtitle.dispose();
    _target.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final target = double.tryParse(_target.text.replaceAll(',', '')) ?? 0;
    if (_name.text.trim().isEmpty || target <= 0) {
      showSnack(context, 'Give your goal a name and a target amount.');
      return;
    }
    setState(() => _busy = true);
    try {
      final repo = ref.read(repositoryProvider);
      final existing = _existing;
      if (existing == null) {
        await repo.addGoal(name: _name.text.trim(), subtitle: _subtitle.text.trim(), icon: _icon, target: target, targetDate: _date);
      } else {
        await repo.updateGoal(
          existing.id,
          name: _name.text.trim(),
          subtitle: _subtitle.text.trim(),
          icon: _icon,
          target: target,
          targetDate: _date,
        );
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        showSnack(context, friendlyError(e));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pn;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(_existing == null ? 'New goal' : 'Edit goal', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            SizedBox(
              height: 60,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (final icon in goalIcons.keys)
                    Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: GestureDetector(
                        onTap: () => setState(() => _icon = icon),
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: icon == _icon ? p.primaryDeep : Colors.transparent, width: 2),
                          ),
                          child: GoalArt(icon, size: 50),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Goal name', hintText: 'e.g. Japan Trip'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _subtitle,
              decoration: const InputDecoration(labelText: 'Description (optional)', hintText: 'e.g. Travel & Experience'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _target,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
              decoration: const InputDecoration(labelText: 'Target amount', prefixText: '₱ '),
            ),
            const SizedBox(height: 12),
            InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () async {
                final now = DateTime.now();
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _date ?? DateTime(now.year + 1, now.month),
                  firstDate: now,
                  lastDate: DateTime(now.year + 30),
                );
                if (picked != null) setState(() => _date = picked);
              },
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Target date (optional)',
                  suffixIcon: Icon(Icons.calendar_today_rounded, size: 18),
                ),
                child: Text(_date == null ? 'No date' : longDate(_date!)),
              ),
            ),
            const SizedBox(height: 20),
            FilledButton(onPressed: _busy ? null : _save, child: Text(_existing == null ? 'Create goal' : 'Save changes')),
          ],
        ),
      ),
    );
  }
}
