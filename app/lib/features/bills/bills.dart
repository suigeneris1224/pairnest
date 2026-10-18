import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/theme/palettes.dart';
import '../../core/widgets/categories.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/nest_ui.dart';
import '../../core/widgets/wallet_picker.dart';
import '../../data/models.dart';
import '../../data/providers.dart';

/// Asks to confirm, then logs this period's payment and moves the bill on.
Future<void> payBill(BuildContext context, WidgetRef ref, Bill bill) async {
  final p = context.pn;
  // The bill's wallet, if whoever's paying can use it.
  final me = ref.read(meProvider).user.id;
  final wallet = knownWallets(ref).where((w) => w.id == bill.walletId && w.usableBy(me)).firstOrNull;
  final ok = await showModalBottomSheet<bool>(
    context: context,
    useRootNavigator: true,
    builder: (sheet) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                CategoryIcon(bill.category),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Mark ${bill.title} as paid?', style: Theme.of(sheet).textTheme.titleMedium),
                      const SizedBox(height: 2),
                      Text(
                        bill.dueLabel(),
                        style: TextStyle(color: bill.isOverdue() ? Theme.of(sheet).colorScheme.error : p.muted, fontSize: 12.5),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              '${peso(bill.amount)} will be logged as an expense today${wallet == null ? '' : ' from ${wallet.name}'}, and the next one will be due '
              '${bill.isWeekly ? 'in a week' : 'next month'}.',
              style: TextStyle(color: p.muted, height: 1.4),
            ),
            const SizedBox(height: 18),
            FilledButton(onPressed: () => Navigator.pop(sheet, true), child: Text('Paid ${peso(bill.amount)}')),
            TextButton(onPressed: () => Navigator.pop(sheet, false), child: const Text('Not yet')),
          ],
        ),
      ),
    ),
  );
  if (ok != true || !context.mounted) return;
  final repo = ref.read(repositoryProvider);
  final messenger = ScaffoldMessenger.of(context);
  final container = ProviderScope.containerOf(context, listen: false);
  try {
    final paid = await repo.payBill(bill.id);
    invalidateMoney(ref);
    HapticFeedback.lightImpact();
    showSnackOn(
      messenger,
      '${bill.title} paid · next due ${shortDate(paid.bill.nextDueOn)}',
      actionLabel: 'Undo',
      onAction: () => repo
          .unpayBill(bill.id, transactionId: paid.transactionId, previousDue: bill.nextDueOn)
          .then((_) => invalidateMoneyIn(container), onError: (Object e) => showSnackOn(messenger, friendlyError(e))),
    );
  } catch (e) {
    showSnackOn(messenger, friendlyError(e));
  }
}

/// Opens the add/edit sheet; returns once it closes.
Future<void> openBillEditor(BuildContext context, {Bill? existing}) => showModalBottomSheet<void>(
  context: context,
  useRootNavigator: true,
  isScrollControlled: true,
  builder: (_) => BillEditor(existing: existing),
);

/// One bill: category icon, title, due label and amount.
class BillRow extends StatelessWidget {
  const BillRow(this.bill, {super.key, this.onTap, this.trailing, this.compact = false, this.hideAmount = false});

  final Bill bill;
  final VoidCallback? onTap;
  final Widget? trailing;
  final bool compact;
  final bool hideAmount;

  @override
  Widget build(BuildContext context) {
    final p = context.pn;
    final overdue = bill.isOverdue();
    final due = bill.daysUntilDue() <= 2;
    final chip = Container(
      padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 10, vertical: compact ? 2 : 3),
      decoration: BoxDecoration(color: Pastel.peach.background(p), borderRadius: BorderRadius.circular(20)),
      child: Text(
        hideAmount ? '₱••••' : peso(bill.amount),
        style: TextStyle(fontSize: compact ? 10.5 : 12, color: Pastel.peach.foreground(p), fontWeight: FontWeight.w700),
      ),
    );
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: compact ? 6 : 10),
        child: Row(
          children: [
            CategoryIcon(bill.category, size: compact ? 34 : 44),
            SizedBox(width: compact ? 8 : 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    bill.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: compact ? 13 : null),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    compact ? bill.dueLabel() : '${bill.dueLabel()} · ${bill.isWeekly ? 'Weekly' : 'Monthly'}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: compact ? 11 : 12,
                      color: overdue ? Theme.of(context).colorScheme.error : (due ? p.heading : p.muted),
                      fontWeight: overdue || due ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                  if (compact) ...[const SizedBox(height: 4), chip],
                ],
              ),
            ),
            if (!compact) ...[const SizedBox(width: 6), chip],
            ?trailing,
          ],
        ),
      ),
    );
  }
}

/// The couple's recurring bills, for the Budgets page.
class BillsSection extends ConsumerWidget {
  const BillsSection({super.key});

