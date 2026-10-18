import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets/nest_ui.dart';
import '../../core/motion/motion.dart';
import '../../core/format.dart';
import '../../core/theme/palettes.dart';
import '../../core/widgets/categories.dart';
import '../../core/widgets/common.dart';
import '../../data/models.dart';
import '../../data/providers.dart';
import '../bills/bills.dart';
import '../paydays/paydays.dart';

class BudgetsScreen extends ConsumerStatefulWidget {
  const BudgetsScreen({super.key});

  @override
  ConsumerState<BudgetsScreen> createState() => _BudgetsScreenState();
}

class _BudgetsScreenState extends ConsumerState<BudgetsScreen> {
  DateTime _month = monthStart(DateTime.now());

  Map<String, double> _spending(List<Txn>? txns) {
    final out = <String, double>{};
    for (final t in txns ?? const <Txn>[]) {
      if (t.isExpense) out[t.category] = (out[t.category] ?? 0) + t.amount;
    }
    return out;
  }

  void _shift(int delta) => setState(() => _month = DateTime(_month.year, _month.month + delta));

  @override
  Widget build(BuildContext context) {
    final budget = ref.watch(budgetProvider(_month));

    return Scaffold(
      body: NestBackground(
        child: SafeArea(
          child: Column(
            children: [
              PageHeader(
                'Budgets',
                trailing: IconButton(
                  tooltip: 'Edit budget',
                  icon: const Icon(Icons.edit_rounded),
                  onPressed: budget.hasValue ? () => _edit(budget.requireValue) : null,
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(tooltip: 'Previous month', icon: const Icon(Icons.chevron_left_rounded), onPressed: () => _shift(-1)),
                  Text(monthLabel(_month), style: const TextStyle(fontWeight: FontWeight.w700)),
                  IconButton(tooltip: 'Next month', icon: const Icon(Icons.chevron_right_rounded), onPressed: () => _shift(1)),
                ],
              ),
              Expanded(
                child: switch (budget) {
                  AsyncData(:final value) => RefreshIndicator(
                    onRefresh: () {
                      invalidateMoney(ref);
                      return ref.refresh(budgetProvider(_month).future);
                    },
                    child: value.total == 0 && value.lines.isEmpty
                        ? ListView(
                            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                            children: [
                              FadeSlideIn(
                                child: SectionCard(
                                  icon: Icons.savings_outlined,
                                  title: 'No budget for this month yet',
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Agree on a total and a few category limits, and Pairnest will keep score for you both.',
                                        style: TextStyle(color: context.pn.muted, height: 1.4),
                                      ),
                                      const SizedBox(height: 12),
                                      FilledButton.tonal(onPressed: () => _edit(value), child: const Text('Set a budget together')),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 14),
                              const FadeSlideIn(index: 1, child: BillsSection()),
                              const SizedBox(height: 14),
                              const FadeSlideIn(index: 2, child: PaydaysSection()),
                            ],
                          )
                        : ListView(
                            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                            children: [
                              FadeSlideIn(
                                child: HeroCard(
                                  child: Column(
                                    children: [
                                      Row(
                                        children: [
                                          _Figure('Total Budget', value.total, Colors.white),
                                          _Figure('Spent', value.spent, Colors.white),
                                          _Figure(
                                            'Remaining',
                                            value.remaining,
                                            value.remaining < 0 ? const Color(0xFFFFC2B8) : Colors.white,
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 14),
                                      HeroProgress(value.ratio),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 14),
                              FadeSlideIn(
                                index: 1,
                                child: SectionCard(
                                  title: 'Where it went',
                                  icon: Icons.pie_chart_outline_rounded,
                                  child: SpendingDonut(spending: _spending(ref.watch(transactionsProvider((_month, ''))).value)),
                                ),
                              ),
                              const SizedBox(height: 14),
                              FadeSlideIn(index: 2, child: const BillsSection()),
                              const SizedBox(height: 14),
                              FadeSlideIn(index: 3, child: const PaydaysSection()),
                              const SizedBox(height: 14),
                              for (final (i, line) in value.lines.indexed) ...[
                                FadeSlideIn(index: i + 4, child: _LineCard(line)),
                                const SizedBox(height: 12),
                              ],
                            ],
                          ),
                  ),
                  AsyncError(:final error) => ErrorRetry(error: error, onRetry: () => ref.invalidate(budgetProvider(_month))),
                  _ => const SkeletonList(),
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _edit(BudgetSummary current) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      builder: (_) => _BudgetEditor(month: _month, current: current),
    );
    if (saved == true) invalidateMoney(ref);
  }
}

class _Figure extends StatelessWidget {
  const _Figure(this.label, this.value, this.color);

  final String label;
  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Color(0xDDFFFFFF), fontSize: 12)),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: AnimatedAmount(
              value,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: color),
            ),
          ),
        ],
      ),
    );
  }
}

class _LineCard extends StatelessWidget {
  const _LineCard(this.line);

  final BudgetLine line;

  @override
  Widget build(BuildContext context) {
    final p = context.pn;
    final style = categoryStyle(line.category);
    return PairnestCard(
      child: Row(
        children: [
          CategoryIcon(line.category, size: 48),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(style.label, style: const TextStyle(fontWeight: FontWeight.w600)),
                    ),
                    Text(peso(line.spent), style: const TextStyle(fontWeight: FontWeight.w700)),
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Expanded(
                      child: Text('of ${peso(line.limit)}', style: TextStyle(color: p.muted, fontSize: 12)),
                    ),
                    Text(
                      line.remaining >= 0 ? '${peso(line.remaining)} left' : '${peso(-line.remaining)} over',
                      style: TextStyle(color: line.remaining >= 0 ? p.muted : const Color(0xFFD9534F), fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: SoftProgress(line.ratio, color: style.color)),
                    const SizedBox(width: 10),
                    Text(
                      '${(line.ratio * 100).round()}%',
                      style: TextStyle(fontSize: 12, color: p.muted, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BudgetEditor extends ConsumerStatefulWidget {
  const _BudgetEditor({required this.month, required this.current});

  final DateTime month;
  final BudgetSummary current;

  @override
  ConsumerState<_BudgetEditor> createState() => _BudgetEditorState();
}

class _BudgetEditorState extends ConsumerState<_BudgetEditor> {
  late final TextEditingController _total;
  late final Map<String, TextEditingController> _limits;
  bool _busy = false;

  String _fmt(double v) => v == 0 ? '' : v.toStringAsFixed(v.truncateToDouble() == v ? 0 : 2);

  @override
  void initState() {
    super.initState();
    _total = TextEditingController(text: _fmt(widget.current.total));
    final existing = {for (final l in widget.current.lines) l.category: l.limit};
    _limits = {for (final c in expenseCategories) c.key: TextEditingController(text: _fmt(existing[c.key] ?? 0))};
  }

  @override
  void dispose() {
    _total.dispose();
    for (final c in _limits.values) {
      c.dispose();
    }
    super.dispose();
  }

  double _parse(TextEditingController c) => double.tryParse(c.text.replaceAll(',', '')) ?? 0;

  Future<void> _save() async {
    final limits = {
      for (final e in _limits.entries)
        if (_parse(e.value) > 0) e.key: _parse(e.value),
    };
    var total = _parse(_total);
    if (total == 0) total = limits.values.fold(0, (a, b) => a + b);

    setState(() => _busy = true);
    try {
      await ref.read(repositoryProvider).saveBudget(widget.month, total, limits);
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
    final numeric = [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))];
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Budget for ${monthLabel(widget.month)}', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            TextField(
              controller: _total,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: numeric,
              decoration: const InputDecoration(
                labelText: 'Total monthly budget',
                prefixText: '₱ ',
                helperText: 'Leave empty to add up the categories',
              ),
            ),
            const SizedBox(height: 16),
            for (final c in expenseCategories) ...[
              TextField(
                controller: _limits[c.key],
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: numeric,
                decoration: InputDecoration(
                  labelText: c.label,
                  prefixText: '₱ ',
                  prefixIcon: Icon(c.icon, color: c.color, size: 20),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 10),
            ],
            const SizedBox(height: 8),
            FilledButton(onPressed: _busy ? null : _save, child: const Text('Save budget')),
          ],
        ),
      ),
    );
  }
}
