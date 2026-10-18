import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/palettes.dart';
import '../../core/widgets/bank_card.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/wallet_brands.dart';
import '../../data/models.dart';
import '../../data/providers.dart';

double? _parse(String text) => double.tryParse(text.replaceAll(',', ''));

/// Opens the add/edit sheet; returns once it closes.
Future<void> openWalletEditor(BuildContext context, {Wallet? existing, String? provider}) => showModalBottomSheet<void>(
  context: context,
  useRootNavigator: true,
  isScrollControlled: true,
  builder: (_) => WalletEditor(existing: existing, provider: provider),
);

/// Asks what the wallet holds now (or owes, for a credit card) and saves it.
Future<void> correctWalletBalance(BuildContext context, WidgetRef ref, Wallet wallet) async {
  final value = await showModalBottomSheet<double>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    builder: (_) => _BalanceSheet(wallet),
  );
  if (value == null || !context.mounted) return;
  try {
    await ref.read(repositoryProvider).setWalletBalance(wallet.id, value);
    invalidateMoney(ref);
    if (context.mounted) showSnack(context, '${wallet.name} balance updated');
  } catch (e) {
    if (context.mounted) showSnack(context, friendlyError(e));
  }
}

class _BalanceSheet extends StatefulWidget {
  const _BalanceSheet(this.wallet);

  final Wallet wallet;

  @override
  State<_BalanceSheet> createState() => _BalanceSheetState();
}

class _BalanceSheetState extends State<_BalanceSheet> {
  late final _controller = TextEditingController(text: _initial());

