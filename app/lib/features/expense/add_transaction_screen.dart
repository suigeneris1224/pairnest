import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets/nest_ui.dart';
import '../../core/format.dart';
import '../../core/mascot/mascot_controller.dart';
import '../../core/theme/palettes.dart';
import '../../core/widgets/bank_card.dart';
import '../../core/widgets/categories.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/wallet_brands.dart';
import '../../data/models.dart';
import '../../data/providers.dart';

const paymentMethods = {'cash': 'Cash', 'card': 'Card', 'gcash': 'GCash', 'maya': 'Maya', 'bank': 'Bank transfer'};

/// Adds a transaction, or edits [existing] when one is passed.
class AddTransactionScreen extends ConsumerStatefulWidget {
  const AddTransactionScreen({super.key, this.initialType = 'expense', this.existing});

  final String initialType;
  final Txn? existing;

  @override
  ConsumerState<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends ConsumerState<AddTransactionScreen> {
  late final Txn? _existing = widget.existing;
  late final _amount = TextEditingController(text: _existing == null ? '' : _plain(_existing.amount));
  late final _title = TextEditingController(text: _existing?.title ?? '');
  late String _type = _existing?.type ?? (widget.initialType == 'income' ? 'income' : 'expense');
  late String _category = _existing != null && _existing.isExpense ? _existing.category : 'food';
  late String _payment = paymentMethods.containsKey(_existing?.paymentMethod) ? _existing!.paymentMethod : 'cash';
  late DateTime _date = _existing?.occurredOn ?? DateTime.now();
  late bool _split = _existing?.isSplit ?? true;
  late int _paidBy = _existing?.userId ?? ref.read(meProvider).user.id;
  late int? _walletId = _existing != null ? _existing.walletId : ref.read(prefsProvider).getInt(_lastWalletKey);
  bool _busy = false;

  static const _lastWalletKey = 'last_wallet_id';

  bool get _isExpense => _type == 'expense';
  bool get _editing => _existing != null;

  static String _plain(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);

  @override
  void dispose() {
    _amount.dispose();
    _title.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    final amount = double.tryParse(_amount.text.replaceAll(',', ''));
    if (amount == null || amount <= 0) {
      showSnack(context, 'Enter an amount greater than zero.');
      return;
    }
    final category = _isExpense ? _category : 'income';
    final title = _title.text.trim().isEmpty ? categoryStyle(category).label : _title.text.trim();

    final draft = TxnDraft(
      type: _type,
      amount: amount,
      category: category,
      title: title,
      paymentMethod: _payment,
      isSplit: _isExpense && _split,
      occurredOn: _date,
      paidBy: _isExpense ? _paidBy : _existing?.userId,
      walletId: _usableWallet(ref.read(walletsProvider).value ?? const [])?.id,
    );
    if (draft.walletId != null) ref.read(prefsProvider).setInt(_lastWalletKey, draft.walletId!);
    final repo = ref.read(repositoryProvider);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      if (_editing) {
        await repo.updateTransaction(_existing!.id, draft);
        invalidateMoney(ref);
        if (mounted) Navigator.of(context).pop();
        showSnackOn(messenger, 'Changes saved');
      } else {
        final saved = await repo.addTransaction(draft);
        invalidateMoney(ref);
        final mascot = ref.read(mascotControllerProvider);
        if (mounted) Navigator.of(context).pop();
        // Once this screen has slid away, the Home birds glance down at the new entry.
        if (_isExpense) Future.delayed(const Duration(milliseconds: 400), () => mascot.react(MascotReaction.glance));
        showSnackOn(
          messenger,
          '${_isExpense ? 'Expense' : 'Income'} saved',
          actionLabel: 'Undo',
          onAction: () => _undo(() => repo.deleteTransaction(saved.id), messenger),
        );
      }
    } catch (e) {
      if (mounted) showSnack(context, friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Whoever pays can use shared wallets and their own.
  int get _payer => _isExpense ? _paidBy : (_existing?.userId ?? ref.read(meProvider).user.id);

  Wallet? _usableWallet(List<Wallet> wallets) => wallets.where((w) => w.id == _walletId && w.usableBy(_payer)).firstOrNull;

  Future<void> _delete() async {
    final txn = _existing!;
    final repo = ref.read(repositoryProvider);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await repo.deleteTransaction(txn.id);
      invalidateMoney(ref);
      if (mounted) Navigator.of(context).pop();
      showSnackOn(
        messenger,
        '"${txn.title}" deleted',
        actionLabel: 'Undo',
        onAction: () => _undo(() => repo.addTransaction(TxnDraft.fromTxn(txn)), messenger),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        showSnack(context, friendlyError(e));
      }
    }
  }

  /// Runs an undo after this screen has closed, so it uses the captured
  /// container and messenger rather than this State.
  void _undo(Future<Object?> Function() action, ScaffoldMessengerState messenger) {
    final container = ProviderScope.containerOf(messenger.context, listen: false);
    action().then((_) => invalidateMoneyIn(container), onError: (Object e) => showSnackOn(messenger, friendlyError(e)));
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pn;
    final me = ref.watch(meProvider);
    final partner = me.partner;
    final wallets = ref.watch(walletsProvider).value ?? const <Wallet>[];
    final selectedWallet = _usableWallet(wallets);
    return Scaffold(
      body: NestBackground(
        child: SafeArea(
          child: Column(
            children: [
              PageHeader(
                '${_editing ? 'Edit' : 'Add'} ${_isExpense ? 'Expense' : 'Income'}',
                trailing: _editing
                    ? TextButton(
                        onPressed: _busy ? null : _delete,
                        style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
                        child: const Text('Delete'),
                      )
                    : null,
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  children: [
                    PillTabs(
                      labels: const ['Expense', 'Income'],
                      index: _isExpense ? 0 : 1,
                      onChanged: (i) => setState(() => _type = i == 0 ? 'expense' : 'income'),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _amount,
                      autofocus: !_editing,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                      style: Theme.of(context).textTheme.headlineMedium,
                      decoration: InputDecoration(
                        prefixIcon: Padding(
                          padding: const EdgeInsets.only(left: 16, right: 4),
                          child: Text('₱', style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: p.muted)),
                        ),
                        prefixIconConstraints: const BoxConstraints(),
                        hintText: '0.00',
                        fillColor: p.soft.withValues(alpha: 0.5),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                      ),
                    ),
                    if (_isExpense) ...[
                      const SizedBox(height: 16),
                      GridView(
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 4, mainAxisExtent: 100),
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        children: [
                          for (final c in expenseCategories)
                            CategoryChoice(style: c, selected: c.key == _category, onTap: () => setState(() => _category = c.key)),
                        ],
                      ),
                    ],
                    const SizedBox(height: 12),
                    TextField(
                      controller: _title,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(labelText: 'Title', hintText: _isExpense ? 'e.g. Grocery at SM' : 'e.g. Salary'),
                    ),
                    const SizedBox(height: 12),
                    InkWell(
                      onTap: _pickDate,
                      borderRadius: BorderRadius.circular(14),
                      child: InputDecorator(
                        decoration: const InputDecoration(labelText: 'Date', suffixIcon: Icon(Icons.calendar_today_rounded, size: 18)),
                        child: Text(longDate(_date)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (wallets.isEmpty)
                      DropdownButtonFormField<String>(
                        initialValue: _payment,
                        decoration: const InputDecoration(labelText: 'Payment method'),
                        borderRadius: BorderRadius.circular(14),
                        items: [for (final e in paymentMethods.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
                        onChanged: (v) => setState(() => _payment = v ?? 'cash'),
                      )
                    else ...[
                      Text(
                        _isExpense ? 'Paid with' : 'Received in',
                        style: TextStyle(color: p.muted, fontSize: 12.5, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 6),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            for (final w in wallets.where((w) => w.usableBy(_payer))) ...[
                              ChoiceChip(
                                avatar: BrandBadge(brandOf(w.provider), size: 22),
                                label: Text(w.isShared ? '${w.name} · Ours' : w.name),
                                selected: selectedWallet?.id == w.id,
                                onSelected: (_) => setState(() {
                                  _walletId = w.id;
                                  // Paid from the shared pot: it's shared spending.
                                  if (w.isShared) _split = true;
                                }),
                              ),
                              const SizedBox(width: 8),
                            ],
                            ChoiceChip(
                              label: const Text('No wallet'),
                              selected: selectedWallet == null,
                              onSelected: (_) => setState(() => _walletId = null),
                            ),
                          ],
                        ),
                      ),
                    ],
                    // Paid from a shared wallet: it came from the pot, not one person.
                    if (_isExpense && partner != null && !(selectedWallet?.isShared ?? false)) ...[
                      const SizedBox(height: 14),
                      Text(
                        'Paid by',
                        style: TextStyle(color: p.muted, fontSize: 12.5, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 6),
                      PillTabs(
                        labels: ['Me', partner.name],
                        index: _paidBy == me.user.id ? 0 : 1,
                        onChanged: (i) => setState(() => _paidBy = i == 0 ? me.user.id : partner.id),
                      ),
                    ],
                    if (_isExpense) ...[
                      const SizedBox(height: 4),
                      SwitchListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                        title: const Text('Split with partner'),
                        subtitle: Text('Shared 50/50 · counts toward who owes whom', style: TextStyle(color: p.muted, fontSize: 12)),
                        value: _split,
                        onChanged: (v) => setState(() => _split = v),
                      ),
                    ],
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: FilledButton(onPressed: _busy ? null : _save, child: const Text('Save')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
