import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets/nest_ui.dart';
import '../../core/motion/motion.dart';
import '../../core/format.dart';
import '../../core/mascot/mascot_controller.dart';
import '../../core/theme/palettes.dart';
import '../../core/widgets/common.dart';
import '../../data/models.dart';
import '../../data/providers.dart';
import 'txn_tile.dart';

/// Transaction history with month switcher and search.
class ActivityScreen extends ConsumerStatefulWidget {
  const ActivityScreen({super.key});

  @override
  ConsumerState<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends ConsumerState<ActivityScreen> {
  DateTime _month = monthStart(DateTime.now());
  String _query = '';
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _search(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () => setState(() => _query = value));
  }

  /// Deletes right away and offers Undo, which adds the transaction back.
  Future<void> _delete(Txn txn) async {
    final repo = ref.read(repositoryProvider);
    try {
      await repo.deleteTransaction(txn.id);
    } catch (e) {
      if (mounted) showSnack(context, friendlyError(e));
      return;
    } finally {
      invalidateMoney(ref);
    }
    if (!mounted) return;
    showSnack(
      context,
      '"${txn.title}" deleted',
      actionLabel: 'Undo',
      onAction: () async {
        try {
          // A transfer comes back by moving the money into its goal again.
          if (txn.isTransfer && txn.goalId != null) {
            await repo.contribute(txn.goalId!, txn.amount);
          } else {
            await repo.addTransaction(TxnDraft.fromTxn(txn));
          }
          if (mounted) invalidateMoney(ref);
        } catch (e) {
          if (mounted) showSnack(context, friendlyError(e));
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pn;
    final txns = ref.watch(transactionsProvider((_month, _query)));

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/add'),
        backgroundColor: p.primaryDeep,
        foregroundColor: p.onPrimary,
        shape: const CircleBorder(),
        tooltip: 'Add transaction',
        child: const Icon(Icons.add_rounded),
      ),
      body: NestBackground(
        child: SafeArea(
          child: Column(
            children: [
              const PageHeader('Activity', showBack: false),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          tooltip: 'Previous month',
                          icon: const Icon(Icons.chevron_left_rounded),
                          onPressed: () => setState(() => _month = DateTime(_month.year, _month.month - 1)),
                        ),
                        Text(monthLabel(_month), style: const TextStyle(fontWeight: FontWeight.w700)),
                        IconButton(
                          tooltip: 'Next month',
                          icon: const Icon(Icons.chevron_right_rounded),
                          onPressed: () => setState(() => _month = DateTime(_month.year, _month.month + 1)),
                        ),
                      ],
                    ),
                    TextField(
                      onChanged: _search,
                      decoration: InputDecoration(
                        hintText: 'Search transactions',
                        prefixIcon: Icon(Icons.search_rounded, color: p.muted),
                        isDense: true,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: switch (txns) {
                  AsyncData(:final value) => RefreshIndicator(
                    onRefresh: () {
                      invalidateMoney(ref);
                      return ref.refresh(transactionsProvider((_month, _query)).future);
                    },
                    child: value.isEmpty
                        ? EmptyState(
                            title: _query.isEmpty ? 'No transactions this month' : 'No matches',
                            message: _query.isEmpty
                                ? 'Log what you spend and earn, and you will both see it here.'
                                : 'Nothing in ${monthLabel(_month)} matches "$_query".',
                            actionLabel: _query.isEmpty ? 'Add expense' : null,
                            onAction: _query.isEmpty ? () => context.push('/add') : null,
                            mood: _query.isEmpty ? MascotMood.curious : MascotMood.idle,
                          )
                        : _GroupedList(
                            value,
                            // Transfers aren't editable; their goal is where they live.
                            onEdit: (t) => t.isTransfer || t.isRelease ? context.go('/goals') : context.push('/add', extra: t),
                            onDelete: _delete,
                          ),
                  ),
                  AsyncError(:final error) => ErrorRetry(error: error, onRetry: () => ref.invalidate(transactionsProvider)),
                  _ => const SkeletonList(),
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GroupedList extends StatelessWidget {
  const _GroupedList(this.txns, {required this.onEdit, required this.onDelete});

  final List<Txn> txns;
  final ValueChanged<Txn> onEdit;
  final ValueChanged<Txn> onDelete;

  @override
  Widget build(BuildContext context) {
    final p = context.pn;
    final income = txns.where((t) => t.isIncome).fold<double>(0, (a, t) => a + t.amount);
    final expense = txns.where((t) => t.isExpense).fold<double>(0, (a, t) => a + t.amount);
    final byDay = <String, List<Txn>>{};
    for (final t in txns) {
      byDay.putIfAbsent(longDate(t.occurredOn), () => []).add(t);
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 96),
      children: [
        FadeSlideIn(
          child: HeroCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: _HeroFigure('Money in', income, Icons.south_west_rounded)),
                    Expanded(child: _HeroFigure('Money out', expense, Icons.north_east_rounded)),
                  ],
                ),
                const SizedBox(height: 14),
                HeroProgress(income <= 0 ? (expense > 0 ? 1 : 0) : expense / income),
                const SizedBox(height: 8),
                Text(
                  income >= expense ? '${peso(income - expense)} left over this month' : '${peso(expense - income)} more out than in',
                  style: const TextStyle(color: Color(0xDDFFFFFF), fontSize: 12.5),
                ),
              ],
            ),
          ),
        ),
        for (final (i, entry) in byDay.entries.indexed) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 18, 0, 6),
            child: Text(
              entry.key,
              style: TextStyle(color: p.muted, fontWeight: FontWeight.w600, fontSize: 12),
            ),
          ),
          FadeSlideIn(
            index: i,
            child: PairnestCard(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Column(
                children: [
                  for (final t in entry.value)
                    Dismissible(
                      key: ValueKey('txn-${t.id}'),
                      // A release is undone by restoring its goal, not by deleting it.
                      direction: t.isRelease ? DismissDirection.none : DismissDirection.endToStart,
                      background: const _DeleteBackground(),
                      onDismissed: (_) => onDelete(t),
                      child: TxnTile(t, onTap: () => onEdit(t)),
                    ),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 12),
        Text(
          'Tap to edit · swipe left to delete',
          textAlign: TextAlign.center,
          style: TextStyle(color: p.muted, fontSize: 12),
        ),
      ],
    );
  }
}

class _DeleteBackground extends StatelessWidget {
  const _DeleteBackground();

  @override
  Widget build(BuildContext context) {
    final error = Theme.of(context).colorScheme.error;
    return Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: 12),
      color: error.withValues(alpha: 0.12),
      child: Icon(Icons.delete_outline_rounded, color: error, semanticLabel: 'Delete'),
    );
  }
}

class _HeroFigure extends StatelessWidget {
  const _HeroFigure(this.label, this.value, this.icon);

  final String label;
  final double value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: const Color(0xDDFFFFFF)),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(color: Color(0xDDFFFFFF), fontSize: 12.5)),
          ],
        ),
        const SizedBox(height: 4),
        AnimatedAmount(
          value,
          style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800),
        ),
      ],
    );
  }
}