  Future<void> _delete(BuildContext context, WidgetRef ref, Bill bill) async {
    final repo = ref.read(repositoryProvider);
    try {
      await repo.deleteBill(bill.id);
    } catch (e) {
      if (context.mounted) showSnack(context, friendlyError(e));
      return;
    } finally {
      invalidateMoney(ref);
    }
    if (!context.mounted) return;
    showSnack(
      context,
      '${bill.title} removed',
      actionLabel: 'Undo',
      onAction: () async {
        await repo.addBill(
          BillDraft(
            title: bill.title,
            amount: bill.amount,
            category: bill.category,
            frequency: bill.frequency,
            nextDueOn: bill.nextDueOn,
            isSplit: bill.isSplit,
            walletId: bill.walletId,
          ),
        );
        if (context.mounted) invalidateMoney(ref);
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.pn;
    final bills = ref.watch(billsProvider);
    return SectionCard(
      icon: Icons.receipt_long_rounded,
      title: 'Bills',
      action: 'Add bill',
      onAction: () => openBillEditor(context),
      child: switch (bills) {
        AsyncData(:final value) when value.isEmpty => Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text(
            'Add rent, subscriptions and utilities. They show up on Home before they are due, and one tap logs the payment.',
            style: TextStyle(color: p.muted, fontSize: 12.5, height: 1.4),
          ),
        ),
        AsyncData(:final value) => Column(
          children: [
            for (final bill in value)
              Dismissible(
                key: ValueKey('bill-${bill.id}'),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 12),
                  color: Theme.of(context).colorScheme.error.withValues(alpha: 0.12),
                  child: Icon(Icons.delete_outline_rounded, color: Theme.of(context).colorScheme.error, semanticLabel: 'Delete'),
                ),
                onDismissed: (_) => _delete(context, ref, bill),
                child: BillRow(
                  bill,
                  onTap: () => openBillEditor(context, existing: bill),
                  trailing: IconButton(
                    tooltip: 'Mark ${bill.title} paid',
                    visualDensity: VisualDensity.compact,
                    icon: Icon(Icons.check_circle_outline_rounded, color: p.primaryDeep),
                    onPressed: () => payBill(context, ref, bill),
                  ),
                ),
              ),
          ],
        ),
        AsyncError(:final error) => ErrorRetry(error: error, onRetry: () => ref.invalidate(billsProvider)),
        _ => const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Skeleton(height: 44)),
      },
    );
  }
}

class BillEditor extends ConsumerStatefulWidget {
  const BillEditor({super.key, this.existing});

  final Bill? existing;

  @override
  ConsumerState<BillEditor> createState() => _BillEditorState();
}

class _BillEditorState extends ConsumerState<BillEditor> {
  late final Bill? _existing = widget.existing;
  late final _title = TextEditingController(text: _existing?.title ?? '');
  late final _amount = TextEditingController(
    text: _existing == null ? '' : _existing.amount.toStringAsFixed(_existing.amount == _existing.amount.roundToDouble() ? 0 : 2),
  );
  late String _category = _existing?.category ?? 'bills';
  late bool _weekly = _existing?.isWeekly ?? false;
  late DateTime _due = _existing?.nextDueOn ?? DateTime.now();
  late bool _split = _existing?.isSplit ?? true;
  late int? _walletId = _existing?.walletId;
  bool _busy = false;

  @override
  void dispose() {
    _title.dispose();
    _amount.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _due,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 2),
    );
    if (picked != null) setState(() => _due = picked);
  }

  Future<void> _save() async {
    final amount = double.tryParse(_amount.text.replaceAll(',', '')) ?? 0;
    if (_title.text.trim().isEmpty || amount <= 0) {
      showSnack(context, 'Give the bill a name and an amount.');
      return;
    }
    final draft = BillDraft(
      title: _title.text.trim(),
      amount: amount,
      category: _category,
      frequency: _weekly ? 'weekly' : 'monthly',
      nextDueOn: _due,
      isSplit: _split,
      walletId: _walletId,
    );
    setState(() => _busy = true);
    try {
      final repo = ref.read(repositoryProvider);
      _existing == null ? await repo.addBill(draft) : await repo.updateBill(_existing.id, draft);
      invalidateMoney(ref);
      if (mounted) Navigator.pop(context);
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
            SheetTitle(_existing == null ? 'New bill' : 'Edit bill'),
            const SizedBox(height: 16),
            TextField(
              controller: _title,
              autofocus: _existing == null,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Name', hintText: 'e.g. Rent, Netflix, Meralco'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _amount,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
              decoration: const InputDecoration(labelText: 'Amount', prefixText: '₱ '),
            ),
            const SizedBox(height: 12),
            GridView(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 4, mainAxisExtent: 96),
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                for (final c in expenseCategories)
                  CategoryChoice(style: c, selected: c.key == _category, onTap: () => setState(() => _category = c.key)),
              ],
            ),
            const SizedBox(height: 8),
            PillTabs(labels: const ['Monthly', 'Weekly'], index: _weekly ? 1 : 0, onChanged: (i) => setState(() => _weekly = i == 1)),
            const SizedBox(height: 12),
            InkWell(
              onTap: _pickDate,
              borderRadius: BorderRadius.circular(14),
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: _existing == null ? 'First due date' : 'Next due date',
                  suffixIcon: const Icon(Icons.calendar_today_rounded, size: 18),
                ),
                child: Text(longDate(_due)),
              ),
            ),
            WalletDropdown(label: 'Paid from', value: _walletId, onChanged: (id) => setState(() => _walletId = id)),
            SwitchListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 4),
              title: const Text('Split with partner'),
              subtitle: Text('Counts toward your shared budget', style: TextStyle(color: p.muted, fontSize: 12)),
              value: _split,
              onChanged: (v) => setState(() => _split = v),
            ),
            const SizedBox(height: 8),
            FilledButton(onPressed: _busy ? null : _save, child: Text(_existing == null ? 'Add bill' : 'Save changes')),
          ],
        ),
      ),
    );
  }
}
