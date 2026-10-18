import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/theme/palettes.dart';
import '../../core/widgets/bank_card.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/wallet_brands.dart';
import '../../data/models.dart';
import '../../data/providers.dart';

/// Moves money between two wallets, e.g. topping up a shared one or paying a
/// card. Shows "Moved · Undo" once done.
Future<void> openMoveSheet(BuildContext context, WidgetRef ref, {Wallet? from, Wallet? to, double? amount}) async {
  final wallets = [
    for (final w in ref.read(walletsProvider).value ?? const <Wallet>[])
      if (w.usableBy(ref.read(meProvider).user.id)) w,
  ];
  if (wallets.length < 2) {
    showSnack(context, 'Add another wallet to move money between them.');
    return;
  }
  final result = await showModalBottomSheet<({int from, int to, double amount, String note})>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    builder: (_) => _MoveSheet(wallets: wallets, from: from, to: to, amount: amount),
  );
  if (result == null || !context.mounted) return;
  final repo = ref.read(repositoryProvider);
  final messenger = ScaffoldMessenger.of(context);
  final container = ProviderScope.containerOf(context, listen: false);
  try {
    final moved = await repo.moveMoney(
      fromWalletId: result.from,
      toWalletId: result.to,
      amount: result.amount,
      note: result.note.isEmpty ? null : result.note,
    );
    invalidateMoney(ref);
    HapticFeedback.lightImpact();
    final toName = wallets.firstWhere((w) => w.id == result.to).name;
    showSnackOn(
      messenger,
      'Moved ${peso(result.amount)} to $toName',
      actionLabel: 'Undo',
      onAction: () => repo
          .deleteTransaction(moved.transaction.id)
          .then((_) => invalidateMoneyIn(container), onError: (Object e) => showSnackOn(messenger, friendlyError(e))),
    );
  } catch (e) {
    showSnackOn(messenger, friendlyError(e));
  }
}

class _MoveSheet extends StatefulWidget {
  const _MoveSheet({required this.wallets, this.from, this.to, this.amount});

  final List<Wallet> wallets;
  final Wallet? from;
  final Wallet? to;
  final double? amount;

  @override
  State<_MoveSheet> createState() => _MoveSheetState();
}

class _MoveSheetState extends State<_MoveSheet> {
  late int _from =
      widget.from?.id ??
      widget.wallets
          .firstWhere((w) => w.id != widget.to?.id && !w.isShared, orElse: () => widget.wallets.firstWhere((w) => w.id != widget.to?.id))
          .id;
  late int _to = widget.to?.id ?? widget.wallets.firstWhere((w) => w.id != _from).id;
  late final _amount = TextEditingController(
    text: widget.amount == null ? '' : widget.amount!.toStringAsFixed(widget.amount! == widget.amount!.roundToDouble() ? 0 : 2),
  );
  final _note = TextEditingController();

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Wallet _w(int id) => widget.wallets.firstWhere((w) => w.id == id);

  double? get _value {
    final v = double.tryParse(_amount.text.replaceAll(',', ''));
    return v == null || v <= 0 ? null : v;
  }

  void _setFrom(int id) => setState(() {
    if (id == _to) _to = _from;
    _from = id;
  });

  void _setTo(int id) => setState(() {
    if (id == _from) _from = _to;
    _to = id;
  });

  @override
  Widget build(BuildContext context) {
    final p = context.pn;
    final to = _w(_to);
    final value = _value;
    final title = to.isShared ? 'Top up ${to.name}' : (to.isCredit ? 'Pay ${to.name}' : 'Move money');
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text("Moving money isn't spending. It just changes which wallet holds it.", style: TextStyle(color: p.muted, fontSize: 12.5)),
            const SizedBox(height: 16),
            _WalletChoice(label: 'From', wallets: widget.wallets, value: _from, onChanged: _setFrom),
            Center(
              child: IconButton.filledTonal(
                tooltip: 'Swap',
                icon: const Icon(Icons.swap_vert_rounded),
                onPressed: () => setState(() {
                  final f = _from;
                  _from = _to;
                  _to = f;
                }),
              ),
            ),
            _WalletChoice(label: 'To', wallets: widget.wallets, value: _to, onChanged: _setTo),
            const SizedBox(height: 14),
            TextField(
              controller: _amount,
              autofocus: widget.amount == null,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
              decoration: const InputDecoration(labelText: 'Amount', prefixText: '₱ '),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _note,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Note (optional)', hintText: 'e.g. My share for October'),
            ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: value == null
                  ? null
                  : () => Navigator.pop(context, (from: _from, to: _to, amount: value, note: _note.text.trim())),
              child: Text(value == null ? 'Move' : 'Move ${peso(value)}'),
            ),
          ],
        ),
      ),
    );
  }
}

class _WalletChoice extends StatelessWidget {
  const _WalletChoice({required this.label, required this.wallets, required this.value, required this.onChanged});

  final String label;
  final List<Wallet> wallets;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final p = context.pn;
    return DropdownButtonFormField<int>(
      key: ValueKey('$label-$value'),
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      borderRadius: BorderRadius.circular(14),
      items: [
        for (final w in wallets)
          DropdownMenuItem(
            value: w.id,
            child: Row(
              children: [
                BrandBadge(brandOf(w.provider), size: 26),
                const SizedBox(width: 10),
                Expanded(child: Text(w.isShared ? '${w.name} · Ours' : w.name, overflow: TextOverflow.ellipsis)),
                Text(walletBalanceText(w), style: TextStyle(color: p.muted, fontSize: 12.5)),
              ],
            ),
          ),
      ],
      onChanged: (v) => v == null ? null : onChanged(v),
    );
  }
}
