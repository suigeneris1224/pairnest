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
import '../../core/widgets/categories.dart';
import '../../core/widgets/wallet_brands.dart';
import '../../core/widgets/bank_card.dart';
import '../../data/providers.dart';
import 'txn_filter.dart';
import 'txn_tile.dart';

/// Transaction history with month switcher and search.
class ActivityScreen extends ConsumerStatefulWidget {
  const ActivityScreen({super.key, this.walletId});

  /// Opens filtered to this wallet, e.g. from its card's "See all".
  final int? walletId;

  @override
  ConsumerState<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends ConsumerState<ActivityScreen> {
  DateTime _month = monthStart(DateTime.now());

  /// A custom period instead of [_month].
  DateTimeRange? _range;
  String _query = '';
  late TxnFilter _filter = widget.walletId == null ? TxnFilter.none : TxnFilter(wallets: {widget.walletId!});
  Timer? _debounce;

  @override
  void didUpdateWidget(ActivityScreen old) {
    super.didUpdateWidget(old);
    // The tab stays alive, so a new ?wallet= arrives here rather than in a new state.
    if (widget.walletId != null && widget.walletId != old.walletId) {
      _filter = TxnFilter(wallets: {widget.walletId!});
    }
  }

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

  FutureProvider<List<Txn>> get _source {
    final range = _range;
    return range == null ? transactionsProvider((_month, _query)) : transactionsRangeProvider((range.start, range.end, _query));
  }

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 1, 12, 31),
      initialDateRange: _range ?? DateTimeRange(start: _month, end: DateTime(_month.year, _month.month + 1, 0)),
    );
    if (picked == null) return;
    if (picked.end.difference(picked.start).inDays > 366) {
      if (mounted) showSnack(context, 'Pick a range of a year or less.');
      return;
    }
    setState(() => _range = picked);
  }

  Future<void> _openFilters(List<Txn> base) async {
    final picked = await showModalBottomSheet<TxnFilter>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      builder: (_) => _FilterSheet(initial: _filter, base: base),
    );
    if (picked != null) setState(() => _filter = picked);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pn;
    final me = ref.watch(meProvider);
    final walletNames = {for (final w in ref.watch(walletsProvider).value ?? const <Wallet>[]) w.id: w.name};
    final txns = ref.watch(_source);
    final range = _range;

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
                      children: range == null
                          ? [
                              IconButton(
                                tooltip: 'Previous month',
                                icon: const Icon(Icons.chevron_left_rounded),
                                onPressed: () => setState(() => _month = DateTime(_month.year, _month.month - 1)),
                              ),
                              Flexible(
                                child: Text(
                                  monthLabel(_month),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontWeight: FontWeight.w700),
                                ),
                              ),
                              IconButton(
                                tooltip: 'Next month',
                                icon: const Icon(Icons.chevron_right_rounded),
                                onPressed: () => setState(() => _month = DateTime(_month.year, _month.month + 1)),
                              ),
                              IconButton(
                                tooltip: 'Pick dates',
                                visualDensity: VisualDensity.compact,
                                icon: const Icon(Icons.date_range_rounded),
                                onPressed: _pickRange,
                              ),
                              IconButton(
                                tooltip: 'Monthly recap',
                                visualDensity: VisualDensity.compact,
                                icon: const Icon(Icons.auto_awesome_outlined),
                                onPressed: () => context.go('/home/recap?month=${monthKey(_month)}'),
                              ),
                            ]
                          : [
                              IconButton(tooltip: 'Pick dates', icon: const Icon(Icons.date_range_rounded), onPressed: _pickRange),
                              Text(_rangeLabel(range), style: const TextStyle(fontWeight: FontWeight.w700)),
                              IconButton(
                                tooltip: 'Back to months',
                                icon: const Icon(Icons.close_rounded),
                                onPressed: () => setState(() => _range = null),
                              ),
                            ],
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            onChanged: _search,
                            decoration: InputDecoration(
                              hintText: 'Search transactions',
                              prefixIcon: Icon(Icons.search_rounded, color: p.muted),
                              isDense: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton.filledTonal(
                          tooltip: 'Filters',
                          onPressed: () => _openFilters(txns.value ?? const []),
                          icon: Badge(
                            isLabelVisible: _filter.isActive,
                            label: Text('${_filter.activeCount}'),
                            child: const Icon(Icons.tune_rounded),
                          ),
                        ),
                      ],
                    ),
                    _ActiveFilters(
                      filter: _filter,
                      walletNames: walletNames,
                      partnerName: me.partner?.name ?? 'partner',
                      onChanged: (f) => setState(() => _filter = f),
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
                      return ref.refresh(_source.future);
                    },
                    child: switch (_filter.apply(value, me.user.id)) {
                      final shown when shown.isEmpty && value.isNotEmpty => EmptyState(
                        title: 'No matches',
                        message: 'Nothing fits these filters.',
                        actionLabel: 'Clear filters',
                        onAction: () => setState(() => _filter = TxnFilter.none),
                      ),
                      final shown when shown.isNotEmpty => _GroupedList(
                        shown,
                        walletNames: walletNames,
                        filtered: _filter.isActive || range != null || _query.isNotEmpty,
                        // Transfers aren't editable; their goal is where they live.
                        onEdit: (t) => t.isTransfer || t.isRelease
                            ? context.go('/goals')
                            : t.isMove
                            ? context.go('/home/wallets?id=${t.toWalletId}')
                            : context.push('/add', extra: t),
                        onDelete: _delete,
                      ),
                      _ => EmptyState(
                        title: _query.isNotEmpty
                            ? 'No matches'
                            : range != null
                            ? 'Nothing in these dates'
                            : 'No transactions this month',
                        message: _query.isNotEmpty
                            ? 'Nothing in ${range == null ? monthLabel(_month) : _rangeLabel(range)} matches "$_query".'
                            : 'Log what you spend and earn, and you will both see it here.',
                        actionLabel: _query.isEmpty ? 'Add expense' : null,
                        onAction: _query.isEmpty ? () => context.push('/add') : null,
                        mood: _query.isEmpty && range == null ? MascotMood.curious : MascotMood.idle,
                      ),
                    },
                  ),
                  AsyncError(:final error) => ErrorRetry(error: error, onRetry: () => ref.invalidate(_source)),
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