  String _initial() {
    final current = widget.wallet.balance ?? 0;
    final shown = widget.wallet.isCredit ? -current : current;
    return shown == shown.roundToDouble() ? shown.toStringAsFixed(0) : shown.toStringAsFixed(2);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final wallet = widget.wallet;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SheetTitle('Correct ${wallet.name}'),
              const SizedBox(height: 6),
              Text(
                wallet.isCredit
                    ? 'How much do you owe on it right now? Check your card app.'
                    : 'How much is in it right now? Check your bank or wallet app.',
                style: TextStyle(color: context.pn.muted, height: 1.4),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _controller,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,-]'))],
                decoration: InputDecoration(labelText: wallet.isCredit ? 'Amount owed' : 'Balance', prefixText: '₱ '),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () {
                  final v = _parse(_controller.text);
                  if (v != null) Navigator.pop(context, wallet.isCredit ? -v : v);
                },
                child: const Text('Save balance'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class WalletEditor extends ConsumerStatefulWidget {
  const WalletEditor({super.key, this.existing, this.provider});

  final Wallet? existing;

  /// A brand to start with, e.g. from the empty state's quick picks.
  final String? provider;

  @override
  ConsumerState<WalletEditor> createState() => _WalletEditorState();
}

class _WalletEditorState extends ConsumerState<WalletEditor> {
  late final Wallet? _existing = widget.existing;
  late String _provider = _existing?.provider ?? widget.provider ?? 'gcash';
  late String _kind = _existing?.kind ?? brandOf(_provider).kind;
  late final _name = TextEditingController(text: _existing?.name ?? brandOf(_provider).name);
  late final _last4 = TextEditingController(text: _existing?.last4 ?? '');
  final _balance = TextEditingController();
  late bool _shared = _existing?.isShared ?? false;
  late bool _showPartner = _existing?.showBalanceToPartner ?? false;

  /// The name follows the brand until it's been typed over.
  late bool _nameTouched = _existing != null;
  bool _busy = false;

  bool get _hasNumber => _kind == 'debit' || _kind == 'credit' || _kind == 'bank';

  @override
  void dispose() {
    _name.dispose();
    _last4.dispose();
    _balance.dispose();
    super.dispose();
  }

  void _pickBrand(WalletBrand b) => setState(() {
    _provider = b.key;
    if (_existing == null && !(b.group == 'Banks' && _kind == 'credit')) _kind = b.kind;
    if (!_nameTouched) _name.text = b.name;
  });

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      showSnack(context, 'Give the wallet a name.');
      return;
    }
    final last4 = _last4.text.trim();
    if (_hasNumber && last4.isNotEmpty && last4.length != 4) {
      showSnack(context, 'Use the last 4 digits only.');
      return;
    }
    final typed = _parse(_balance.text) ?? 0;
    final draft = WalletDraft(
      name: name,
      kind: _kind,
      provider: _provider,
      last4: _hasNumber && last4.isNotEmpty ? last4 : null,
      balance: _kind == 'credit' ? -typed : typed,
      isShared: _shared,
      showBalanceToPartner: !_shared && _showPartner,
    );
    setState(() => _busy = true);
    try {
      final repo = ref.read(repositoryProvider);
      _existing == null ? await repo.addWallet(draft) : await repo.updateWallet(_existing.id, draft);
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
    final me = ref.watch(meProvider);
    final partner = me.partner;
    final typed = _parse(_balance.text) ?? 0;
    final preview = Wallet(
      id: 0,
      name: _name.text.trim().isEmpty ? brandOf(_provider).name : _name.text.trim(),
      kind: _kind,
      provider: _provider,
      ownerId: _shared ? null : me.user.id,
      ownerName: me.user.name,
      last4: _hasNumber && _last4.text.length == 4 ? _last4.text : null,
      balance: _existing?.balance ?? (_kind == 'credit' ? -typed : typed),
    );
    final label = TextStyle(color: p.muted, fontSize: 12.5, fontWeight: FontWeight.w600);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SheetTitle(_existing == null ? 'New wallet' : 'Edit wallet'),
            const SizedBox(height: 12),
            BankCard(preview, hide: false),
            const SizedBox(height: 16),
            if (_existing?.builtin ?? false) ...[
              Text(
                'Your Cash wallet is built in, for withdrawals and paying in cash. You can rename it, but not remove it.',
                style: TextStyle(color: p.muted, fontSize: 12.5, height: 1.4),
              ),
              const SizedBox(height: 14),
            ] else ...[
              for (final group in walletGroups) ...[
                Text(group, style: label),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 10,
                  children: [
                    for (final b in walletBrands.where((b) => b.group == group))
                      Semantics(
                        button: true,
                        selected: b.key == _provider,
                        label: b.name,
                        excludeSemantics: true,
                        child: InkWell(
                          onTap: () => _pickBrand(b),
                          borderRadius: BorderRadius.circular(12),
                          child: SizedBox(
                            width: 64,
                            child: Column(
                              children: [
                                BrandBadge(b, size: 40, selected: b.key == _provider),
                                const SizedBox(height: 4),
                                Text(
                                  b.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: b.key == _provider ? p.heading : p.muted,
                                    fontWeight: b.key == _provider ? FontWeight.w700 : FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
              ],
              Text('Type', style: label),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final e in walletKinds.entries)
                    ChoiceChip(label: Text(e.value), selected: _kind == e.key, onSelected: (_) => setState(() => _kind = e.key)),
                ],
              ),
              const SizedBox(height: 14),
            ],
            TextField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Name', hintText: 'e.g. GCash, BPI Payroll, Our Maya'),
              onChanged: (_) => setState(() => _nameTouched = true),
            ),
            if (_hasNumber) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _last4,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(4)],
                decoration: const InputDecoration(labelText: 'Last 4 digits (optional)', helperText: 'Only to tell your cards apart.'),
                onChanged: (_) => setState(() {}),
              ),
            ],
            if (_existing == null) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _balance,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                decoration: InputDecoration(
                  labelText: _kind == 'credit' ? 'Amount owed now' : 'Balance now',
                  prefixText: '₱ ',
                  helperText: _kind == 'credit' ? null : 'What your app shows today. You can correct it any time.',
                ),
                onChanged: (_) => setState(() {}),
              ),
              if (partner != null)
                SwitchListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                  title: const Text('Ours (shared wallet)'),
                  subtitle: Text('You both can spend from it and top it up', style: TextStyle(color: p.muted, fontSize: 12)),
                  value: _shared,
                  onChanged: (v) => setState(() => _shared = v),
                ),
            ],
            if (!_shared && partner != null)
              SwitchListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                title: Text('Show balance to ${partner.name}'),
                subtitle: Text("${partner.name} always sees the wallet's name", style: TextStyle(color: p.muted, fontSize: 12)),
                value: _showPartner,
                onChanged: (v) => setState(() => _showPartner = v),
              ),
            const SizedBox(height: 8),
            FilledButton(onPressed: _busy ? null : _save, child: Text(_existing == null ? 'Add ${preview.name}' : 'Save changes')),
            if (_existing == null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Pairnest never connects to your bank. Balances move as you log money in and out.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: p.muted, fontSize: 11.5),
                ),
              ),
            if (_existing != null && _existing.balance != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Balance now: ${walletBalanceText(_existing)}. Use Correct balance to change it.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: p.muted, fontSize: 11.5),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