String _rangeLabel(DateTimeRange r) => '${shortDate(r.start)} – ${shortDate(r.end)}';

class _GroupedList extends StatelessWidget {
  const _GroupedList(this.txns, {required this.onEdit, required this.onDelete, this.filtered = false, this.walletNames = const {}});

  final List<Txn> txns;
  final Map<int, String> walletNames;

  /// Showing a search, filter or custom range rather than the whole month.
  final bool filtered;
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

    final days = byDay.entries.toList();
    // Built lazily, a day at a time: a month or range can hold hundreds of rows.
    final items = <Widget Function()>[
      () => FadeSlideIn(
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
                income >= expense
                    ? '${peso(income - expense)} left over ${filtered ? 'in these results' : 'this month'}'
                    : '${peso(expense - income)} more out than in',
                style: const TextStyle(color: Color(0xDDFFFFFF), fontSize: 12.5),
              ),
            ],
          ),
        ),
      ),
      () => Padding(
        padding: const EdgeInsets.fromLTRB(4, 14, 4, 0),
        child: Text(
          '${txns.length} ${txns.length == 1 ? 'transaction' : 'transactions'} · ${peso(expense)} out',
          style: TextStyle(color: p.muted, fontSize: 12.5, fontWeight: FontWeight.w600),
        ),
      ),
      for (final (i, entry) in days.indexed)
        () => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
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
                        child: TxnTile(t, walletName: walletNames[t.walletId], onTap: () => onEdit(t)),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      () => Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Text(
          'Tap to edit · swipe left to delete',
          textAlign: TextAlign.center,
          style: TextStyle(color: p.muted, fontSize: 12),
        ),
      ),
    ];

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 96),
      itemCount: items.length,
      itemBuilder: (_, i) => items[i](),
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

/// Removable chips for each active filter; nothing when none are on.
class _ActiveFilters extends StatelessWidget {
  const _ActiveFilters({required this.filter, required this.partnerName, required this.onChanged, this.walletNames = const {}});

  final TxnFilter filter;
  final Map<int, String> walletNames;
  final String partnerName;
  final ValueChanged<TxnFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    if (!filter.isActive) return const SizedBox.shrink();
    const kindLabels = {TxnKind.expense: 'Expenses', TxnKind.income: 'Income', TxnKind.savings: 'Savings'};
    final chips = <(String, TxnFilter)>[
      for (final k in filter.kinds) (kindLabels[k]!, filter.copyWith(kinds: {...filter.kinds}..remove(k))),
      for (final c in filter.categories) (categoryStyle(c).label, filter.copyWith(categories: {...filter.categories}..remove(c))),
      if (filter.payer != Payer.anyone)
        (filter.payer == Payer.me ? 'Paid by me' : 'Paid by $partnerName', filter.copyWith(payer: Payer.anyone)),
      if (filter.split != SplitFilter.any)
        (filter.split == SplitFilter.shared ? 'Shared' : 'Personal', filter.copyWith(split: SplitFilter.any)),
      for (final w in filter.wallets) (walletNames[w] ?? 'Wallet', filter.copyWith(wallets: {...filter.wallets}..remove(w))),
    ];
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: SizedBox(
        height: 36,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: [
            for (final (label, without) in chips)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: InputChip(
                  label: Text(label),
                  onDeleted: () => onChanged(without),
                  deleteButtonTooltipMessage: 'Remove $label',
                  visualDensity: VisualDensity.compact,
                ),
              ),
            TextButton(onPressed: () => onChanged(TxnFilter.none), child: const Text('Clear all')),
          ],
        ),
      ),
    );
  }
}

/// Type, who paid, shared or personal, and categories, with a live count.
class _FilterSheet extends ConsumerStatefulWidget {
  const _FilterSheet({required this.initial, required this.base});

  final TxnFilter initial;

  /// The period's transactions, to count matches as filters change.
  final List<Txn> base;

  @override
  ConsumerState<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends ConsumerState<_FilterSheet> {
  late TxnFilter _f = widget.initial;

  @override
  Widget build(BuildContext context) {
    final p = context.pn;
    final me = ref.watch(meProvider);
    final partner = me.partner;
    final count = _f.apply(widget.base, me.user.id).length;
    final wallets = ref.watch(walletsProvider).value ?? const <Wallet>[];
    Widget label(String text) => Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Text(
        text,
        style: TextStyle(color: p.muted, fontWeight: FontWeight.w700, fontSize: 12.5),
      ),
    );

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.85),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 12, 0),
              child: Row(
                children: [
                  Expanded(child: Text('Filters', style: Theme.of(context).textTheme.titleLarge)),
                  TextButton(onPressed: () => setState(() => _f = TxnFilter.none), child: const Text('Reset')),
                ],
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                children: [
                  label('TYPE'),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final (kind, text) in [(TxnKind.expense, 'Expenses'), (TxnKind.income, 'Income'), (TxnKind.savings, 'Savings')])
                        FilterChip(
                          label: Text(text),
                          selected: _f.kinds.contains(kind),
                          onSelected: (on) =>
                              setState(() => _f = _f.copyWith(kinds: on ? {..._f.kinds, kind} : ({..._f.kinds}..remove(kind)))),
                        ),
                    ],
                  ),
                  if (partner != null) ...[
                    label('PAID BY'),
                    PillTabs(
                      labels: ['Anyone', 'Me', partner.name],
                      index: _f.payer.index,
                      onChanged: (i) => setState(() => _f = _f.copyWith(payer: Payer.values[i])),
                    ),
                  ],
                  label('SHARED OR PERSONAL'),
                  PillTabs(
                    labels: const ['Any', 'Shared', 'Personal'],
                    index: _f.split.index,
                    onChanged: (i) => setState(() => _f = _f.copyWith(split: SplitFilter.values[i])),
                  ),
                  if (wallets.isNotEmpty) ...[
                    label('WALLET'),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        for (final w in wallets)
                          FilterChip(
                            avatar: BrandBadge(brandOf(w.provider), size: 20),
                            // Both of you have a "Cash": say whose a partner's wallet is.
                            label: Text(w.isShared || w.ownerId == me.user.id ? w.name : '${w.name} · ${w.ownerName}'),
                            selected: _f.wallets.contains(w.id),
                            onSelected: (on) =>
                                setState(() => _f = _f.copyWith(wallets: on ? {..._f.wallets, w.id} : ({..._f.wallets}..remove(w.id)))),
                          ),
                      ],
                    ),
                  ],
                  label('CATEGORY'),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      for (final c in expenseCategories)
                        FilterChip(
                          avatar: Icon(c.icon, size: 16, color: c.color),
                          label: Text(c.label),
                          selected: _f.categories.contains(c.key),
                          onSelected: (on) => setState(
                            () => _f = _f.copyWith(categories: on ? {..._f.categories, c.key} : ({..._f.categories}..remove(c.key))),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
              child: FilledButton(
                onPressed: () => Navigator.pop(context, _f),
                child: Text(count == 1 ? 'Show 1 result' : 'Show $count results'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
